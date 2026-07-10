/// 句级字幕模型（影子跟读的载体）。
///
/// 数据来自 `videos.subtitle_en_url` 指向的字幕文件，App 拉取后自行解析。
/// `seq` 从 0 开始连续，等同后端 `training_records.sentence_index`（跨仓契约）。
class Sentence {
  const Sentence({
    required this.seq,
    required this.startMs,
    required this.endMs,
    required this.textEn,
    required this.textCn,
  });

  /// 句序号：0 起连续，评测时作为 sentence_index 上报。
  final int seq;

  /// 该句在视频中的起止毫秒（App 据此定位/循环该句片段）。
  final int startMs;
  final int endMs;

  /// 英文原文：显示 + 讯飞 ISE 评测标准答案。
  final String textEn;

  /// 中文翻译（纯展示，可能为空）。
  final String textCn;
}

/// 一段视频的完整字幕。
class Subtitle {
  const Subtitle({
    required this.version,
    required this.language,
    required this.sentences,
  });

  final int version;
  final String language;
  final List<Sentence> sentences;

  bool get isEmpty => sentences.isEmpty;

  /// 给定播放毫秒，返回“当前所在/最近一句”的下标。
  ///
  /// 句子按 `startMs` 升序；返回最后一个 `startMs <= ms` 的句子。
  /// **早于首句起点返回 -1（不高亮任何句）**，空则返回 -1。
  /// 句间空档保持高亮上一句（卡拉OK式，避免闪烁）。
  int indexAt(int ms) {
    if (sentences.isEmpty) return -1;
    if (ms < sentences.first.startMs) return -1;
    int lo = 0, hi = sentences.length - 1, ans = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (sentences[mid].startMs <= ms) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }
}
