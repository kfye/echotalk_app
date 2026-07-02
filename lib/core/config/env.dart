/// 全局环境配置。
///
/// baseUrl 走编译期注入：`flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8080/api/v1`
/// 不传则用默认值（Android 模拟器访问宿主机 localhost 的专用别名 10.0.2.2）。
class Env {
  Env._();

  /// 业务接口基址（带 /api/v1）。
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  /// 健康检查基址（根路径，不带 /api/v1）。openapi 中 /healthz 挂在服务器根。
  static const String healthBaseUrl = String.fromEnvironment(
    'HEALTH_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// debug 构建下为 true，用于决定是否挂 dio 日志拦截器。
  static const bool isDebug = !bool.fromEnvironment('dart.vm.product');
}
