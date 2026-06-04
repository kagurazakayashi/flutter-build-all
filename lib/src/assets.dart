/// assets.dart — pubspec.yaml 解析與資源檔案處理
library;

import 'dart:convert' show utf8;
import 'dart:io' show File, Directory, FileSystemEntity, IOSink;

import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

/// 從指定的 Flutter 專案目錄讀取 pubspec.yaml，回傳應用名稱與版本號。
///
/// 若檔案不存在則拋出例外；若 name 欄位為空則回傳空字串。
(String name, String version) getPubspecInfo(String projectDir) {
  final String pubspecPath = p.join(projectDir, 'pubspec.yaml');
  final File file = File(pubspecPath);
  if (!file.existsSync()) {
    throw Exception(
      'pubspec.yaml not found. This directory is not a Flutter project.',
    );
  }

  final String content = file.readAsStringSync();
  final y.YamlMap doc = y.loadYaml(content) as y.YamlMap;
  final String name = (doc['name'] as String?) ?? '';
  final String version = (doc['version'] as String?) ?? '';
  return (name, version);
}

/// 掃描專案根目錄，收集 LICENSE 與 README*.md 資源檔案
Map<String, String> findAssetFiles(String projectDir) {
  final Map<String, String> assets = <String, String>{};
  final Directory dir = Directory(projectDir);
  for (final FileSystemEntity entity in dir.listSync()) {
    if (entity is! File) continue;
    final String fileName = p.basename(entity.path);
    if (fileName == 'LICENSE') {
      assets['LICENSE.txt'] = fileName;
    } else if (fileName.startsWith('README') && fileName.endsWith('.md')) {
      final String outName =
          '${fileName.substring(0, fileName.length - 3)}.html';
      assets[outName] = fileName;
    }
  }
  return assets;
}

/// 將 Markdown 文字轉為 GitHub Flavored HTML
String convertMarkdown(String text) {
  return md.markdownToHtml(text, extensionSet: md.ExtensionSet.gitHubFlavored);
}

/// 將資源檔案寫入建置輸出目錄
void writeAssetFiles(
  String outDir,
  String platform,
  Map<String, String> assets,
  Map<String, String> textCache,
) {
  for (final MapEntry<String, String> entry in assets.entries) {
    final String outPath = p.join(outDir, entry.key);
    String text = textCache[entry.value] ?? '';
    if (entry.key.endsWith('.html')) {
      File(outPath).writeAsStringSync(text);
    } else if (entry.key.endsWith('.txt')) {
      if (platform == 'windows') {
        // Windows 平台需要 CRLF 換行符與 UTF-8 BOM
        text = text.replaceAll('\n', '\r\n');
        final File file = File(outPath);
        final IOSink sink = file.openWrite();
        sink.add(const [0xEF, 0xBB, 0xBF]);
        sink.add(utf8.encode(text));
        sink.close();
      } else {
        File(outPath).writeAsStringSync(text);
      }
    }
  }
}
