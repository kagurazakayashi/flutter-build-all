/// build_runner.dart — 核心建置流程：單平台建置函式與 buildAll 流程協調器
///
/// 本模組實作了建置流水線的所有步驟：
/// 1. 讀取 pubspec.yaml → 2. 圖示生成 → 3. 多語系生成
/// → 4. 靜態分析 → 5. 平台列舉 → 6. 資源準備
/// → 7. 逐平台建置 → 8. 後處理（安裝腳本、桌面捷徑）
///
/// 支援序列與平行建置模式，可透過 buildAll() 的參數控制各步驟開關。
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'assets.dart';
import 'build_steps.dart';
import 'constants.dart';
import 'desktop.dart';
import 'dir_utils.dart';
import 'log.dart';
import 'platforms.dart';
import 'web_fonts.dart';

// =============================================================================
// 並行建置控制
// =============================================================================

/// 訊號量（Semaphore），用於控制平行建置的最大並行數
class _Semaphore {
  int _permits;
  final List<Completer<void>> _waiters = <Completer<void>>[];

  _Semaphore(this._permits);

  /// 獲取一個許可，若無可用許可則阻塞等待
  Future<void> acquire() {
    if (_permits > 0) {
      _permits--;
      return Future<void>.value();
    }
    final Completer<void> c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  /// 釋放一個許可，若有等待者則喚醒最早的一個
  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _permits++;
    }
  }
}

// =============================================================================
// 單一平台建置
// =============================================================================

/// 針對單一平台執行 Flutter 建置並複製產物至輸出目錄。
///
/// 回傳 (status, error) 元組。status 為 "OK"、"FAILED"。
/// 建置成功後會自動複製建置產物、寫入資源檔案、處理桌面捷徑。
Future<(String status, String error)> buildOnePlatform({
  required String platform,
  required String name,
  required String appver,
  required String projectDir,
  required Map<String, String> assets,
  required Map<String, String> textCache,
  required String appicon,
  required String appdesc,
  required String appgeneric,
  required String appcategory,
  required String appidentifier,
  required String appmacoscategory,
  required String binDir,
  String webBaseHref = '/',
  bool webEmbedFonts = false,
}) async {
  final String ext = platformExtensions[platform] ?? '';
  final String outDirName = appver.isNotEmpty
      ? '${name}_v${appver}_$platform'
      : '${name}_$platform';
  final String outDir = p.join(binDir, outDirName);

  // 建置命令
  List<String> cmd;
  switch (platform) {
    case 'web':
      cmd = <String>[
        'flutter',
        'build',
        'web',
        '--base-href',
        webBaseHref,
        '--no-tree-shake-icons',
      ];
    case 'android':
      cmd = <String>['flutter', 'build', 'apk'];
    case 'ios':
      cmd = <String>['flutter', 'build', 'ios', '--no-codesign'];
    default:
      cmd = <String>['flutter', 'build', platform];
  }

  logMessage('Building $platform ...');

  final ProcessResult result = await Process.run(
    cmd.first,
    cmd.skip(1).toList(),
    workingDirectory: projectDir,
    runInShell: true,
  );

  if (result.exitCode != 0) {
    final String err = (result.stderr as String).trim();
    final String out = (result.stdout as String).trim();
    return ('FAILED', err.isNotEmpty ? err : out);
  }

  // 複製建置產物
  Directory(outDir).createSync(recursive: true);
  final String? buildSrc = platformBuildDirs[platform];
  if (buildSrc != null) {
    final String buildSrcAbs = p.join(projectDir, buildSrc);
    final Directory buildSrcDir = Directory(buildSrcAbs);
    if (buildSrcDir.existsSync()) {
      copyDirectory(buildSrcAbs, outDir);
    }
  }

  // 寫入資源檔案
  if (assets.isNotEmpty) {
    writeAssetFiles(outDir, platform, assets, textCache);
  }

  // Web 內嵌字型：複製快取字型至建置輸出
  if (platform == 'web' && webEmbedFonts) {
    copyWebFontsToBuild(projectDir, outDir);
  }

  // 平台特定後處理
  final String fullAppicon = p.join(projectDir, appicon);
  switch (platform) {
    case 'linux':
      handleLinuxDesktop(
        outDir: outDir,
        name: name,
        ext: ext,
        appicon: fullAppicon,
        appdesc: appdesc,
        appgeneric: appgeneric,
        appcategory: appcategory,
      );
    case 'windows':
      handleWindowsShortcut(
        outDir: outDir,
        name: name,
        ext: ext,
        appdesc: appdesc,
        projectDir: projectDir,
      );
    case 'macos':
      handleMacosBundle(
        outDir: outDir,
        name: name,
        appver: appver,
        appdesc: appdesc,
        appgeneric: appgeneric,
        appidentifier: appidentifier,
        appmacoscategory: appmacoscategory,
      );
  }

  return ('OK', '');
}

// =============================================================================
// 主建置流程
// =============================================================================

/// 主建置流程入口。
///
/// 依序執行：pubspec 解析 → 圖示生成 → 多語系生成 → 靜態分析
/// → 平台列舉 → 字型下載（若啟用） → 資源準備 → 逐平台建置。
///
/// 所有步驟均可透過對應的布林參數控制開關（如 analyze、icon、l10n）。
/// 設定 jobs 參數可啟用平行建置，null 則為序列模式。
Future<void> buildAll({
  String? nameOverride,
  String? targetFilter,
  String? appver,
  String appdesc = '',
  String appgeneric = '',
  String appcategory = 'Utility',
  String appicon = 'web/icons/Icon-192.png',
  String? appiconbg,
  String appidentifier = '',
  String appmacoscategory = 'public.app-category.utilities',
  String? projectDir,
  int? jobs,
  String webBaseHref = '/',
  bool analyze = true,
  bool icon = true,
  bool l10n = true,
  bool webEmbedFonts = false,
  String? webFontProxy,
}) async {
  // 自動規範化 webBaseHref：確保以 / 開頭與結尾
  String normalizedWebBaseHref = webBaseHref.isEmpty ? '/' : webBaseHref;
  if (!normalizedWebBaseHref.startsWith('/')) {
    normalizedWebBaseHref = '/$normalizedWebBaseHref';
  }
  if (!normalizedWebBaseHref.endsWith('/')) {
    normalizedWebBaseHref = '$normalizedWebBaseHref/';
  }

  // 確認並切換至專案目錄
  final String effectiveProjectDir = projectDir != null
      ? Directory(projectDir).absolute.path
      : Directory.current.path;
  if (!Directory(effectiveProjectDir).existsSync()) {
    throw Exception('Project directory not found: $effectiveProjectDir');
  }
  logMessage('Project directory: $effectiveProjectDir');

  // 讀取 pubspec.yaml
  final (String name, String detectedVersion) =
      getPubspecInfo(effectiveProjectDir);
  if (name.isEmpty) {
    throw Exception(
      "Cannot find 'name' in pubspec.yaml. This directory is not a Flutter project.",
    );
  }
  logMessage('pubspec.yaml found, this is a Flutter project.');
  logMessage('');

  final String effectiveName = nameOverride ?? name;
  final String effectiveVersion = appver ?? detectedVersion;
  if (effectiveVersion.isNotEmpty) {
    logMessage('Version from pubspec.yaml: $effectiveVersion');
  }

  // 圖示生成（透過 flutter-icon-creator）
  if (icon) {
    await runIconGenerate(effectiveProjectDir, appiconbg: appiconbg);
  }

  // 多語系生成
  if (l10n) {
    runL10nGenerate(effectiveProjectDir);
  }

  // 靜態分析
  if (analyze) {
    runFlutterAnalyze(effectiveProjectDir);
  }

  // 取得可用平台
  List<String> platforms = getAvailablePlatforms();
  if (targetFilter != null && targetFilter.isNotEmpty) {
    platforms = filterPlatforms(platforms, targetFilter);
  }

  // 通知使用者不可用的平台
  final Iterable<String> unavailable = (targetFilter != null
          ? targetFilter
              .split(',')
              .map((String t) => t.trim().toLowerCase())
          : allPlatforms)
      .where((String p) => allPlatforms.contains(p) && !isPlatformAvailable(p));
  for (final String p in unavailable) {
    logMessage(
        "Note: platform '$p' cannot be built on this OS (${Platform.operatingSystem}), skipped.");
  }

  logMessage('App: $effectiveName');
  if (effectiveVersion.isNotEmpty) {
    logMessage('Version: $effectiveVersion');
  }
  logMessage('Platforms: ${platforms.length} -> ${platforms.join(', ')}');
  if (webEmbedFonts) {
    logMessage('Web base-href: $normalizedWebBaseHref');
    logMessage('Web embed fonts: enabled');
  }
  logMessage('');

  // Web 內嵌字型：預先下載至快取目錄
  if (webEmbedFonts && platforms.contains('web')) {
    await downloadWebFonts(effectiveProjectDir, proxy: webFontProxy);
    logMessage('');
  }

  // 準備資源檔案
  final Map<String, String> assets = findAssetFiles(effectiveProjectDir);

  final Map<String, String> textCache = <String, String>{};
  for (final String srcName in assets.values) {
    final String content =
        File(p.join(effectiveProjectDir, srcName)).readAsStringSync();
    textCache[srcName] =
        srcName.endsWith('.md') ? convertMarkdown(content) : content;
  }

  if (assets.isNotEmpty) {
    logMessage('Asset files to include in each output:');
    for (final String outName in assets.keys.toList()..sort()) {
      logMessage('  $outName');
    }
    logMessage('');
  }

  // 清除舊的 bin/ 目錄
  final String binDir = p.join(effectiveProjectDir, 'bin');
  if (Directory(binDir).existsSync()) {
    Directory(binDir).deleteSync(recursive: true);
    logMessage('Removed old bin directory.');
  }
  Directory(binDir).createSync();

  int success = 0;
  int failed = 0;

  if (jobs != null) {
    // ---- 平行建置 ----
    final int maxWorkers = jobs == 0 ? Platform.numberOfProcessors : jobs;
    logMessage('Building with $maxWorkers parallel workers');
    logMessage('');

    final _Semaphore semaphore = _Semaphore(maxWorkers);
    final _Semaphore lock = _Semaphore(1);
    final List<String> errors = <String>[];

    final Iterable<Future<void>> futures = platforms.map(
        (String platform) async {
      await semaphore.acquire();
      try {
        final String label = effectiveVersion.isNotEmpty
            ? '${effectiveName}_v${effectiveVersion}_$platform'
            : '${effectiveName}_$platform';

        final (String status, String error) = await buildOnePlatform(
          platform: platform,
          name: effectiveName,
          appver: effectiveVersion,
          projectDir: effectiveProjectDir,
          assets: assets,
          textCache: textCache,
          appicon: appicon,
          appdesc: appdesc,
          appgeneric: appgeneric,
          appcategory: appcategory,
          appidentifier: appidentifier,
          appmacoscategory: appmacoscategory,
          binDir: binDir,
          webBaseHref: normalizedWebBaseHref,
          webEmbedFonts: webEmbedFonts,
        );

        await lock.acquire();
        try {
          logMessage('Building $label ... $status');
          if (error.isNotEmpty) {
            final String shortErr = error.length > 500
                ? '${error.substring(0, 500)}...'
                : error;
            logMessage('  $shortErr');
            errors.add('$platform: $error');
          }
          if (status == 'FAILED') {
            failed++;
          } else {
            success++;
          }
        } finally {
          lock.release();
        }
      } finally {
        semaphore.release();
      }
    });

    await Future.wait(futures);
  } else {
    // ---- 序列建置 ----
    for (final String platform in platforms) {
      final String label = effectiveVersion.isNotEmpty
          ? '${effectiveName}_v${effectiveVersion}_$platform'
          : '${effectiveName}_$platform';
      final (String status, String error) = await buildOnePlatform(
        platform: platform,
        name: effectiveName,
        appver: effectiveVersion,
        projectDir: effectiveProjectDir,
        assets: assets,
        textCache: textCache,
        appicon: appicon,
        appdesc: appdesc,
        appgeneric: appgeneric,
        appcategory: appcategory,
        appidentifier: appidentifier,
        appmacoscategory: appmacoscategory,
        binDir: binDir,
        webBaseHref: normalizedWebBaseHref,
        webEmbedFonts: webEmbedFonts,
      );
      logMessage('Building $label ... $status');
      if (error.isNotEmpty) {
        final String shortErr =
            error.length > 500 ? '${error.substring(0, 500)}...' : error;
        logMessage('  $shortErr');
      }
      if (status == 'FAILED') {
        failed++;
      } else {
        success++;
      }
    }
  }

  logMessage('');
  logMessage('Done. Success: $success, Failed: $failed');
}
