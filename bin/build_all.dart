/// Flutter 全平台建置腳本 —— CLI 入口
///
/// 從 Flutter 專案根目錄執行此腳本，會自動讀取 pubspec.yaml 取得應用名稱與版本，
/// 並針對所有可用的平台進行建置。
/// 建置完成後會在 bin/ 目錄下產生各平台的輸出資料夾，
/// 內含執行檔、README、LICENSE 以及平台對應的安裝腳本。
import 'dart:io';

import 'package:args/args.dart';

import 'package:flutter_build_all/build_all.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag(
      'test',
      abbr: 't',
      help: 'Test the script environment (no actual build)',
      negatable: false,
    )
    ..addOption(
      'name',
      help: 'Custom name for output folders (default: from pubspec.yaml)',
    )
    ..addOption(
      'target',
      help: 'Comma-separated platforms to build, e.g. "windows,linux,web"',
    )
    ..addOption(
      'project-dir',
      help: 'Flutter project root directory (default: current directory)',
    )
    ..addOption(
      'appver',
      help: 'Application version for output folder naming',
    )
    ..addOption(
      'appdesc',
      help: 'Application description for desktop entries',
    )
    ..addOption(
      'appgeneric',
      help: 'Generic name for desktop entries',
    )
    ..addOption(
      'appcategory',
      help: 'Desktop entry categories (default: Utility)',
      defaultsTo: 'Utility',
    )
    ..addOption(
      'appicon',
      help:
          'Path to app icon file within the project (default: web/icons/Icon-192.png)',
      defaultsTo: 'web/icons/Icon-192.png',
    )
    ..addOption(
      'appidentifier',
      help:
          'Bundle identifier for macOS (auto-derived from pubspec name if not specified)',
    )
    ..addOption(
      'appmacoscategory',
      help:
          'macOS app category for Info.plist (default: public.app-category.utilities)',
      defaultsTo: 'public.app-category.utilities',
    )
    ..addOption(
      'jobs',
      help: 'Number of parallel build jobs (0=CPU cores, default: sequential)',
    )
    ..addOption(
      'web-renderer',
      help: 'Web renderer: auto, canvaskit, or html (default: auto)',
      defaultsTo: 'auto',
      allowed: ['auto', 'canvaskit', 'html'],
    )
    ..addFlag(
      'skip-analyze',
      help: 'Skip flutter analyze step',
      negatable: false,
    )
    ..addFlag(
      'no-web',
      help: 'Skip web platform build',
      negatable: false,
    );

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln(parser.usage);
    exit(64); // usage error
  }

  if (args['test'] as bool) {
    // ---- 自我測試模式 ----
    _logTest('=== Test Mode ===');
    _logTest('Checking environment ...');
    _logTest('');

    // Python 版本 -> Dart 版本
    _logTest('Dart: ${Platform.version}');
    _logTest('OS: ${Platform.operatingSystem}');

    // 檢查 Flutter 是否可用
    try {
      final result = await Process.run('flutter', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        _logTest('Flutter: available');
        _logTest('  ${(result.stdout as String).trim().split('\n').first}');
      } else {
        _logTest('Flutter: NOT available');
        exit(1);
      }
    } on ProcessException {
      _logTest('Flutter: NOT found in PATH');
      exit(1);
    }

    // 列出可用平台
    _logTest('');
    _logTest('Available platforms on this OS:');
    for (final p in allPlatforms) {
      final ok = isPlatformAvailable(p);
      final mark = ok ? 'OK' : 'SKIP (not supported on this OS)';
      _logTest('  $p: $mark');
    }

    // 檢查可選依賴
    _logTest('');
    _logTest('Dependencies:');
    _logTest('  yaml: available (dart package)');
    _logTest('  markdown: available (dart package)');

    // 嘗試解析 pubspec.yaml
    _logTest('');
    try {
      final (name, version) = getPubspecInfo(Directory.current.path);
      _logTest('pubspec.yaml detected:');
      _logTest('  name: $name');
      _logTest('  version: ${version.isNotEmpty ? version : '(none)'}');
    } on Exception catch (e) {
      _logTest('pubspec.yaml: ${e.toString()}');
    }

    _logTest('');
    _logTest('=== Test completed ===');
  } else {
    // ---- 一般建置模式 ----
    try {
      await buildAll(
        nameOverride: args['name'] as String?,
        targetFilter: args['target'] as String?,
        appver: args['appver'] as String?,
        appdesc: (args['appdesc'] as String?) ?? '',
        appgeneric: (args['appgeneric'] as String?) ?? '',
        appcategory: args['appcategory'] as String,
        appicon: args['appicon'] as String,
        appidentifier: (args['appidentifier'] as String?) ?? '',
        appmacoscategory: args['appmacoscategory'] as String,
        projectDir: args['project-dir'] as String?,
        jobs: args['jobs'] != null ? int.parse(args['jobs'] as String) : null,
        webRenderer: args['web-renderer'] as String,
        skipAnalyze: args['skip-analyze'] as bool,
        skipWeb: args['no-web'] as bool,
      );
    } on Exception catch (e) {
      stderr.writeln('Error: ${e.toString()}');
      exit(1);
    }
  }
}

void _logTest(String message) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  print('[$ts][BUILD] $message');
}
