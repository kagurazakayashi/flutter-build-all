// ignore_for_file: avoid_print

/// build_all.dart — Flutter 全平台建置 CLI 入口
///
/// 從 Flutter 專案根目錄執行此腳本，會自動讀取 pubspec.yaml 取得應用名稱與版本，
/// 並針對所有可用的平台進行建置。
/// 建置完成後會在 bin/ 目錄下產生各平台的輸出資料夾，
/// 內含執行檔、README、LICENSE 以及平台對應的安裝腳本。
library;

import 'dart:io';

import 'package:args/args.dart';

import 'package:flutter_build_all/build_all.dart';

/// 解析 on/off 字串為布林值
bool _parseOnOff(String? value, {required bool defaultValue}) {
  if (value == null || value.isEmpty) return defaultValue;
  return value.trim().toLowerCase() == 'on';
}

/// 讀取簡單的 .ini 設定檔，回傳 section.key → value 對應。
Map<String, String> _parseIniFile(String path) {
  final File file = File(path);
  if (!file.existsSync()) throw Exception('Config file not found: $path');

  final Map<String, String> result = <String, String>{};
  String section = '';

  for (String line in file.readAsLinesSync()) {
    line = line.trim();
    if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) continue;

    if (line.startsWith('[') && line.endsWith(']')) {
      section = line.substring(1, line.length - 1).trim();
      continue;
    }

    // 支援 = 和 : 分隔符
    final int sepIndex = line.indexOf('=');
    if (sepIndex == -1) {
      final int colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;
      final String key = line.substring(0, colonIndex).trim();
      final String val = line.substring(colonIndex + 1).trim();
      result[section.isEmpty ? key : '$section.$key'] = val;
    } else {
      final String key = line.substring(0, sepIndex).trim();
      final String val = line.substring(sepIndex + 1).trim();
      result[section.isEmpty ? key : '$section.$key'] = val;
    }
  }

  return result;
}

/// 解析字串值（可為 null）：CLI 參數 > INI 設定檔 > 預設值
String? _resolveStr(
  ArgResults args,
  Map<String, String>? iniVals,
  String key, [
  String? defaultValue,
  String section = 'build',
]) {
  if (args.wasParsed(key)) return args[key] as String?;
  if (iniVals != null) {
    final String? v = iniVals['$section.$key'];
    if (v != null) return v;
  }
  return defaultValue;
}

/// 解析字串值（必須非空）：CLI 參數 > INI 設定檔 > 預設值
String _resolveStrReq(
  ArgResults args,
  Map<String, String>? iniVals,
  String key,
  String defaultValue, [
  String section = 'build',
]) {
  if (args.wasParsed(key)) return (args[key] as String?) ?? defaultValue;
  if (iniVals != null) {
    final String? v = iniVals['$section.$key'];
    if (v != null) return v;
  }
  return defaultValue;
}

/// 解析 on/off 布林值：CLI 參數 > INI 設定檔 > 預設值
bool _resolveOnOff(
  ArgResults args,
  Map<String, String>? iniVals,
  String key,
  bool defaultValue, [
  String section = 'build',
]) {
  if (args.wasParsed(key)) {
    return _parseOnOff(args[key] as String?, defaultValue: defaultValue);
  }
  if (iniVals != null) {
    final String? v = iniVals['$section.$key'];
    if (v != null) return _parseOnOff(v, defaultValue: defaultValue);
  }
  return defaultValue;
}

/// CLI 進入點：解析命令列參數與 INI 設定檔後執行全平台建置
void main(List<String> arguments) async {
  final ArgParser parser = ArgParser()
    ..addFlag(
      'test',
      abbr: 't',
      help: 'Test the script environment (no actual build)',
      negatable: false,
    )
    ..addOption(
      'config',
      abbr: 'f',
      help: 'Path to .ini configuration file',
    )
    ..addOption(
      'name',
      abbr: 'n',
      help: 'Custom name for output folders (default: from pubspec.yaml)',
    )
    ..addOption(
      'target',
      abbr: 'p',
      help: 'Comma-separated platforms to build, e.g. "windows,linux,web"',
    )
    ..addOption(
      'project-dir',
      abbr: 'r',
      help: 'Flutter project root directory (default: current directory)',
    )
    ..addOption(
      'appver',
      abbr: 'v',
      help: 'Application version for output folder naming',
    )
    ..addOption(
      'appdesc',
      abbr: 'd',
      help: 'Application description for desktop entries',
    )
    ..addOption(
      'appgeneric',
      abbr: 'g',
      help: 'Generic name for desktop entries',
    )
    ..addOption(
      'appcategory',
      abbr: 'c',
      help: 'Desktop entry categories (default: Utility)',
      defaultsTo: 'Utility',
    )
    ..addOption(
      'appicon',
      abbr: 'a',
      help:
          'Path to app icon file within the project (default: web/icons/Icon-192.png)',
      defaultsTo: 'web/icons/Icon-192.png',
    )
    ..addOption(
      'appiconbg',
      abbr: 'B',
      help: 'Path to background icon image (overrides auto-detection of ico/iconb.png)',
    )
    ..addOption(
      'appidentifier',
      abbr: 'I',
      help:
          'Bundle identifier for macOS (auto-derived from pubspec name if not specified)',
    )
    ..addOption(
      'appmacoscategory',
      abbr: 'm',
      help:
          'macOS app category for Info.plist (default: public.app-category.utilities)',
      defaultsTo: 'public.app-category.utilities',
    )
    ..addOption(
      'jobs',
      abbr: 'j',
      help: 'Number of parallel build jobs (0=CPU cores, default: sequential)',
    )
    ..addOption(
      'web-base-href',
      abbr: 'b',
      help: 'Base href for web build (default: /)',
      defaultsTo: '/',
    )
    ..addOption(
      'analyze',
      abbr: 'A',
      help: 'Run flutter analyze before build (default: on)',
      defaultsTo: 'on',
      allowed: ['on', 'off'],
      allowedHelp: {
        'on': 'Run flutter analyze',
        'off': 'Skip flutter analyze',
      },
    )
    ..addOption(
      'icon',
      abbr: 'i',
      help: 'Auto-generate app icons before build (default: on)',
      defaultsTo: 'on',
      allowed: ['on', 'off'],
      allowedHelp: {
        'on': 'Generate icons via flutter-icon-creator',
        'off': 'Skip icon generation',
      },
    )
    ..addOption(
      'l10n',
      abbr: 'l',
      help: 'Run flutter gen-l10n before build (default: on)',
      defaultsTo: 'on',
      allowed: ['on', 'off'],
      allowedHelp: {
        'on': 'Run flutter gen-l10n',
        'off': 'Skip flutter gen-l10n',
      },
    )
    ..addOption(
      'web-embed-fonts',
      abbr: 'w',
      help:
          'Download & embed Flutter fallback fonts into web build (default: off)',
      defaultsTo: 'off',
      allowed: ['on', 'off'],
      allowedHelp: {
        'on': 'Download fonts and embed into web output',
        'off': 'Do not embed fonts',
      },
    )
    ..addOption(
      'proxy',
      abbr: 'x',
      help: 'Proxy server for font downloads (e.g. http://127.0.0.1:1080).'
          ' Also reads HTTPS_PROXY / HTTP_PROXY / ALL_PROXY env vars.',
    );

  late ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln(parser.usage);
    exit(64);
  }

  // 載入 INI 設定檔
  Map<String, String>? iniVals;
  final String? configPath = args['config'] as String?;
  final String? effectiveConfigPath = configPath ??
      (File('build-all.ini').existsSync() ? 'build-all.ini' : null);
  if (effectiveConfigPath != null) {
    try {
      iniVals = _parseIniFile(effectiveConfigPath);
      _log('Loaded config from $effectiveConfigPath');
    } on Exception catch (e) {
      _log('WARN: cannot read config file $effectiveConfigPath: $e');
    }
  }

  // 解析各項設定，優先順序：CLI 參數 > INI 設定檔 > 預設值
  final String? effectiveName = _resolveStr(
    args, iniVals, 'name', null, 'project',
  );
  final String? effectiveTarget = _resolveStr(
    args, iniVals, 'target', null, 'platform',
  );
  final String? effectiveAppver = _resolveStr(
    args, iniVals, 'appver', null, 'project',
  );
  final String effectiveAppdesc = _resolveStrReq(
    args, iniVals, 'appdesc', '', 'project',
  );
  final String effectiveAppgeneric = _resolveStrReq(
    args, iniVals, 'appgeneric', '', 'project',
  );
  final String effectiveAppcategory = _resolveStrReq(
    args, iniVals, 'appcategory', 'Utility', 'desktop',
  );
  final String effectiveAppicon = _resolveStrReq(
    args, iniVals, 'appicon', 'web/icons/Icon-192.png', 'desktop',
  );
  final String effectiveAppidentifier = _resolveStrReq(
    args, iniVals, 'appidentifier', '', 'desktop',
  );
  final String effectiveAppmacoscategory = _resolveStrReq(
    args, iniVals, 'appmacoscategory', 'public.app-category.utilities', 'desktop',
  );
  final String effectiveWebBaseHref = _resolveStrReq(
    args, iniVals, 'web-base-href', '/', 'web',
  );
  final String? effectiveAppiconbg = _resolveStr(
    args, iniVals, 'appiconbg', null, 'desktop',
  );
  final String? effectiveProjectDir = _resolveStr(
    args, iniVals, 'project-dir', null, 'project',
  );
  final String? effectiveJobs = _resolveStr(
    args, iniVals, 'jobs', null, 'build',
  );
  final int? effectiveJobsInt = effectiveJobs != null
      ? int.tryParse(effectiveJobs)
      : null;
  final bool effectiveAnalyze = _resolveOnOff(
    args, iniVals, 'analyze', true, 'build',
  );
  final bool effectiveIcon = _resolveOnOff(
    args, iniVals, 'icon', true, 'build',
  );
  final bool effectiveL10n = _resolveOnOff(
    args, iniVals, 'l10n', true, 'build',
  );
  final bool effectiveWebEmbedFonts = _resolveOnOff(
    args, iniVals, 'web-embed-fonts', false, 'web',
  );
  final String? effectiveProxy = _resolveStr(
    args, iniVals, 'proxy', null, 'web',
  );

  if (args['test'] as bool) {
    _log('=== Test Mode ===');
    _log('Checking environment ...');
    _log('');

    _log('Dart: ${Platform.version}');
    _log('OS: ${Platform.operatingSystem}');

    try {
      final ProcessResult result =
          await Process.run('flutter', ['--version'], runInShell: true);
      if (result.exitCode == 0) {
        _log('Flutter: available');
        _log('  ${(result.stdout as String).trim().split('\n').first}');
      } else {
        _log('Flutter: NOT available');
        exit(1);
      }
    } on ProcessException {
      _log('Flutter: NOT found in PATH');
      exit(1);
    }

    _log('');
    _log('Available platforms on this OS:');
    for (final String p in allPlatforms) {
      final bool ok = isPlatformAvailable(p);
      final String mark = ok ? 'OK' : 'SKIP (not supported on this OS)';
      _log('  $p: $mark');
    }

    _log('');
    _log('Dependencies:');
    _log('  yaml: available (dart package)');
    _log('  markdown: available (dart package)');

    _log('');
    try {
      final (String name, String version) =
          getPubspecInfo(Directory.current.path);
      _log('pubspec.yaml detected:');
      _log('  name: $name');
      _log('  version: ${version.isNotEmpty ? version : '(none)'}');
    } on Exception catch (e) {
      _log('pubspec.yaml: ${e.toString()}');
    }

    _log('');
    _log('Config file: ${effectiveConfigPath ?? '(none)'}');
    _log('=== Test completed ===');
  } else {
    try {
      await buildAll(
        nameOverride: effectiveName,
        targetFilter: effectiveTarget,
        appver: effectiveAppver,
        appdesc: effectiveAppdesc,
        appgeneric: effectiveAppgeneric,
        appcategory: effectiveAppcategory,
        appicon: effectiveAppicon,
        appiconbg: effectiveAppiconbg,
        appidentifier: effectiveAppidentifier,
        appmacoscategory: effectiveAppmacoscategory,
        projectDir: effectiveProjectDir,
        jobs: effectiveJobsInt,
        webBaseHref: effectiveWebBaseHref,
        analyze: effectiveAnalyze,
        icon: effectiveIcon,
        l10n: effectiveL10n,
        webEmbedFonts: effectiveWebEmbedFonts,
        webFontProxy: effectiveProxy,
      );
    } on Exception catch (e) {
      stderr.writeln('Error: ${e.toString()}');
      exit(1);
    }
  }
}

/// 輸出一行帶時間戳的日誌訊息
void _log(String message) {
  final String ts =
      '${DateTime.now().hour.toString().padLeft(2, '0')}:'
      '${DateTime.now().minute.toString().padLeft(2, '0')}:'
      '${DateTime.now().second.toString().padLeft(2, '0')}';
  print('[$ts][BUILD] $message');
}
