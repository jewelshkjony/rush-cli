import 'dart:io' show Directory, File, exit;

import 'package:args/command_runner.dart';
import 'package:dart_console/dart_console.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:rush_cli/helpers/dir_utils.dart';
import 'package:rush_cli/templates/rules_pro.dart';

import 'package:rush_prompt/rush_prompt.dart';
import 'package:rush_cli/templates/intellij_files.dart';
import 'package:rush_cli/helpers/casing.dart';
import 'package:rush_cli/commands/create_command/questions.dart';
import 'package:rush_cli/templates/android_manifest.dart';
import 'package:rush_cli/templates/dot_gitignore.dart';
import 'package:rush_cli/templates/readme.dart';
import 'package:rush_cli/templates/rush_yml.dart';
import 'package:rush_cli/templates/extension_source.dart';

class CreateCommand extends Command {
  final String _cd;
  final String _dataDir;
  String? extName;

  CreateCommand(this._cd, this._dataDir);

  @override
  String get description =>
      'Scaffolds a new extension project in the current working directory.';

  @override
  String get name => 'create';

  @override
  void printUsage() {
    PrintArt();

    Console()
      ..setForegroundColor(ConsoleColor.cyan)
      ..write(' create: ')
      ..resetColorAttributes()
      ..writeLine(description)
      ..writeLine()
      ..writeLine(' Usage: ')
      ..setForegroundColor(ConsoleColor.brightBlue)
      ..write('   rush ')
      ..setForegroundColor(ConsoleColor.cyan)
      ..write('create ')
      ..resetColorAttributes()
      ..writeLine('<extension_name>');
  }

  /// Creates a new extension project in the current directory.
  @override
  Future<void> run() async {
    late String name;
    if (argResults!.rest.length == 1) {
      name = argResults!.rest.first;
    } else {
      printUsage();
      exit(64); // Exit code 64 indicates usage error
    }
    PrintArt();

    final kebabCasedName = Casing.kebabCase(name);
    final projectDir = p.join(_cd, kebabCasedName);

    if (Directory(projectDir).existsSync()) {
      Logger.log(
          LogType.erro,
          'A dircetory named "$kebabCasedName" already exists in $_cd. Please '
          'choose a different name for the extension or move to different directory.');
      exit(1);
    }

    final answers = RushPrompt(questions: Questions.questions).askAll();
    final authorName = answers[1][1].toString().trim();
    final versionName = answers[2][1].toString().trim();
    final lang = answers[3][1].toString().trim();
    var orgName = answers[0][1].toString().trim();

    final camelCasedName = Casing.camelCase(name);
    final pascalCasedName = Casing.pascalCase(name);

    // If the last word after '.' in pacakge name is same as the
    // extension name, then
    final isOrgAndNameSame =
        orgName.split('.').last.toLowerCase() == camelCasedName.toLowerCase();
    if (!isOrgAndNameSame) {
      orgName = orgName.toLowerCase() + '.' + camelCasedName.toLowerCase();
    }

    Logger.logCustom('Getting things ready...',
        prefix: '\n• ', prefixFG: ConsoleColor.yellow);

    // Creates the required files for the extension.
    try {
      final extPath = p.joinAll([projectDir, 'src', ...orgName.split('.')]);

      if (lang == 'Java') {
        _writeFile(
            p.join(extPath, '$pascalCasedName.java'),
            getExtensionTempJava(
              pascalCasedName,
              orgName,
            ));
      } else {
        _writeFile(
            p.join(extPath, '$pascalCasedName.kt'),
            getExtensionTempKt(
              pascalCasedName,
              orgName,
            ));
      }

      _writeFile(p.join(projectDir, 'src', 'AndroidManifest.xml'),
          getManifestXml(orgName));
      _writeFile(p.join(projectDir, 'src', 'proguard-rules.pro'),
          getPgRules(orgName, pascalCasedName));

      _writeFile(
          p.join(projectDir, 'rush.yml'),
          getRushYamlTemp(
              pascalCasedName, versionName, authorName, lang == 'Kotlin'));

      _writeFile(p.join(projectDir, 'README.md'), getReadme(pascalCasedName));
      _writeFile(p.join(projectDir, '.gitignore'), getDotGitignore());
      _writeFile(p.join(projectDir, 'deps', '.placeholder'),
          'This directory stores your extension\'s depenedencies.');

      // IntelliJ IDEA files
      _writeFile(p.join(projectDir, '.idea', 'misc.xml'), getMiscXml());

      _writeFile(p.join(projectDir, '.idea', 'libraries', 'dev-deps.xml'),
          getDevDepsXml(_dataDir));
      _writeFile(
          p.join(projectDir, '.idea', 'libraries', 'deps.xml'), getDepsXml());

      _writeFile(p.join(projectDir, '.idea', 'modules.xml'),
          getModulesXml(kebabCasedName));
      _writeFile(p.join(projectDir, '.idea', '$kebabCasedName.iml'), getIml());
    } catch (e) {
      Logger.log(LogType.erro, e.toString());
      exit(1);
    }

    try {
      Directory(p.join(projectDir, 'assets')).createSync(recursive: true);
    } catch (e) {
      Logger.log(LogType.erro, e.toString());
      exit(1);
    }

    // Copy icon
    File(p.join(_dataDir, 'tools', 'other', 'icon-rush.png'))
        .copySync(p.join(projectDir, 'assets', 'icon.png'));

    Hive.init(p.join(projectDir, '.rush'));
    final box = await Hive.openBox('data');
    await box.putAll({
      'name': pascalCasedName,
      'version': 1,
      'org': orgName,
      'rushYmlLastMod': DateTime.now(),
      'srcDirLastMod': DateTime.now(),
    });

    Console()
      ..setForegroundColor(ConsoleColor.green)
      ..write('• ')
      ..setForegroundColor(ConsoleColor.brightGreen)
      ..write('Success! ')
      ..resetColorAttributes()
      ..write('Generated a new AI2 extension project in: ')
      ..setForegroundColor(ConsoleColor.cyan)
      ..writeLine(projectDir)
      ..writeLine()
      ..resetColorAttributes()
      ..write('Next up, \n' + ' ' * 2 + '-')
      ..setForegroundColor(ConsoleColor.yellow)
      ..write(' cd ')
      ..resetColorAttributes()
      ..write('into ')
      ..setForegroundColor(ConsoleColor.brightBlue)
      ..write(kebabCasedName + '/')
      ..resetColorAttributes()
      ..writeLine(', and')
      ..write(' ' * 2 + '- run ')
      ..setForegroundColor(ConsoleColor.brightBlue)
      ..write('rush build ')
      ..resetColorAttributes()
      ..writeLine('to compile your extension.');
  }

  /// Creates a file in [path] and writes [content] inside it.
  void _writeFile(String path, String content) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }
}
