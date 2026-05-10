/// dir_utils.dart — 目錄複製與合併輔助函式
import 'dart:io' show Directory, File;

import 'package:path/path.dart' as p;

/// 複製目錄內容至目標目錄（已存在子目錄則合併）
void copyDirectory(String src, String dst) {
  for (final entity in Directory(src).listSync()) {
    final target = p.join(dst, p.basename(entity.path));
    if (entity is Directory) {
      if (!Directory(target).existsSync()) {
        copyRecursive(entity.path, target);
      } else {
        mergeDirectory(entity.path, target);
      }
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

/// 遞迴複製整個目錄（目標不應已存在）
void copyRecursive(String src, String dst) {
  Directory(dst).createSync(recursive: true);
  for (final entity in Directory(src).listSync()) {
    final target = p.join(dst, p.basename(entity.path));
    if (entity is Directory) {
      copyRecursive(entity.path, target);
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

/// 合併目錄：將來源檔案遞迴複製至目標（覆蓋同名檔案）
void mergeDirectory(String src, String dst) {
  for (final entity in Directory(src).listSync(recursive: true)) {
    if (entity is! File) continue;
    final rel = p.relative(entity.path, from: src);
    final target = p.join(dst, rel);
    Directory(p.dirname(target)).createSync(recursive: true);
    entity.copySync(target);
  }
}
