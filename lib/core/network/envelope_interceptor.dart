import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'api_response.dart';

/// 统一解信封拦截器。
///
/// - onResponse（HTTP 2xx）：把响应体当信封解析。
///   - code == 0 → 用 data 字段替换 response.data，调用方直接拿业务数据；
///   - code != 0（如 HTTP 200 + 11003 密码错误）→ 转成 ApiException 抛出。
/// - onError（非 2xx，如 400/404/500）：把信封或传输错误统一成 ApiException。
///   注意：401 不在此处理，交由 AuthInterceptor（靠装配顺序保证 401 先到 Auth）。
class EnvelopeInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('code')) {
      final env = Envelope.raw(data);
      if (env.isOk) {
        // 用真正的业务数据替换整个信封，调用方无需再剥壳。
        response.data = env.data;
        handler.next(response);
      } else {
        handler.reject(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
            error: ApiException.fromEnvelope(
              env,
              statusCode: response.statusCode,
            ),
          ),
        );
      }
      return;
    }
    // 非信封结构（理论上不该出现），原样透传。
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 已被上游（AuthInterceptor）归一为 ApiException 的，直接透传。
    if (err.error is ApiException) {
      handler.next(err);
      return;
    }
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: ApiException.fromDio(err),
      ),
    );
  }
}
