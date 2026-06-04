/// build_steps.dart — Flutter 建置前置步驟：analyze、l10n生成、圖示生成
library;

// ignore: depend_on_referenced_packages
import 'dart:io' show Directory, File, Process, ProcessResult;

import 'package:flutter_icon_creator/flutter_icon_creator.dart' as icon_creator;
import 'package:path/path.dart' as p;

import 'log.dart';

/// 執行 flutter analyze 進行靜態分析
void runFlutterAnalyze(String projectDir) {
  logMessage('Running flutter analyze ...');
  final ProcessResult result = Process.runSync(
      'flutter', ['analyze', '--no-fatal-infos'],
      workingDirectory: projectDir, runInShell: true);
  if (result.exitCode != 0) {
    final String err = (result.stderr as String).trim();
    final String out = (result.stdout as String).trim();
    logMessage('flutter analyze found issues:');
    logMessage(err.isNotEmpty ? err : out);
    throw Exception('flutter analyze found issues');
  }
  logMessage('flutter analyze passed.');
  logMessage('');
}

/// 若專案中含 lib/l10n/app_*.arb 檔案，則執行 flutter gen-l10n。
///
/// 若未找到 ARB 檔案則直接返回，不報錯。
void runL10nGenerate(String projectDir) {
  final String arbDir = p.join(projectDir, 'lib', 'l10n');
  if (!Directory(arbDir).existsSync()) return;

  final List<File> arbFiles = Directory(arbDir)
      .listSync()
      .whereType<File>()
      .where((File f) {
        final String fileName = p.basename(f.path);
        return fileName.startsWith('app_') && fileName.endsWith('.arb');
      })
      .toList();

  if (arbFiles.isEmpty) return;

  logMessage('Found l10n folder with app_*.arb files, running flutter gen-l10n ...');
  final ProcessResult result = Process.runSync('flutter', ['gen-l10n'],
      workingDirectory: projectDir, runInShell: true);
  if (result.exitCode != 0) {
    logMessage('flutter gen-l10n failed:');
    logMessage((result.stderr as String).trim());
    throw Exception('flutter gen-l10n failed');
  }
  logMessage('flutter gen-l10n OK.');
  logMessage('');
}

/// 自動偵測圖示來源檔案並透過 flutter-icon-creator 生成全平台圖示。
///
/// 偵測順序：ico/iconf.png → ico/icon.png（前景）、ico/iconb.png（背景）。
/// 若 [appiconbg] 不為空則優先使用，跳過自動偵測。
/// 若未找到任何來源檔案則輸出警告並跳過。
Future<void> runIconGenerate(String projectDir, {String? appiconbg}) async {
  final List<String> iconFgPaths = [
    p.join(projectDir, 'ico', 'iconf.png'),
    p.join(projectDir, 'ico', 'icon.png'),
  ];
  final List<String> iconBgPaths = [
    p.join(projectDir, 'ico', 'iconb.png'),
  ];

  final String fgPath = iconFgPaths.firstWhere(
      (String pth) => File(pth).existsSync(),
      orElse: () => '');
  final String bgPath = (appiconbg != null && appiconbg.isNotEmpty)
      ? p.join(projectDir, appiconbg)
      : iconBgPaths.firstWhere((String pth) => File(pth).existsSync(),
          orElse: () => '');

  if (fgPath.isEmpty && bgPath.isEmpty) {
    logMessage('No icon source files found (ico/iconf.png, ico/icon.png, ico/iconb.png), skipping icon generation.');
    return;
  }

  logMessage('Generating app icons ...');
  final List<String> args = <String>[
    '-f',
    projectDir,
    if (fgPath.isNotEmpty) ...['-i', fgPath],
    if (bgPath.isNotEmpty) ...['-b', bgPath],
  ];

  try {
    await icon_creator.run(args);
    logMessage('Icon generation OK.');
  } on Exception catch (e) {
    logMessage('Icon generation warning: $e');
    logMessage('Continuing with build...');
  }
  logMessage('');
}
