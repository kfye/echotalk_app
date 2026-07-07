import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/page_data.dart';
import '../domain/video.dart';

/// 内容相关 HTTP 端点封装（openapi tags: content）。
/// 信封已由 EnvelopeInterceptor 剥掉，response.data 即业务数据。
class ContentApi {
  ContentApi(this._dio);

  final Dio _dio;

  Future<PageData<VideoListItem>> listVideos({
    int page = 1,
    int pageSize = 20,
    String? category,
    int? difficulty,
  }) {
    return guardApiCall(() async {
      final resp = await _dio.get<dynamic>(
        '/content/videos',
        queryParameters: {
          'page': page,
          'page_size': pageSize,
          if (category != null && category.isNotEmpty) 'category': category,
          'difficulty': ?difficulty,
        },
      );
      return PageData.fromJson(
        resp.data as Map<String, dynamic>,
        VideoListItem.fromJson,
      );
    });
  }

  Future<VideoDetail> getVideo(int id) {
    return guardApiCall(() async {
      final resp = await _dio.get<dynamic>('/content/videos/$id');
      return VideoDetail.fromJson(resp.data as Map<String, dynamic>);
    });
  }
}

final contentApiProvider = Provider<ContentApi>(
  (ref) => ContentApi(ref.watch(dioProvider)),
);
