/// templates.dart — 模板檔案尋找與路徑輔助
import 'dart:io' show File, Platform, Directory;

import 'package:path/path.dart' as p;

/// 回傳此套件根目錄（模板檔案所在）。
///
/// 根據目前腳本路徑向上推算：若位於 lib/src/ 則回傳上兩層（套件根目錄），
/// 否則回傳上一層（bin/ 的上層即為套件根目錄）。
String get scriptDir {
  final scriptPath = File(Platform.script.toFilePath()).absolute.path;
  final libDir = p.dirname(scriptPath); // lib/src 或 bin
  if (libDir.endsWith('src')) {
    return p.dirname(p.dirname(libDir));
  } else {
    return p.dirname(libDir);
  }
}

/// 尋找模板檔案：先嘗試 [scriptDirPath]，若不存在則嘗試目前工作目錄中的同名檔案
File? findTemplate(String scriptDirPath) {
  final f = File(scriptDirPath);
  if (f.existsSync()) return f;
  final cwdPath = p.join(Directory.current.path, p.basename(scriptDirPath));
  final cwd = File(cwdPath);
  return cwd.existsSync() ? cwd : null;
}
