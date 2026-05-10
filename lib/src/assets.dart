/// assets.dart — pubspec.yaml 解析與資源檔案處理
import 'dart:convert' show utf8;
import 'dart:io' show File, Directory;

import 'package:markdown/markdown.dart' as md;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart' as y;

/// 從指定的 Flutter 專案目錄讀取 pubspec.yaml，回傳應用名稱與版本號。
///
/// 若檔案不存在則拋出例外；若 name 欄位為空則回傳空字串。
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

/// 掃描專案根目錄，收集 LICENSE 與 README*.md 資源檔案
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
  for (final entry in assets.entries) {
    final outPath = p.join(outDir, entry.key);
    var text = textCache[entry.value] ?? '';
    if (entry.key.endsWith('.html')) {
      File(outPath).writeAsStringSync(text);
    } else if (entry.key.endsWith('.txt')) {
      if (platform == 'windows') {
        // Windows 平台需要 CRLF 換行符與 UTF-8 BOM
        text = text.replaceAll('\n', '\r\n');
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
