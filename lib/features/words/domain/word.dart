/// 高频3000单词卡。数据源 assets/data/words_data.json（词典导出，非后端契约）。
class Word {
  const Word({
    required this.w,
    required this.uk,
    required this.us,
    required this.cn,
    required this.ex,
    required this.excn,
    required this.tag,
    required this.lv,
  });

  /// 单词本身，同时用作收藏键。
  final String w;

  /// 英式 / 美式音标（IPA，可能含多音，分号分隔）。
  final String uk;
  final String us;

  /// 中文释义，多义按 \n 分行。
  final String cn;

  /// 例句英文 / 中文。
  final String ex;
  final String excn;

  /// 词汇来源标签（初中/高中/四级…，可能为空）。
  final String tag;

  /// CEFR 等级 A1..C1。
  final String lv;

  /// 主释义 = cn 首行（卡片主展示）。
  String get primaryMeaning {
    final i = cn.indexOf('\n');
    return i < 0 ? cn : cn.substring(0, i);
  }

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      w: json['w'] as String? ?? '',
      uk: json['uk'] as String? ?? '',
      us: json['us'] as String? ?? '',
      cn: json['cn'] as String? ?? '',
      ex: json['ex'] as String? ?? '',
      excn: json['excn'] as String? ?? '',
      tag: json['tag'] as String? ?? '',
      lv: json['lv'] as String? ?? '',
    );
  }
}

/// 单词等级筛选。all=全部（不过滤），其余对应 CEFR。
enum WordLevel {
  all('全部', ''),
  a1('A1', 'A1'),
  a2('A2', 'A2'),
  b1('B1', 'B1'),
  b2('B2', 'B2'),
  c1('C1', 'C1');

  const WordLevel(this.label, this.code);

  /// chip 文案。
  final String label;

  /// 匹配 [Word.lv] 的值；all 为空串表示不过滤。
  final String code;

  /// 1c 模块卡里的级别说明文案。
  String get description => switch (this) {
        WordLevel.all => '',
        WordLevel.a1 => 'A1 入门·初中基础',
        WordLevel.a2 => 'A2 基础日常对话',
        WordLevel.b1 => 'B1 独立交流·高中/PET',
        WordLevel.b2 => 'B2 流利交流·四级+',
        WordLevel.c1 => 'C1 熟练·六级/考研',
      };

  /// 1c 级别网格档位名。
  String get tierName => switch (this) {
        WordLevel.all => '全部',
        WordLevel.a1 => '入门',
        WordLevel.a2 => '基础',
        WordLevel.b1 => '进阶',
        WordLevel.b2 => '熟练',
        WordLevel.c1 => '精通',
      };

  /// 1c 级别网格的示例词（装饰性 teaser，对齐设计稿）。
  String get sampleWords => switch (this) {
        WordLevel.all => '',
        WordLevel.a1 => 'apple · water',
        WordLevel.a2 => 'weather · travel',
        WordLevel.b1 => 'opinion · culture',
        WordLevel.b2 => 'debate · policy',
        WordLevel.c1 => 'nuance · subtle',
      };

  /// 参与练习的等级（不含 all）。
  static const List<WordLevel> practiceLevels = [
    WordLevel.a1,
    WordLevel.a2,
    WordLevel.b1,
    WordLevel.b2,
    WordLevel.c1,
  ];

  bool matches(Word word) => this == WordLevel.all || word.lv == code;
}
