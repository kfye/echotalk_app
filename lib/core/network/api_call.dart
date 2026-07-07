import 'package:dio/dio.dart';

import 'api_exception.dart';

/// 把 dio 抛出的 DioException 归一为 ApiException（页面直接读 .message）。
/// 各 feature 的 api 层统一用它包裹请求。
Future<T> guardApiCall<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    final err = e.error;
    throw err is ApiException ? err : ApiException.fromDio(e);
  }
}
