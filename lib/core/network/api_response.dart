/// 后端统一响应信封：`{ code, msg, data, request_id }`。
///
/// 约定见 echotalk_server/docs/api-conventions.md：
/// - code == 0 表示业务成功，非 0 见错误码表；
/// - data 在失败时可能缺省。
///
/// 仅负责解析，不抛异常；业务码判定交给 EnvelopeInterceptor。
class Envelope<T> {
  const Envelope({
    required this.code,
    required this.msg,
    this.data,
    this.requestId,
  });

  final int code;
  final String msg;
  final T? data;
  final String? requestId;

  bool get isOk => code == 0;

  /// [fromData] 把原始 data（可能是 Map/List/null）转成目标类型 T。
  factory Envelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) fromData,
  ) {
    return Envelope<T>(
      code: (json['code'] as num?)?.toInt() ?? -1,
      msg: json['msg'] as String? ?? '',
      data: fromData(json['data']),
      requestId: json['request_id'] as String?,
    );
  }

  /// 不关心 data 类型时的便捷解析（data 原样保留为 Object?）。
  static Envelope<Object?> raw(Map<String, dynamic> json) =>
      Envelope.fromJson(json, (d) => d);
}
