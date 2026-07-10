/// 讯飞 ISE 评测结果。对齐 openapi schema EvaluateResult。
///
/// 讯飞不可用时后端降级：`degraded=true`、分数为 0、带 `message`，HTTP 仍 200。
class EvaluateResult {
  const EvaluateResult({
    this.recordId,
    required this.overall,
    required this.accuracy,
    required this.fluency,
    required this.integrity,
    required this.words,
    required this.degraded,
    this.message,
  });

  /// 落库后的训练记录 ID（Day 12 历史页用）。
  final int? recordId;

  /// 总分 / 发音准确度 / 流利度 / 完整度（0-100）。
  final double overall;
  final double accuracy;
  final double fluency;
  final double integrity;

  /// 词级评分（用于当前句英文的逐词高亮）。
  final List<WordScore> words;

  /// 讯飞不可用的降级兜底结果（分数为 0）。
  final bool degraded;

  /// 降级等情形的提示语，正常时为空。
  final String? message;

  factory EvaluateResult.fromJson(Map<String, dynamic> json) {
    final rawWords = (json['words'] as List?) ?? const [];
    return EvaluateResult(
      recordId: (json['record_id'] as num?)?.toInt(),
      overall: _toDouble(json['overall']),
      accuracy: _toDouble(json['accuracy']),
      fluency: _toDouble(json['fluency']),
      integrity: _toDouble(json['integrity']),
      words: rawWords
          .whereType<Map<String, dynamic>>()
          .map(WordScore.fromJson)
          .toList(),
      degraded: json['degraded'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  static double _toDouble(Object? v) => (v as num?)?.toDouble() ?? 0;
}

/// 单词级评分。
class WordScore {
  const WordScore({required this.word, required this.score});

  final String word;
  final double score;

  factory WordScore.fromJson(Map<String, dynamic> json) => WordScore(
        word: json['word'] as String? ?? '',
        score: (json['score'] as num?)?.toDouble() ?? 0,
      );
}
