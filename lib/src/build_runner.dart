/// Flutter 全平台建置核心邏輯
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

import 'constants.dart';

// =============================================================================
// 取得腳本所在目錄（模板檔案位置）
// =============================================================================

/// 回傳此 `build_runner.dart` 所在目錄，若從 compiled exe 執行則回傳 exe 所在目錄
String get _scriptDir {
  final scriptPath = File(Platform.script.toFilePath()).absolute.path;
  final libDir = p.dirname(scriptPath); // lib/src 或 bin
  // 模板檔案放在套件根目錄，從 lib/src 往上兩層，從 bin 往上一層
  if (libDir.endsWith('src')) {
    return p.dirname(p.dirname(libDir));
  } else {
    return p.dirname(libDir);
  }
}

// =============================================================================
// 日誌輸出
// =============================================================================

void _log(String message) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  print('[$ts][BUILD] $message');
}

void _logInline(String message) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  stdout.write('[$ts][BUILD] $message');
}

// =============================================================================
// pubspec.yaml 解析
// =============================================================================

(String name, String version) getPubspecInfo(String projectDir) {
  final pubspecPath = p.join(projectDir, 'pubspec.yaml');
  final file = File(pubspecPath);
  if (!file.existsSync()) {
    throw Exception(
      'pubspec.yaml not found. This directory is not a Flutter project.',
    );
  }

  final content = file.readAsStringSync();
  final doc = y.loadYaml(content) as y.YamlMap;
  final name = (doc['name'] as String?) ?? '';
  final version = (doc['version'] as String?) ?? '';
  return (name, version);
}

// =============================================================================
// 平台可用性檢查
// =============================================================================

List<String> getAvailablePlatforms() {
  return allPlatforms.where(isPlatformAvailable).toList();
}

List<String> filterPlatforms(List<String> platforms, String? targetFilter) {
  if (targetFilter == null || targetFilter.isEmpty) return platforms;
  final targets = targetFilter
      .split(',')
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toSet();
  final filtered = platforms.where((p) => targets.contains(p)).toList();
  if (filtered.isEmpty) {
    _log("Warning: no platforms matched filter '$targetFilter'");
  }
  return filtered;
}

// =============================================================================
// Flutter 前置步驟
// =============================================================================

void runFlutterClean() {
  _logInline('Running flutter clean ... ');
  final result = Process.runSync('flutter', ['clean'], runInShell: true);
  if (result.exitCode != 0) {
    _log('FAILED');
    _log((result.stderr as String).trim());
    throw Exception('flutter clean failed');
  }
  _log('OK');
  _log('');
}

void runFlutterAnalyze() {
  _log('Running flutter analyze ...');
  final result = Process.runSync('flutter', ['analyze'], runInShell: true);
  if (result.exitCode != 0) {
    final err = (result.stderr as String).trim();
    final out = (result.stdout as String).trim();
    _log('flutter analyze found issues:');
    _log(err.isNotEmpty ? err : out);
    exit(1);
  }
  _log('flutter analyze passed.');
  _log('');
}

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

  _log('Found l10n folder with app_*.arb files, running flutter gen-l10n ...');
  final result = Process.runSync('flutter', ['gen-l10n'], runInShell: true);
  if (result.exitCode != 0) {
    _log('flutter gen-l10n failed:');
    _log((result.stderr as String).trim());
    throw Exception('flutter gen-l10n failed');
  }
  _log('flutter gen-l10n OK.');
  _log('');
}

// =============================================================================
// 資源檔案處理
// =============================================================================

Map<String, String> findAssetFiles(String projectDir) {
  final assets = <String, String>{};
  final dir = Directory(projectDir);
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (name == 'LICENSE') {
      assets['LICENSE.txt'] = name;
    } else if (name.startsWith('README') && name.endsWith('.md')) {
      final outName = '${name.substring(0, name.length - 3)}.html';
      assets[outName] = name;
    }
  }
  return assets;
}

String convertMarkdown(String text) {
  return md.markdownToHtml(text, extensionSet: md.ExtensionSet.gitHubFlavored);
}

void writeAssetFiles(
  String outDir,
  String platform,
  Map<String, String> assets,
  Map<String, String> textCache,
) {
  for (final entry in assets.entries) {
    final outPath = p.join(outDir, entry.key);
    var text = textCache[entry.value] ?? '';
    if (entry.key.endsWith('.html')) {
      File(outPath).writeAsStringSync(text);
    } else if (entry.key.endsWith('.txt')) {
      if (platform == 'windows') {
        text = text.replaceAll('\n', '\r\n');
        // 寫入 UTF-8 BOM
        final file = File(outPath);
        final sink = file.openWrite();
        sink.add(const [0xEF, 0xBB, 0xBF]);
        sink.add(utf8.encode(text));
        sink.close();
      } else {
        File(outPath).writeAsStringSync(text);
      }
    }
  }
}

// =============================================================================
// 桌面平台後處理
// =============================================================================

void _handleLinuxDesktop({
  required String outDir,
  required String name,
  required String ext,
  required String appicon,
  required String appdesc,
  required String appgeneric,
  required String appcategory,
}) {
  final iconFile = p.basename(appicon);
  final iconName = p.basenameWithoutExtension(iconFile);

  if (File(appicon).existsSync()) {
    final dst = p.join(outDir, iconFile);
    if (!File(dst).existsSync()) {
      File(appicon).copySync(dst);
    }
  }

  final tmplPath = p.join(_scriptDir, 'install_app.sh.tmpl');
  final tmplFile = File(tmplPath);
  if (!tmplFile.existsSync()) {
    _log('  Warning: install_app.sh.tmpl not found, skipping install script');
    return;
  }

  var template = tmplFile.readAsStringSync();

  final replacements = {
    '{{APP_NAME}}': name,
    '{{APP_EXEC}}': '$name$ext',
    '{{APP_ICON_FILE}}': iconFile,
    '{{APP_ICON_NAME}}': iconName,
    '{{APP_COMMENT}}': appdesc.isNotEmpty ? appdesc : name,
    '{{APP_GENERIC_NAME}}': appgeneric.isNotEmpty ? appgeneric : name,
    '{{APP_CATEGORIES}}': appcategory,
    '{{APP_DESKTOP_NAME}}': name,
  };

  for (final entry in replacements.entries) {
    template = template.replaceAll(entry.key, entry.value);
  }

  final scriptPath = p.join(outDir, 'install_app.sh');
  File(scriptPath).writeAsStringSync(template);
  // 設定執行權限（Linux/macOS）
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['755', scriptPath]);
  }
}

void _handleWindowsShortcut({
  required String outDir,
  required String name,
  required String ext,
  required String appdesc,
  required String appgeneric,
  required String projectDir,
}) {
  // 尋找 ico 圖示
  final icoPaths = [
    p.join(projectDir, 'ico', 'icon.ico'),
    p.join(projectDir, 'icon.ico'),
    p.join(projectDir, 'windows', 'runner', 'resources', 'app_icon.ico'),
  ];
  var iconFile = '';
  for (final icoPath in icoPaths) {
    if (File(icoPath).existsSync()) {
      iconFile = p.basename(icoPath);
      final dst = p.join(outDir, iconFile);
      if (!File(dst).existsSync()) {
        File(icoPath).copySync(dst);
      }
      break;
    }
  }

  final tmplPath = p.join(_scriptDir, 'install_app.ps1.tmpl');
  final tmplFile = File(tmplPath);
  if (!tmplFile.existsSync()) {
    _log('  Warning: install_app.ps1.tmpl not found, skipping install script');
    return;
  }

  var template = tmplFile.readAsStringSync();

  final replacements = {
    '{{APP_NAME}}': name,
    '{{APP_EXEC}}': '$name$ext',
    '{{APP_ICON}}': iconFile,
    '{{APP_COMMENT}}': appdesc.isNotEmpty ? appdesc : name,
    '{{APP_DESKTOP_NAME}}': name,
  };

  for (final entry in replacements.entries) {
    template = template.replaceAll(entry.key, entry.value);
  }

  final scriptPath = p.join(outDir, 'install_app.ps1');
  // Windows 使用 UTF-8-BOM
  final file = File(scriptPath);
  final sink = file.openWrite();
  sink.add(const [0xEF, 0xBB, 0xBF]);
  sink.add(utf8.encode(template));
  sink.close();
}

void _handleMacosBundle({
  required String outDir,
  required String name,
  required String appver,
  required String appdesc,
  required String appgeneric,
  required String appidentifier,
  required String appmacoscategory,
}) {
  // 產生 macOS 安裝腳本
  final installScript = '''#!/bin/sh
set -e

SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
APP_NAME="$name"
APP_BUNDLE="\$SCRIPT_DIR/\${APP_NAME}.app"
DEST="/Applications/\${APP_NAME}.app"

case "\${1:-}" in
    install)
        echo "[install] Installing \${APP_NAME} to /Applications ..."
        if [ -d "\$DEST" ]; then
            rm -rf "\$DEST"
        fi
        cp -R "\$APP_BUNDLE" "\$DEST"
        echo "[install] Done. \${APP_NAME} installed to /Applications."
        ;;
    uninstall)
        echo "[uninstall] Removing \${APP_NAME} ..."
        rm -rf "\$DEST"
        echo "[uninstall] Done."
        ;;
    *)
        echo "Usage: \$0 {install|uninstall}"
        echo "  install   - Copy .app to /Applications"
        echo "  uninstall - Remove from /Applications"
        exit 1
        ;;
esac
''';

  final scriptPath = p.join(outDir, 'install_app.sh');
  File(scriptPath).writeAsStringSync(installScript);
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['755', scriptPath]);
  }
}

// =============================================================================
// 單一平台建置
// =============================================================================

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
  required String webRenderer,
  required String binDir,
}) async {
  final ext = platformExtensions[platform] ?? '';
  final outDirName =
      appver.isNotEmpty ? '${name}_v${appver}_$platform' : '${name}_$platform';
  final outDir = p.join(binDir, outDirName);

  // 建置命令
  List<String> cmd;
  switch (platform) {
    case 'web':
      cmd = ['flutter', 'build', 'web', '--web-renderer', webRenderer];
    case 'android':
      cmd = ['flutter', 'build', 'apk'];
    case 'ios':
      cmd = ['flutter', 'build', 'ios', '--no-codesign'];
    default:
      cmd = ['flutter', 'build', platform];
  }

  _logInline('Building $platform ... ');

  final result = await Process.run(
    cmd.first,
    cmd.skip(1).toList(),
    workingDirectory: projectDir,
    runInShell: true,
  );

  if (result.exitCode != 0) {
    final err = (result.stderr as String).trim();
    final out = (result.stdout as String).trim();
    return ('FAILED', err.isNotEmpty ? err : out);
  }

  // 複製建置產物
  Directory(outDir).createSync(recursive: true);
  final buildSrc = platformBuildDirs[platform];
  if (buildSrc != null) {
    final buildSrcAbs = p.join(projectDir, buildSrc);
    final buildSrcDir = Directory(buildSrcAbs);
    if (buildSrcDir.existsSync()) {
      _copyDirectory(buildSrcAbs, outDir);
    }
  }

  // 寫入資源檔案
  if (assets.isNotEmpty) {
    writeAssetFiles(outDir, platform, assets, textCache);
  }

  // 平台特定後處理
  final fullAppicon = p.join(projectDir, appicon);
  switch (platform) {
    case 'linux':
      _handleLinuxDesktop(
        outDir: outDir,
        name: name,
        ext: ext,
        appicon: fullAppicon,
        appdesc: appdesc,
        appgeneric: appgeneric,
        appcategory: appcategory,
      );
    case 'windows':
      _handleWindowsShortcut(
        outDir: outDir,
        name: name,
        ext: ext,
        appdesc: appdesc,
        appgeneric: appgeneric,
        projectDir: projectDir,
      );
    case 'macos':
      _handleMacosBundle(
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
// 目錄複製輔助
// =============================================================================

void _copyDirectory(String src, String dst) {
  for (final entity in Directory(src).listSync()) {
    final target = p.join(dst, p.basename(entity.path));
    if (entity is Directory) {
      if (!Directory(target).existsSync()) {
        // 遞迴複製
        _copyRecursive(entity.path, target);
      } else {
        _mergeDirectory(entity.path, target);
      }
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

void _copyRecursive(String src, String dst) {
  Directory(dst).createSync(recursive: true);
  for (final entity in Directory(src).listSync()) {
    final target = p.join(dst, p.basename(entity.path));
    if (entity is Directory) {
      _copyRecursive(entity.path, target);
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

void _mergeDirectory(String src, String dst) {
  for (final entity in Directory(src).listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: src);
    final target = p.join(dst, rel);
    Directory(p.dirname(target)).createSync(recursive: true);
    entity.copySync(target);
  }
}

// =============================================================================
// 並行建置控制
// =============================================================================

class _Semaphore {
  int _permits;
  final List<Completer<void>> _waiters = [];

  _Semaphore(this._permits);

  Future<void> acquire() {
    if (_permits > 0) {
      _permits--;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _permits++;
    }
  }
}

// =============================================================================
// 主建置流程
// =============================================================================

Future<void> buildAll({
  String? nameOverride,
  String? targetFilter,
  String? appver,
  String appdesc = '',
  String appgeneric = '',
  String appcategory = 'Utility',
  String appicon = 'web/icons/Icon-192.png',
  String appidentifier = '',
  String appmacoscategory = 'public.app-category.utilities',
  String? projectDir,
  int? jobs,
  String webRenderer = 'auto',
  bool skipAnalyze = false,
  bool skipWeb = false,
}) async {
  // 確認並切換至專案目錄
  final effectiveProjectDir = projectDir != null
      ? Directory(projectDir).absolute.path
      : Directory.current.path;
  if (!Directory(effectiveProjectDir).existsSync()) {
    throw Exception('Project directory not found: $effectiveProjectDir');
  }
  _log('Project directory: $effectiveProjectDir');

  // 讀取 pubspec.yaml
  final (name, detectedVersion) = getPubspecInfo(effectiveProjectDir);
  if (name.isEmpty) {
    throw Exception(
      "Cannot find 'name' in pubspec.yaml. This directory is not a Flutter project.",
    );
  }
  _log('pubspec.yaml found, this is a Flutter project.');
  _log('');

  final effectiveName = nameOverride ?? name;
  final effectiveVersion = appver ?? detectedVersion;
  if (effectiveVersion.isNotEmpty) {
    _log('Version from pubspec.yaml: $effectiveVersion');
  }

  // 多語系生成
  runL10nGenerate(effectiveProjectDir);

  // 靜態分析
  if (!skipAnalyze) {
    runFlutterAnalyze();
  }

  // 取得可用平台
  var platforms = getAvailablePlatforms();
  if (skipWeb) {
    platforms = platforms.where((p) => p != 'web').toList();
  }
  if (targetFilter != null && targetFilter.isNotEmpty) {
    platforms = filterPlatforms(platforms, targetFilter);
  }

  // 通知使用者不可用的平台
  final unavailable = (targetFilter != null
          ? targetFilter.split(',').map((t) => t.trim().toLowerCase())
          : allPlatforms)
      .where((p) => allPlatforms.contains(p) && !isPlatformAvailable(p));
  for (final p in unavailable) {
    _log(
        "Note: platform '$p' cannot be built on this OS (${Platform.operatingSystem}), skipped.");
  }

  _log('App: $effectiveName');
  if (effectiveVersion.isNotEmpty) {
    _log('Version: $effectiveVersion');
  }
  _log('Platforms: ${platforms.length} -> ${platforms.join(', ')}');
  _log('Web renderer: $webRenderer');
  _log('');

  // 準備資源檔案
  final assets = findAssetFiles(effectiveProjectDir);

  final textCache = <String, String>{};
  for (final srcName in assets.values) {
    final content =
        File(p.join(effectiveProjectDir, srcName)).readAsStringSync();
    textCache[srcName] =
        srcName.endsWith('.md') ? convertMarkdown(content) : content;
  }

  if (assets.isNotEmpty) {
    _log('Asset files to include in each output:');
    for (final outName in assets.keys.toList()..sort()) {
      _log('  $outName');
    }
    _log('');
  }

  // 清除舊的 bin/ 目錄
  final binDir = p.join(effectiveProjectDir, 'bin');
  if (Directory(binDir).existsSync()) {
    Directory(binDir).deleteSync(recursive: true);
    _log('Removed old bin directory.');
  }
  Directory(binDir).createSync();

  int success = 0;
  int failed = 0;

  if (jobs != null) {
    // ---- 平行建置 ----
    final maxWorkers = jobs == 0 ? Platform.numberOfProcessors : jobs;
    _log('Building with $maxWorkers parallel workers');
    _log('');

    final semaphore = _Semaphore(maxWorkers);
    final lock = _Semaphore(1);
    final errors = <String>[];

    final futures = platforms.map((platform) async {
      await semaphore.acquire();
      try {
        final label = effectiveVersion.isNotEmpty
            ? '${effectiveName}_v${effectiveVersion}_$platform'
            : '${effectiveName}_$platform';

        final (status, error) = await buildOnePlatform(
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
          webRenderer: webRenderer,
          binDir: binDir,
        );

        await lock.acquire();
        try {
          _log('Building $label ... $status');
          if (error.isNotEmpty) {
            final shortErr =
                error.length > 500 ? '${error.substring(0, 500)}...' : error;
            _log('  $shortErr');
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
    for (final platform in platforms) {
      final label = effectiveVersion.isNotEmpty
          ? '${effectiveName}_v${effectiveVersion}_$platform'
          : '${effectiveName}_$platform';
      _logInline('Building $label ... ');
      final (status, error) = await buildOnePlatform(
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
        webRenderer: webRenderer,
        binDir: binDir,
      );
      print(status);
      if (error.isNotEmpty) {
        _log(
            '  ${error.length > 500 ? '${error.substring(0, 500)}...' : error}');
      }
      if (status == 'FAILED') {
        failed++;
      } else {
        success++;
      }
    }
  }

  _log('');
  _log('Done. Success: $success, Failed: $failed');
}
