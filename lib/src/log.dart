/// log.dart — 日誌輸出輔助函式
import 'dart:io' show stdout;

/// 輸出一行帶時間戳的日誌訊息
void logMessage(String message) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  print('[$ts][BUILD] $message');
}

/// 輸出不換行的帶時間戳日誌訊息（用於進度提示）
void logMessageInline(String message) {
  final ts = DateTime.now().toIso8601String().substring(11, 19);
  stdout.write('[$ts][BUILD] $message');
}
