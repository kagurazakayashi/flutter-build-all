/// platforms.dart — 平台可用性檢查與篩選
library;

import 'constants.dart';
import 'log.dart';

/// 回傳目前 OS 可建置的平台清單
List<String> getAvailablePlatforms() {
  return allPlatforms.where(isPlatformAvailable).toList();
}

/// 根據 [targetFilter] 篩選平台清單，支援逗號分隔的多平台指定
List<String> filterPlatforms(List<String> platforms, String? targetFilter) {
  if (targetFilter == null || targetFilter.isEmpty) return platforms;
  final Set<String> targets = targetFilter
      .split(',')
      .map((String t) => t.trim().toLowerCase())
      .where((String t) => t.isNotEmpty)
      .toSet();
  final List<String> filtered =
      platforms.where((String p) => targets.contains(p)).toList();
  if (filtered.isEmpty) {
    logMessage("Warning: no platforms matched filter '$targetFilter'");
  }
  return filtered;
}
