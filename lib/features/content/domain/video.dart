/// 内容列表项。对齐 openapi schema VideoListItem。
class VideoListItem {
  const VideoListItem({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.difficulty,
    required this.category,
    required this.isFree,
    required this.locked,
  });

  final int id;
  final String title;
  final String coverUrl;

  /// 时长（秒）。
  final int duration;

  /// 英语等级 1-6 → A1/A2/B1/B2/C1/C2。
  final int difficulty;
  final String category;
  final bool isFree;

  /// 服务端计算：当前用户是否被付费墙拦住。
  final bool locked;

  static const _cefr = ['—', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  /// CEFR 等级标签（越界兜 '—'）。
  String get cefrLabel =>
      (difficulty >= 1 && difficulty <= 6) ? _cefr[difficulty] : '—';

  /// mm:ss 时长文本（分钟补零，对齐设计稿）。
  String get durationText {
    final m = duration ~/ 60;
    final s = duration % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  factory VideoListItem.fromJson(Map<String, dynamic> json) {
    return VideoListItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      coverUrl: json['cover_url'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
      isFree: json['is_free'] as bool? ?? false,
      locked: json['locked'] as bool? ?? false,
    );
  }
}

/// 内容详情 = VideoListItem + 播放/字幕地址等。对齐 openapi schema VideoDetail。
class VideoDetail extends VideoListItem {
  const VideoDetail({
    required super.id,
    required super.title,
    required super.coverUrl,
    required super.duration,
    required super.difficulty,
    required super.category,
    required super.isFree,
    required super.locked,
    this.description,
    this.hlsUrl,
    this.subtitleEnUrl,
    this.subtitleCnUrl,
    this.status,
  });

  final String? description;

  /// HLS 播放地址（locked=true 时可能为空）。
  final String? hlsUrl;
  final String? subtitleEnUrl;
  final String? subtitleCnUrl;

  /// 0 草稿 / 1 上架 / 2 下架。
  final int? status;

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    final base = VideoListItem.fromJson(json);
    return VideoDetail(
      id: base.id,
      title: base.title,
      coverUrl: base.coverUrl,
      duration: base.duration,
      difficulty: base.difficulty,
      category: base.category,
      isFree: base.isFree,
      locked: base.locked,
      description: json['description'] as String?,
      hlsUrl: json['hls_url'] as String?,
      subtitleEnUrl: json['subtitle_en_url'] as String?,
      subtitleCnUrl: json['subtitle_cn_url'] as String?,
      status: (json['status'] as num?)?.toInt(),
    );
  }
}
