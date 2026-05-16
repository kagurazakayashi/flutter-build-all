/// web_fonts.dart — Web 內嵌字型：從 Flutter SDK 下載 fallback 字型並打包進 web 產物
library;

import 'dart:async' show Future;
import 'dart:io' show Directory, File, HttpClient, Process;

import 'package:path/path.dart' as p;

import 'log.dart';

/// Google Fonts CDN 基礎 URL
const fontsCdnBase = 'https://fonts.gstatic.com/s/';

/// 專案中註冊的字體（不在 font_fallback_data.dart 中但 CanvasKit 仍會請求）
const projectFonts = <String>[
  'roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2',
];

/// 透過 `where flutter` 尋找 Flutter SDK 根目錄
String? findFlutterSdk() {
  final result = Process.runSync('where', ['flutter'], runInShell: true);
  if (result.exitCode != 0) return null;
  for (final line in (result.stdout as String).trim().split('\n')) {
    final linePath = line.trim();
    if (linePath.endsWith('flutter.bat') || linePath.endsWith('flutter')) {
      final root = Directory(linePath).parent.parent.path;
      if (File(p.join(root, 'bin', 'flutter.bat')).existsSync()) {
        return root;
      }
    }
  }
  return null;
}

/// 從 font_fallback_data.dart 擷取 .woff2 路徑（去重）
List<String> parseFontUrls(String fallbackPath) {
  final content = File(fallbackPath).readAsStringSync();
  final regex = RegExp(r"'([a-z][^']*\.woff2)'");
  final seen = <String>{};
  return regex
      .allMatches(content)
      .map((m) => m.group(1)!)
      .where((url) => seen.add(url))
      .toList();
}

/// 下載 fallback 字型至快取目錄（跳過已存在檔案）
Future<void> downloadWebFonts(String projectDir) async {
  final flutterRoot = findFlutterSdk();
  if (flutterRoot == null) {
    logMessage('Warning: Cannot detect Flutter SDK, skipping font download.');
    return;
  }

  final fallbackPath = p.join(
    flutterRoot,
    'bin',
    'cache',
    'flutter_web_sdk',
    'lib',
    '_engine',
    'engine',
    'font_fallback_data.dart',
  );
  if (!File(fallbackPath).existsSync()) {
    logMessage('Warning: font_fallback_data.dart not found, skipping font download.');
    return;
  }
  logMessage('  Source: $fallbackPath');

  final urls = {...parseFontUrls(fallbackPath), ...projectFonts}.toList();
  logMessage('  Found ${urls.length} font entries.');

  final cacheDir = p.join(projectDir, 'web_fonts_cache');
  Directory(cacheDir).createSync(recursive: true);

  var downloaded = 0;
  var skipped = 0;
  var errors = 0;
  final client = HttpClient();

  for (var i = 0; i < urls.length; i++) {
    final url = urls[i];
    final localPath = p.join(cacheDir, url);
    final localFile = File(localPath);

    if (localFile.existsSync()) {
      skipped++;
      continue;
    }

    Directory(localFile.parent.path).createSync(recursive: true);
    final fullUrl = Uri.parse('$fontsCdnBase$url');

    try {
      final request = await client.getUrl(fullUrl);
      final response = await request.close();
      if (response.statusCode == 200) {
        await localFile.openWrite().addStream(response);
        downloaded++;
      } else {
        errors++;
        logMessage('  FAILED: HTTP ${response.statusCode} for $url');
      }
    } on Exception catch (e) {
      errors++;
      logMessage('  FAILED: $e for $url');
    }
  }

  client.close();
  logMessage(
      '  Font download complete: $downloaded downloaded, $skipped skipped, $errors errors.');
}

/// 將快取字型複製到 web 建置輸出目錄
void copyWebFontsToBuild(String projectDir, String webOutputDir) {
  final cacheDir = Directory(p.join(projectDir, 'web_fonts_cache'));
  if (!cacheDir.existsSync()) return;

  final fontsBuildDir = p.join(webOutputDir, 'fonts');
  Directory(fontsBuildDir).createSync(recursive: true);

  var copied = 0;
  var skipped = 0;

  for (final entity in cacheDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final relPath = p.relative(entity.path, from: cacheDir.path);
    final target = p.join(fontsBuildDir, relPath);
    if (File(target).existsSync()) {
      skipped++;
      continue;
    }
    Directory(p.dirname(target)).createSync(recursive: true);
    entity.copySync(target);
    copied++;
  }

  if (copied > 0 || skipped > 0) {
    logMessage('  Font copy to build: $copied copied, $skipped skipped.');
  }
}
