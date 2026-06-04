/// log.dart — 日誌輸出輔助函式
library;

import 'dart:io' show stdout;

/// 輸出一行帶時間戳的日誌訊息
void logMessage(String message) {
  final String ts = _formatTime(DateTime.now());
  print('[$ts][BUILD] $message');
}

/// 輸出不換行的帶時間戳日誌訊息（用於進度提示）
void logMessageInline(String message) {
  final String ts = _formatTime(DateTime.now());
  stdout.write('[$ts][BUILD] $message');
}

/// 將 [DateTime] 格式化為 HH:mm:ss 字串
String _formatTime(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';
}
