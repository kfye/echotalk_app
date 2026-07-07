import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/page_data.dart';
import '../domain/video.dart';
import 'content_api.dart';

/// 内容数据仓库：编排 content api（预留缓存位）。供 controller / 页面调用。
class ContentRepository {
  ContentRepository(this._api);

  final ContentApi _api;

  Future<PageData<VideoListItem>> listVideos({
    int page = 1,
    int pageSize = 20,
    String? category,
    int? difficulty,
  }) {
    return _api.listVideos(
      page: page,
      pageSize: pageSize,
      category: category,
      difficulty: difficulty,
    );
  }

  Future<VideoDetail> getVideo(int id) => _api.getVideo(id);
}

final contentRepositoryProvider = Provider<ContentRepository>(
  (ref) => ContentRepository(ref.watch(contentApiProvider)),
);
