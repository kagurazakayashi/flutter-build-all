/// web_fonts.dart — Web 內嵌字型：從 Flutter SDK 下載 fallback 字型並打包進 web 產物
library;

import 'dart:async' show Future;
import 'dart:io'
    show Directory, File, FileSystemEntity, HttpClient, HttpClientRequest,
        HttpClientResponse, Platform, Process, ProcessResult;

import 'package:path/path.dart' as p;

import 'log.dart';

/// Google Fonts CDN 基礎 URL
const String fontsCdnBase = 'https://fonts.gstatic.com/s/';

/// 專案中註冊的字體（不在 font_fallback_data.dart 中但 CanvasKit 仍會請求）
const List<String> projectFonts = <String>[
  'roboto/v32/KFOmCnqEu92Fr1Me4GZLCzYlKw.woff2',
];

/// 從環境變數讀取代理設定（優先使用明確指定值，否則偵測系統代理變數）
///
/// 回傳值為 Dart HttpClient.findProxy 所需的格式：
/// "PROXY host:port"（HTTP 代理）或 "SOCKS5 host:port"（SOCKS5 代理）。
String? resolveProxy(String? explicitProxy) {
  String? raw = explicitProxy;

  if (raw == null) {
    const List<String> envKeys = <String>[
      'HTTPS_PROXY',
      'https_proxy',
      'HTTP_PROXY',
      'http_proxy',
      'ALL_PROXY',
      'all_proxy',
    ];
    for (final String key in envKeys) {
      final String? val = Platform.environment[key];
      if (val != null && val.isNotEmpty) {
        raw = val;
        break;
      }
    }
  }

  if (raw == null || raw.isEmpty) return null;

  // 解析代理 URL（支援 http://host:port 與 socks5://host:port）
  final Uri? uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority) {
    // 無 scheme 時預設為 HTTP 代理
    return 'PROXY $raw';
  }

  final String hostPort = uri.host +
      (uri.hasPort ? ':${uri.port}' : '');
  final String scheme = uri.scheme.toLowerCase();

  switch (scheme) {
    case 'socks5':
      return 'SOCKS5 $hostPort';
    case 'http':
    case 'https':
      return 'PROXY $hostPort';
    default:
      return 'PROXY $raw';
  }
}

/// 透過系統命令尋找 Flutter SDK 根目錄
String? findFlutterSdk() {
  final String cmdName = Platform.isWindows ? 'where' : 'which';
  final ProcessResult result =
      Process.runSync(cmdName, ['flutter'], runInShell: true);
  if (result.exitCode != 0) return null;
  for (final String line
      in (result.stdout as String).trim().split('\n')) {
    final String linePath = line.trim();
    if (linePath.endsWith('flutter.bat') || linePath.endsWith('flutter')) {
      final String root = Directory(linePath).parent.parent.path;
      if (File(p.join(root, 'bin', 'flutter.bat')).existsSync()) {
        return root;
      }
    }
  }
  return null;
}

/// 從 font_fallback_data.dart 擷取 .woff2 路徑（去重）
List<String> parseFontUrls(String fallbackPath) {
  final String content = File(fallbackPath).readAsStringSync();
  final RegExp regex = RegExp(r"'([a-z][^']*\.woff2)'");
  final Set<String> seen = <String>{};
  return regex
      .allMatches(content)
      .map((RegExpMatch m) => m.group(1)!)
      .where((String url) => seen.add(url))
      .toList();
}

/// 下載 fallback 字型至快取目錄（跳過已存在檔案）
///
/// [proxy] 為代理伺服器 URL（如 http://127.0.0.1:23333），
/// 若為 null 則自動從環境變數 (HTTPS_PROXY / HTTP_PROXY / ALL_PROXY) 偵測。
Future<void> downloadWebFonts(String projectDir, {String? proxy}) async {
  final String? flutterRoot = findFlutterSdk();
  if (flutterRoot == null) {
    logMessage('Warning: Cannot detect Flutter SDK, skipping font download.');
    return;
  }

  final String fallbackPath = p.join(
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
    logMessage(
        'Warning: font_fallback_data.dart not found, skipping font download.');
    return;
  }
  logMessage('  Source: $fallbackPath');

  final List<String> urls =
      {...parseFontUrls(fallbackPath), ...projectFonts}.toList();
  logMessage('  Found ${urls.length} font entries.');

  final String? effectiveProxy = resolveProxy(proxy);
  if (effectiveProxy != null) {
    logMessage('  Using proxy: $effectiveProxy');
  }

  final String cacheDir = p.join(projectDir, 'web_fonts_cache');
  Directory(cacheDir).createSync(recursive: true);

  int downloaded = 0;
  int skipped = 0;
  int errors = 0;
  int consecutiveErrors = 0;
  final HttpClient client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 10);
  client.idleTimeout = const Duration(seconds: 30);

  if (effectiveProxy != null) {
    client.findProxy = (Uri url) => effectiveProxy;
  }

  try {
    for (int i = 0; i < urls.length; i++) {
      final String url = urls[i];
      final String localPath = p.join(cacheDir, url);
      final File localFile = File(localPath);

      if (localFile.existsSync()) {
        skipped++;
        consecutiveErrors = 0;
        continue;
      }

      Directory(localFile.parent.path).createSync(recursive: true);
      final Uri fullUrl = Uri.parse('$fontsCdnBase$url');

      try {
        final HttpClientRequest request = await client.getUrl(fullUrl);
        final HttpClientResponse response = await request.close().timeout(
          const Duration(seconds: 15),
        );
        if (response.statusCode == 200) {
          await localFile.openWrite().addStream(response).timeout(
            const Duration(seconds: 30),
          );
          downloaded++;
          consecutiveErrors = 0;
          logMessage('  Font [${i + 1}/${urls.length}] OK: $url');
        } else {
          errors++;
          consecutiveErrors++;
          logMessage(
              '  Font [${i + 1}/${urls.length}] FAIL: HTTP ${response.statusCode} for $url');
        }
      } on Exception catch (e) {
        errors++;
        consecutiveErrors++;
        logMessage('  Font [${i + 1}/${urls.length}] FAIL: $e for $url');
      }

      // 若連續 5 次請求全部失敗，判定 CDN 不可達，終止下載（避免無限制等待）
      if (consecutiveErrors >= 5) {
        logMessage(
            '  Warning: $consecutiveErrors consecutive failures, CDN ($fontsCdnBase) may be unreachable. Aborting font download.');
        break;
      }
    }
  } finally {
    client.close();
  }

  logMessage(
      '  Font download complete: $downloaded downloaded, $skipped skipped, $errors errors.');
}

/// 將快取字型複製到 web 建置輸出目錄
void copyWebFontsToBuild(String projectDir, String webOutputDir) {
  final Directory cacheDir = Directory(p.join(projectDir, 'web_fonts_cache'));
  if (!cacheDir.existsSync()) return;

  final String fontsBuildDir = p.join(webOutputDir, 'fonts');
  Directory(fontsBuildDir).createSync(recursive: true);

  int copied = 0;
  int skipped = 0;

  for (final FileSystemEntity entity in cacheDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final String relPath = p.relative(entity.path, from: cacheDir.path);
    final String target = p.join(fontsBuildDir, relPath);
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
