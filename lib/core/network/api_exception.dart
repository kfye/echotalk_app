import 'package:dio/dio.dart';

import 'api_response.dart';

/// 全应用统一的接口异常。
///
/// 把「HTTP 传输错误」与「后端业务码」归一为一个带可读 [message] 的异常，
/// 页面层直接 `catch (e) { showSnack(e.message) }` 即可提示。
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  /// 业务码（后端 code；纯传输错误时用 HTTP 状态或本地占位码）。
  final int code;

  /// 面向用户的可读提示。
  final String message;

  /// HTTP 状态码（若有）。
  final int? statusCode;

  /// 未授权/登录失效的业务码（api-conventions.md）。
  static const int unauthorized = 10401;

  bool get isUnauthorized => code == unauthorized || statusCode == 401;

  /// 由业务失败的信封构造（HTTP 200 但 code != 0，如 11003 密码错误）。
  factory ApiException.fromEnvelope(Envelope env, {int? statusCode}) {
    return ApiException(
      code: env.code,
      message: env.msg.isNotEmpty ? env.msg : '请求失败',
      statusCode: statusCode,
    );
  }

  /// 由 DioException 构造（超时/连接失败/非 2xx 等传输级错误）。
  factory ApiException.fromDio(DioException e) {
    // 若响应体本身是后端信封，优先用其 code/msg。
    final data = e.response?.data;
    if (data is Map<String, dynamic> && data.containsKey('code')) {
      return ApiException.fromEnvelope(
        Envelope.raw(data),
        statusCode: e.response?.statusCode,
      );
    }

    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        '网络连接超时，请稍后重试',
      DioExceptionType.connectionError =>
        '无法连接服务器，请检查网络',
      DioExceptionType.badCertificate => '证书校验失败',
      DioExceptionType.cancel => '请求已取消',
      _ => '网络异常（${e.response?.statusCode ?? '-'}）',
    };
    return ApiException(
      code: e.response?.statusCode ?? -1,
      message: message,
      statusCode: e.response?.statusCode,
    );
  }

  @override
  String toString() => 'ApiException(code: $code, message: $message, '
      'statusCode: $statusCode)';
}
