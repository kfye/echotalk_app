import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/content_repository.dart';
import '../domain/video.dart';

/// 跟读内容列表状态：持当前分类过滤 + 列表数据。
/// Day 9 数据量小，loadMore 暂留桩（预留分页）。
class VideoListController extends AsyncNotifier<List<VideoListItem>> {
  String? _category;

  String? get category => _category;

  @override
  Future<List<VideoListItem>> build() async {
    final repo = ref.watch(contentRepositoryProvider);
    final page = await repo.listVideos(category: _category);
    return page.list;
  }

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final page = await ref
          .read(contentRepositoryProvider)
          .listVideos(category: _category);
      return page.list;
    });
  }

  /// 切换分类（null = 全部/推荐）。
  Future<void> setCategory(String? category) async {
    if (_category == category) return;
    _category = category;
    await _reload();
  }

  Future<void> refresh() => _reload();
}

final videoListProvider =
    AsyncNotifierProvider<VideoListController, List<VideoListItem>>(
  VideoListController.new,
);

/// 单个内容详情（供播放页）。
///
/// `keepAlive`：加载过即缓存在内存，重进同一视频播放页秒开、不再请求。
/// 注意：`locked` 依赖会员态，Day 11 购买后需 `ref.invalidate(videoDetailProvider(id))` 刷新。
final videoDetailProvider = FutureProvider.family<VideoDetail, int>((ref, id) {
  ref.keepAlive();
  return ref.watch(contentRepositoryProvider).getVideo(id);
});

/// 零宽字符码点：ZWSP(200B) ZWNJ(200C) ZWJ(200D) BOM(FEFF)。
/// 后端 category 里混入了这些，展示前按码点过滤（避免在源码里写不可见字符）。
const _zeroWidthCodes = {0x200B, 0x200C, 0x200D, 0xFEFF};

String cleanCategory(String s) =>
    String.fromCharCodes(s.runes.where((r) => !_zeroWidthCodes.contains(r)))
        .trim();

/// 分类 chips 数据（独立于过滤后的列表，避免选中分类后 chips 丢失）。
/// 返回 (raw 用于接口过滤, label 用于展示)。
final videoCategoriesProvider =
    FutureProvider<List<({String raw, String label})>>((ref) async {
  final page =
      await ref.watch(contentRepositoryProvider).listVideos(pageSize: 100);
  final seen = <String>{};
  final result = <({String raw, String label})>[];
  for (final v in page.list) {
    final label = cleanCategory(v.category);
    if (label.isEmpty || !seen.add(label)) continue;
    result.add((raw: v.category, label: label));
  }
  return result;
});
