import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subtitle_api.dart';
import '../data/subtitle_parser.dart';
import '../domain/subtitle.dart';

/// 按字幕 URL 拉取并解析句级字幕。key = subtitle_en_url。
///
/// `keepAlive`：解析结果常驻内存，重进播放页不再重复拉取/解析（会话内即时）。
/// 叠加 SubtitleApi 的磁盘缓存，跨重启也免网络。
final subtitleProvider = FutureProvider.family<Subtitle, String>((ref, url) async {
  ref.keepAlive();
  final raw = await ref.watch(subtitleApiProvider).fetch(url);
  return parseSubtitle(raw);
});
