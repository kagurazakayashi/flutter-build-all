/// 平台相關常數定義
import 'dart:io' show Platform;

const allPlatforms = ['windows', 'linux', 'macos', 'web', 'android', 'ios'];

/// 需要桌面安裝腳本的平台
const desktopPlatforms = ['windows', 'linux', 'macos'];

/// 各平台的 Flutter build 輸出子目錄
const platformBuildDirs = <String, String>{
  'windows': 'build/windows/x64/runner/Release',
  'linux': 'build/linux/x64/release/bundle',
  'macos': 'build/macos/Build/Products/Release',
  'web': 'build/web',
  'android': 'build/app/outputs/flutter-apk',
  'ios': 'build/ios/iphoneos',
};

/// 各平台的執行檔副檔名
const platformExtensions = <String, String>{
  'windows': '.exe',
  'linux': '',
  'macos': '',
  'web': '',
  'android': '.apk',
  'ios': '',
};

/// 檢查指定平台是否可在當前 OS 上建置
bool isPlatformAvailable(String platform) {
  if (Platform.isWindows &&
      !const {'windows', 'web', 'android'}.contains(platform)) return false;
  if (Platform.isMacOS &&
      !const {'macos', 'ios', 'web', 'android'}.contains(platform))
    return false;
  if (Platform.isLinux && !const {'linux', 'web', 'android'}.contains(platform))
    return false;
  return true;
}
