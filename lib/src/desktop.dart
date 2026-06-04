/// desktop.dart — 桌面平台後處理：Linux 安裝腳本、Windows 捷徑、macOS Bundle
library;

import 'dart:convert' show utf8;
import 'dart:io' show File, IOSink, Platform, Process;

import 'package:path/path.dart' as p;

import 'log.dart';
import 'templates.dart';

/// 為 Linux 建置產物產生 install_app.sh 安裝腳本
void handleLinuxDesktop({
  required String outDir,
  required String name,
  required String ext,
  required String appicon,
  required String appdesc,
  required String appgeneric,
  required String appcategory,
}) {
  final String iconFile = p.basename(appicon);
  final String iconName = p.basenameWithoutExtension(iconFile);

  if (File(appicon).existsSync()) {
    final String dst = p.join(outDir, iconFile);
    if (!File(dst).existsSync()) {
      File(appicon).copySync(dst);
    }
  }

  final String tmplPath = p.join(scriptDir, 'install_app.sh.tmpl');
  final File? tmplFile = findTemplate(tmplPath);
  if (tmplFile == null) {
    logMessage('  Warning: install_app.sh.tmpl not found, skipping install script');
    return;
  }

  String template = tmplFile.readAsStringSync();

  final Map<String, String> replacements = {
    '{{APP_NAME}}': name,
    '{{APP_EXEC}}': '$name$ext',
    '{{APP_ICON_FILE}}': iconFile,
    '{{APP_ICON_NAME}}': iconName,
    '{{APP_COMMENT}}': appdesc.isNotEmpty ? appdesc : name,
    '{{APP_GENERIC_NAME}}': appgeneric.isNotEmpty ? appgeneric : name,
    '{{APP_CATEGORIES}}': appcategory,
    '{{APP_DESKTOP_NAME}}': name,
  };

  for (final MapEntry<String, String> entry in replacements.entries) {
    template = template.replaceAll(entry.key, entry.value);
  }

  final String scriptPath = p.join(outDir, 'install_app.sh');
  File(scriptPath).writeAsStringSync(template);
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['755', scriptPath]);
  }
}

/// 為 Windows 建置產物產生 install_app.ps1 PowerShell 安裝腳本
void handleWindowsShortcut({
  required String outDir,
  required String name,
  required String ext,
  required String appdesc,
  required String projectDir,
}) {
  // 依序搜尋三個可能的 .ico 圖示檔案位置
  final List<String> icoPaths = [
    p.join(projectDir, 'ico', 'icon.ico'),
    p.join(projectDir, 'icon.ico'),
    p.join(projectDir, 'windows', 'runner', 'resources', 'app_icon.ico'),
  ];
  String iconFile = '';
  for (final String icoPath in icoPaths) {
    if (File(icoPath).existsSync()) {
      iconFile = p.basename(icoPath);
      final String dst = p.join(outDir, iconFile);
      if (!File(dst).existsSync()) {
        File(icoPath).copySync(dst);
      }
      break;
    }
  }

  final String tmplPath = p.join(scriptDir, 'install_app.ps1.tmpl');
  final File? tmplFile = findTemplate(tmplPath);
  if (tmplFile == null) {
    logMessage('  Warning: install_app.ps1.tmpl not found, skipping install script');
    return;
  }

  String template = tmplFile.readAsStringSync();

  final Map<String, String> replacements = {
    '{{APP_NAME}}': name,
    '{{APP_EXEC}}': '$name$ext',
    '{{APP_ICON}}': iconFile,
    '{{APP_COMMENT}}': appdesc.isNotEmpty ? appdesc : name,
    '{{APP_DESKTOP_NAME}}': name,
  };

  for (final MapEntry<String, String> entry in replacements.entries) {
    template = template.replaceAll(entry.key, entry.value);
  }

  final String scriptPath = p.join(outDir, 'install_app.ps1');
  final File file = File(scriptPath);
  final IOSink sink = file.openWrite();
  // 寫入 UTF-8 BOM 標頭（0xEF 0xBB 0xBF），PowerShell 需要才能正確解析
  sink.add(const [0xEF, 0xBB, 0xBF]);
  sink.add(utf8.encode(template));
  sink.close();
}

/// 為 macOS 建置產物產生 install_app.sh 安裝腳本與自訂 Info.plist
void handleMacosBundle({
  required String outDir,
  required String name,
  required String appver,
  required String appdesc,
  required String appgeneric,
  required String appidentifier,
  required String appmacoscategory,
}) {
  // 讀取 Info.plist 模板
  final String tmplPath = p.join(scriptDir, 'Info.plist.tmpl');
  final File? tmplFile = findTemplate(tmplPath);
  String plistTemplate;
  if (tmplFile != null) {
    plistTemplate = tmplFile.readAsStringSync();
  } else {
    logMessage('  Warning: Info.plist.tmpl not found, using built-in template');
    plistTemplate = _defaultPlistTemplate;
  }

  final Map<String, String> plistReplacements = {
    '{{APP_DISPLAY_NAME}}': name,
    '{{APP_EXEC}}': name,
    '{{APP_ICON_NAME}}': name,
    '{{APP_IDENTIFIER}}': appidentifier,
    '{{APP_NAME}}': name,
    '{{APP_VERSION}}': appver,
    '{{APP_MACOS_CATEGORY}}': appmacoscategory,
    '{{APP_COPYRIGHT}}': '',
  };

  String plistContent = plistTemplate;
  for (final MapEntry<String, String> entry in plistReplacements.entries) {
    plistContent = plistContent.replaceAll(entry.key, entry.value);
  }

  final String plistPath = p.join(outDir, 'Info.plist');
  File(plistPath).writeAsStringSync(plistContent);

  // 產生 install_app.sh
  final String installScript = '''#!/bin/sh
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

  final String scriptPath = p.join(outDir, 'install_app.sh');
  File(scriptPath).writeAsStringSync(installScript);
  if (!Platform.isWindows) {
    Process.runSync('chmod', ['755', scriptPath]);
  }
}

/// 內建預設 Info.plist 模板（在找不到外部模板時使用）
const String _defaultPlistTemplate = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>{{APP_DISPLAY_NAME}}</string>
    <key>CFBundleExecutable</key>
    <string>{{APP_EXEC}}</string>
    <key>CFBundleIconFile</key>
    <string>{{APP_ICON_NAME}}</string>
    <key>CFBundleIdentifier</key>
    <string>{{APP_IDENTIFIER}}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>{{APP_NAME}}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>{{APP_VERSION}}</string>
    <key>CFBundleVersion</key>
    <string>{{APP_VERSION}}</string>
    <key>LSApplicationCategoryType</key>
    <string>{{APP_MACOS_CATEGORY}}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>{{APP_COPYRIGHT}}</string>
</dict>
</plist>
''';
