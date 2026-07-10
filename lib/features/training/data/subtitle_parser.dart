import 'dart:convert';

import '../domain/subtitle.dart';

/// 字幕解析器。
///
/// 实际线上字幕是**多语言 SRT-x**（SRT 时间戳 + `[en:]`/`[zh:]` 等语言标签，
/// 另有 `origin:`/`[MARK:]`/`[NOTE:]` 杂项）。同时兼容跨仓 JSON 契约
/// （`{version, language, sentences:[{seq,start_ms,end_ms,text_en,text_cn}]}`）：
/// 内容以 `{` 开头时按 JSON 解析，否则按 srtx 解析。
///
/// `seq` 一律由**数组顺序 0 起**赋值（忽略 srtx 里 1 起的块号），对齐 sentence_index。
Subtitle parseSubtitle(String raw) {
  final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final head = text.trimLeft();
  if (head.startsWith('{')) {
    try {
      return _parseJson(head);
    } catch (_) {
      // JSON 解析失败则退回 srtx（尽力而为）。
    }
  }
  return _parseSrtx(text);
}

final _timeRe = RegExp(r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})');
final _tagRe = RegExp(r'^\[([A-Za-z]+):\]\s?(.*)$');
final _wsRe = RegExp(r'\s+');

Subtitle _parseSrtx(String text) {
  final blocks = text.split(RegExp(r'\n\s*\n'));
  final out = <Sentence>[];
  for (final block in blocks) {
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.isEmpty) continue;

    int? startMs, endMs;
    String en = '', cn = '';
    for (final line in lines) {
      if (startMs == null && line.contains('-->')) {
        final ms = _timeRe.allMatches(line).map(_toMs).toList();
        if (ms.length >= 2) {
          startMs = ms[0];
          endMs = ms[1];
        }
        continue;
      }
      final m = _tagRe.firstMatch(line);
      if (m == null) continue;
      final tag = m.group(1)!.toLowerCase();
      final val = _clean(m.group(2)!);
      if (tag == 'en') {
        en = val;
      } else if (tag == 'zh') {
        cn = val;
      }
    }

    if (startMs == null || endMs == null || endMs <= startMs) continue;
    if (en.isEmpty) continue;
    out.add(Sentence(
      seq: out.length,
      startMs: startMs,
      endMs: endMs,
      textEn: en,
      textCn: cn,
    ));
  }
  return Subtitle(version: 1, language: 'en', sentences: out);
}

int _toMs(RegExpMatch m) {
  final h = int.parse(m.group(1)!);
  final mi = int.parse(m.group(2)!);
  final s = int.parse(m.group(3)!);
  final ms = int.parse(m.group(4)!.padRight(3, '0'));
  return ((h * 60 + mi) * 60 + s) * 1000 + ms;
}

/// srtx 的 `[en:]` 偶有多空格/多语句，折叠空白便于显示与评测。
String _clean(String s) => s.replaceAll(_wsRe, ' ').trim();

Subtitle _parseJson(String raw) {
  final obj = jsonDecode(raw) as Map<String, dynamic>;
  final rawList = (obj['sentences'] as List?) ?? const [];
  final out = <Sentence>[];
  for (var i = 0; i < rawList.length; i++) {
    final e = rawList[i] as Map<String, dynamic>;
    final start = (e['start_ms'] as num?)?.toInt() ?? 0;
    final end = (e['end_ms'] as num?)?.toInt() ?? 0;
    final en = _clean((e['text_en'] as String?) ?? '');
    if (end <= start || en.isEmpty) continue;
    out.add(Sentence(
      seq: out.length,
      startMs: start,
      endMs: end,
      textEn: en,
      textCn: _clean((e['text_cn'] as String?) ?? ''),
    ));
  }
  return Subtitle(
    version: (obj['version'] as num?)?.toInt() ?? 1,
    language: (obj['language'] as String?) ?? 'en',
    sentences: out,
  );
}
