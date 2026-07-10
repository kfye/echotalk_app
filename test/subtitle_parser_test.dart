import 'package:flutter_test/flutter_test.dart';
import 'package:echotalk_app/features/training/data/subtitle_parser.dart';

void main() {
  group('parseSubtitle · srtx（线上实际格式）', () {
    // 取自线上 Sample-pollykann.srtx 的代表性片段：
    // origin 头 + [MARK:] + 多语言标签，仅需 en/zh + 时间戳。
    const srtx = '''
origin:en

1
00:00:02,559 --> 00:00:05,062
[MARK:]1
[ko:]안녕, 여러분
[zh:]早安 各位
[en:]Morning, everyone.
[es:]Buenos días a todos.

2
00:00:05,732 --> 00:00:08,275
[zh:]早安 斯普劳特教授
[en:]Morning, Professor Sprout.
[fr:]Bonjour, professeur Chourave.
''';

    test('抽取 en/zh + 时间戳，seq 0 起，忽略杂项标签', () {
      final sub = parseSubtitle(srtx);
      expect(sub.sentences.length, 2);

      final s0 = sub.sentences[0];
      expect(s0.seq, 0);
      expect(s0.startMs, 2559);
      expect(s0.endMs, 5062);
      expect(s0.textEn, 'Morning, everyone.');
      expect(s0.textCn, '早安 各位');

      final s1 = sub.sentences[1];
      expect(s1.seq, 1); // 忽略文件里 1 起的块号，按顺序 0 起
      expect(s1.startMs, 5732);
      expect(s1.textEn, 'Morning, Professor Sprout.');
    });

    test('缺英文或时间非法的块被跳过', () {
      const bad = '''
1
99:99 --> bad
[zh:]只有中文

2
00:00:01,000 --> 00:00:02,000
[en:]Valid line.
''';
      final sub = parseSubtitle(bad);
      expect(sub.sentences.length, 1);
      expect(sub.sentences.first.textEn, 'Valid line.');
    });
  });

  group('parseSubtitle · JSON 契约兼容', () {
    test('以 { 开头按跨仓 JSON 契约解析', () {
      const json = '{"version":1,"language":"en","sentences":['
          '{"seq":0,"start_ms":0,"end_ms":2600,"text_en":"Hello.","text_cn":"你好。"}]}';
      final sub = parseSubtitle(json);
      expect(sub.sentences.length, 1);
      expect(sub.sentences.first.textEn, 'Hello.');
      expect(sub.sentences.first.endMs, 2600);
    });
  });
}
