/// build_steps.dart — Flutter 建置前置步驟：clean、analyze、l10n生成、圖示生成
library;

import 'dart:async' show Future;

// ignore: depend_on_referenced_packages
import 'dart:io' show Directory, File, Process, exit;

import 'package:flutter_icon_creator/flutter_icon_creator.dart' as icon_creator;
import 'package:path/path.dart' as p;

import 'log.dart';

/// 執行 flutter clean
void runFlutterClean() {
  logMessageInline('Running flutter clean ... ');
  final result = Process.runSync('flutter', ['clean'], runInShell: true);
  if (result.exitCode != 0) {
    logMessage('FAILED');
    logMessage((result.stderr as String).trim());
    throw Exception('flutter clean failed');
  }
  logMessage('OK');
  logMessage('');
}

/// 執行 flutter analyze 進行靜態分析
void runFlutterAnalyze(String projectDir) {
  logMessage('Running flutter analyze ...');
  final result = Process.runSync('flutter', ['analyze'],
      workingDirectory: projectDir, runInShell: true);
  if (result.exitCode != 0) {
    final err = (result.stderr as String).trim();
    final out = (result.stdout as String).trim();
    logMessage('flutter analyze found issues:');
    logMessage(err.isNotEmpty ? err : out);
    exit(1);
  }
  logMessage('flutter analyze passed.');
  logMessage('');
}

/// 若專案中含 lib/l10n/app_*.arb 檔案，則執行 flutter gen-l10n。
///
/// 若未找到 ARB 檔案則直接返回，不報錯。
void runL10nGenerate(String projectDir) {
  final arbDir = p.join(projectDir, 'lib', 'l10n');
  if (!Directory(arbDir).existsSync()) return;

  final arbFiles = Directory(arbDir)
      .listSync()
      .whereType<File>()
      .where((f) {
        final name = p.basename(f.path);
        return name.startsWith('app_') && name.endsWith('.arb');
      })
      .toList();

  if (arbFiles.isEmpty) return;

  logMessage('Found l10n folder with app_*.arb files, running flutter gen-l10n ...');
  final result = Process.runSync('flutter', ['gen-l10n'],
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
  final iconFgPaths = [
    p.join(projectDir, 'ico', 'iconf.png'),
    p.join(projectDir, 'ico', 'icon.png'),
  ];
  final iconBgPaths = [
    p.join(projectDir, 'ico', 'iconb.png'),
  ];

  final fgPath =
      iconFgPaths.firstWhere((pth) => File(pth).existsSync(), orElse: () => '');
  final bgPath = (appiconbg != null && appiconbg.isNotEmpty)
      ? p.join(projectDir, appiconbg)
      : iconBgPaths.firstWhere((pth) => File(pth).existsSync(), orElse: () => '');

  if (fgPath.isEmpty && bgPath.isEmpty) {
    logMessage('No icon source files found (ico/iconf.png, ico/icon.png, ico/iconb.png), skipping icon generation.');
    return;
  }

  logMessage('Generating app icons ...');
  final args = <String>[
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
