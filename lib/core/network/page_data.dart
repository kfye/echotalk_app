/// 通用分页信封：`{ list, total, page, page_size }`（对齐 openapi PageData）。
class PageData<T> {
  const PageData({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> list;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < total;

  factory PageData.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final raw = (json['list'] as List?) ?? const [];
    return PageData<T>(
      list: raw
          .map((e) => itemFromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      total: (json['total'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 0,
    );
  }
}
