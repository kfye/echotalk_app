import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../storage/token_storage.dart';
import 'auth_events.dart';
import 'auth_interceptor.dart';
import 'envelope_interceptor.dart';

/// 应用主 Dio 实例。
///
/// 装配顺序（重要）：AuthInterceptor → EnvelopeInterceptor →（debug）LogInterceptor。
/// - 401 先到 AuthInterceptor 尝试刷新重放；
/// - 其余响应/错误由 EnvelopeInterceptor 解信封 / 归一为 ApiException。
final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final authEvents = ref.watch(authEventsProvider);

  final options = BaseOptions(
    baseUrl: Env.apiBaseUrl,
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
    contentType: Headers.jsonContentType,
  );

  final dio = Dio(options);

  // 刷新专用的裸 dio：不挂任何拦截器，避免刷新请求自身触发 401 → 无限递归。
  final refreshDio = Dio(options.copyWith());

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      storage: storage,
      authEvents: authEvents,
    ),
  );
  dio.interceptors.add(EnvelopeInterceptor());

  if (Env.isDebug) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
      ),
    );
  }

  return dio;
});
