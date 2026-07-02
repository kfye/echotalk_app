import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_exception.dart';

/// 鉴权拦截器：
/// - onRequest：非豁免接口自动附 `Authorization: Bearer <access>`。
/// - onError：HTTP 401（access 过期）→ 单飞刷新 → 成功则带新 token 重放原请求；
///   刷新失败 → 清 token + 广播会话失效（T4 跳登录）。
///
/// 关键防坑：
/// - 刷新用独立的 [_refreshDio]（不挂任何拦截器），避免刷新请求自身 401 → 无限递归；
/// - 用 [_refreshing] Completer 做单飞锁，并发 401 只触发一次刷新；
/// - 重放走 [_dio].fetch，重新进入拦截器链（自动带新 bearer + 解信封），
///   并用 extra['retried'] 标记防止二次 401 再刷新。
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required Dio refreshDio,
    required TokenStorage storage,
    required StreamController<void> authEvents,
  })  : _dio = dio,
        _refreshDio = refreshDio,
        _storage = storage,
        _authEvents = authEvents;

  final Dio _dio;
  final Dio _refreshDio;
  final TokenStorage _storage;
  final StreamController<void> _authEvents;

  /// 无需鉴权（openapi 中 security: []）的接口路径。
  static const _exemptPaths = <String>{
    '/user/login',
    '/user/register',
    '/user/refresh',
    '/user/send-code',
    '/healthz',
    '/system/config',
  };

  bool _isExempt(String path) => _exemptPaths.any(path.endsWith);

  Completer<bool>? _refreshing;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isExempt(options.path)) {
      final access = await _storage.readAccess();
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    final alreadyRetried = options.extra['retried'] == true;

    // 非 401 / 豁免接口 / 已重试过 → 交给下一个拦截器（EnvelopeInterceptor 归一异常）。
    if (!is401 || _isExempt(options.path) || alreadyRetried) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshToken();
    if (!refreshed) {
      await _storage.clear();
      _authEvents.add(null); // 广播会话失效
      handler.reject(
        DioException(
          requestOptions: options,
          response: err.response,
          type: DioExceptionType.badResponse,
          error: const ApiException(
            code: ApiException.unauthorized,
            message: '登录已失效，请重新登录',
            statusCode: 401,
          ),
        ),
      );
      return;
    }

    // 刷新成功 → 带新 token 重放原请求。
    final newAccess = await _storage.readAccess();
    options.headers['Authorization'] = 'Bearer $newAccess';
    options.extra['retried'] = true;
    try {
      final response = await _dio.fetch(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  /// 单飞刷新：并发调用共享同一个 Future，只实际刷新一次。
  Future<bool> _refreshToken() {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;

    final completer = Completer<bool>();
    _refreshing = completer;
    _doRefresh().then((ok) {
      _refreshing = null;
      completer.complete(ok);
    }).catchError((_) {
      _refreshing = null;
      completer.complete(false);
    });
    return completer.future;
  }

  Future<bool> _doRefresh() async {
    final refresh = await _storage.readRefresh();
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final resp = await _refreshDio.post<Map<String, dynamic>>(
        '/user/refresh',
        data: {'refresh_token': refresh},
      );
      final body = resp.data;
      if (body != null && (body['code'] as num?)?.toInt() == 0) {
        final data = body['data'];
        if (data is Map<String, dynamic>) {
          final access = data['access_token'];
          final newRefresh = data['refresh_token'];
          if (access is String && newRefresh is String) {
            await _storage.save(access: access, refresh: newRefresh);
            return true;
          }
        }
      }
      return false;
    } on DioException {
      // refresh 过期/无效会返回 401 → 抛出 → 视为刷新失败。
      return false;
    }
  }
}
