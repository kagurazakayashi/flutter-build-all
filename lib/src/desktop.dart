/// desktop.dart — 桌面平台後處理：Linux 安裝腳本、Windows 捷徑、macOS Bundle
library;

import 'dart:convert' show utf8;
import 'dart:io' show File, Platform, Process;

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
  final iconFile = p.basename(appicon);
  final iconName = p.basenameWithoutExtension(iconFile);

  if (File(appicon).existsSync()) {
    final dst = p.join(outDir, iconFile);
    if (!File(dst).existsSync()) {
      File(appicon).copySync(dst);
    }
  }

  final tmplPath = p.join(scriptDir, 'install_app.sh.tmpl');
  final tmplFile = findTemplate(tmplPath);
  if (tmplFile == null) {
    logMessage('  Warning: install_app.sh.tmpl not found, skipping install script');
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
  required String appgeneric,
  required String projectDir,
}) {
  // 依序搜尋三個可能的 .ico 圖示檔案位置
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

  final tmplPath = p.join(scriptDir, 'install_app.ps1.tmpl');
  final tmplFile = findTemplate(tmplPath);
  if (tmplFile == null) {
    logMessage('  Warning: install_app.ps1.tmpl not found, skipping install script');
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
  final file = File(scriptPath);
  final sink = file.openWrite();
  // 寫入 UTF-8 BOM 標頭（0xEF 0xBB 0xBF），PowerShell 需要才能正確解析
  sink.add(const [0xEF, 0xBB, 0xBF]);
  sink.add(utf8.encode(template));
  sink.close();
}

/// 為 macOS 建置產物產生 install_app.sh 安裝腳本
void handleMacosBundle({
  required String outDir,
  required String name,
  required String appver,
  required String appdesc,
  required String appgeneric,
  required String appidentifier,
  required String appmacoscategory,
}) {
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
