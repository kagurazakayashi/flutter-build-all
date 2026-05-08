/// Flutter 全平台建置腳本 —— CLI 入口
///
/// 從 Flutter 專案根目錄執行此腳本，會自動讀取 pubspec.yaml 取得應用名稱與版本，
/// 並針對所有可用的平台進行建置。
/// 建置完成後會在 bin/ 目錄下產生各平台的輸出資料夾，
/// 內含執行檔、README、LICENSE 以及平台對應的安裝腳本。
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
  final file = File(path);
  if (!file.existsSync()) throw Exception('Config file not found: $path');

  final result = <String, String>{};
  var section = '';

  for (var line in file.readAsLinesSync()) {
    line = line.trim();
    if (line.isEmpty || line.startsWith(';') || line.startsWith('#')) continue;

    if (line.startsWith('[') && line.endsWith(']')) {
      section = line.substring(1, line.length - 1).trim();
      continue;
    }

    // 支援 = 和 : 分隔符
    final sepIndex = line.indexOf('=');
    if (sepIndex == -1) {
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) continue;
      final key = line.substring(0, colonIndex).trim();
      final val = line.substring(colonIndex + 1).trim();
      result[section.isEmpty ? key : '$section.$key'] = val;
    } else {
      final key = line.substring(0, sepIndex).trim();
      final val = line.substring(sepIndex + 1).trim();
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
    final v = iniVals['$section.$key'];
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
    final v = iniVals['$section.$key'];
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
    final v = iniVals['$section.$key'];
    if (v != null) return _parseOnOff(v, defaultValue: defaultValue);
  }
  return defaultValue;
}

void main(List<String> arguments) async {
  final parser = ArgParser()
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
  final configPath = args['config'] as String?;
  final effectiveConfigPath = configPath ??
      (File('build-all.ini').existsSync() ? 'build-all.ini' : null);
  if (effectiveConfigPath != null) {
    try {
      iniVals = _parseIniFile(effectiveConfigPath);
      _logInfo('Loaded config from $effectiveConfigPath');
    } on Exception catch (e) {
      _logInfo('WARN: cannot read config file $effectiveConfigPath: $e');
    }
  }

  // 解析各項設定，優先順序：CLI 參數 > INI 設定檔 > 預設值
  final effectiveName = _resolveStr(
    args, iniVals, 'name', null, 'project',
  );
  final effectiveTarget = _resolveStr(
    args, iniVals, 'target', null, 'platform',
  );
  final effectiveAppver = _resolveStr(
    args, iniVals, 'appver', null, 'project',
  );
  final effectiveAppdesc = _resolveStrReq(
    args, iniVals, 'appdesc', '', 'project',
  );
  final effectiveAppgeneric = _resolveStrReq(
    args, iniVals, 'appgeneric', '', 'project',
  );
  final effectiveAppcategory = _resolveStrReq(
    args, iniVals, 'appcategory', 'Utility', 'desktop',
  );
  final effectiveAppicon = _resolveStrReq(
    args, iniVals, 'appicon', 'web/icons/Icon-192.png', 'desktop',
  );
  final effectiveAppidentifier = _resolveStrReq(
    args, iniVals, 'appidentifier', '', 'desktop',
  );
  final effectiveAppmacoscategory = _resolveStrReq(
    args, iniVals, 'appmacoscategory', 'public.app-category.utilities', 'desktop',
  );
  final effectiveWebBaseHref = _resolveStrReq(
    args, iniVals, 'web-base-href', '/', 'web',
  );
  final effectiveAppiconbg = _resolveStr(
    args, iniVals, 'appiconbg', null, 'desktop',
  );
  final effectiveProjectDir = _resolveStr(
    args, iniVals, 'project-dir', null, 'project',
  );
  final effectiveJobs = _resolveStr(
    args, iniVals, 'jobs', null, 'build',
  );
  final effectiveJobsInt = effectiveJobs != null
      ? int.tryParse(effectiveJobs)
      : null;
  final effectiveAnalyze = _resolveOnOff(
    args, iniVals, 'analyze', true, 'build',
  );
  final effectiveIcon = _resolveOnOff(
    args, iniVals, 'icon', true, 'build',
  );
  final effectiveL10n = _resolveOnOff(
    args, iniVals, 'l10n', true, 'build',
  );
  final effectiveWebEmbedFonts = _resolveOnOff(
    args, iniVals, 'web-embed-fonts', false, 'web',
  );

  if (args['test'] as bool) {
    _logTest('=== Test Mode ===');
    _logTest('Checking environment ...');
    _logTest('');

    _logTest('Dart: ${Platform.version}');
    _logTest('OS: ${Platform.operatingSystem}');

    try {
      final result =
          await Process.run('flutter', ['--version'], runInShell: true);
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

    _logTest('');
    _logTest('Available platforms on this OS:');
    for (final p in allPlatforms) {
      final ok = isPlatformAvailable(p);
      final mark = ok ? 'OK' : 'SKIP (not supported on this OS)';
      _logTest('  $p: $mark');
    }

    _logTest('');
    _logTest('Dependencies:');
    _logTest('  yaml: available (dart package)');
    _logTest('  markdown: available (dart package)');

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
    _logTest('Config file: ${effectiveConfigPath ?? '(none)'}');
    _logTest('=== Test completed ===');
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
      );
    } on Exception catch (e) {
      stderr.writeln('Error: ${e.toString()}');
      exit(1);
    }
  }
}

void _logInfo(String message) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  print('[$ts][BUILD] $message');
}

void _logTest(String message) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  print('[$ts][BUILD] $message');
}
