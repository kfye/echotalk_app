import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../domain/token_pair.dart';
import '../domain/user.dart';

/// 账号相关 HTTP 端点封装（openapi tags: account）。
///
/// 响应的外层信封已由 T2 的 EnvelopeInterceptor 剥掉，这里 response.data 即业务数据。
/// 所有方法经 [_guard] 把 DioException 归一为 ApiException，调用方只需 catch ApiException。
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<TokenPair> login(String email, String password) {
    return _guard(() async {
      final resp = await _dio.post<dynamic>(
        '/user/login',
        data: {'email': email, 'password': password},
      );
      return TokenPair.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  Future<User> register(
    String email,
    String password, {
    String? nickname,
    required String code,
  }) {
    return _guard(() async {
      final resp = await _dio.post<dynamic>(
        '/user/register',
        data: {
          'email': email,
          'password': password,
          'code': code,
          if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        },
      );
      return User.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  /// 通常由 AuthInterceptor 自动刷新，此方法备用。
  Future<TokenPair> refresh(String refreshToken) {
    return _guard(() async {
      final resp = await _dio.post<dynamic>(
        '/user/refresh',
        data: {'refresh_token': refreshToken},
      );
      return TokenPair.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  Future<void> logout() {
    return _guard(() async {
      await _dio.post<dynamic>('/user/logout');
    });
  }

  Future<void> sendCode(String email) {
    return _guard(() async {
      await _dio.post<dynamic>('/user/send-code', data: {'email': email});
    });
  }

  Future<UserProfile> profile() {
    return _guard(() async {
      final resp = await _dio.get<dynamic>('/user/profile');
      return UserProfile.fromJson(resp.data as Map<String, dynamic>);
    });
  }

  /// 把 dio 抛出的 DioException 归一为 ApiException（页面直接读 .message）。
  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      final err = e.error;
      throw err is ApiException ? err : ApiException.fromDio(e);
    }
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);
