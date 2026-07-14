import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/word.dart';

/// 高频3000单词数据源。从随包 asset 一次性加载解析，全内存驻留。
///
/// 本项目首个使用 rootBundle 的地方——单词表是静态词典数据，不走后端契约。
class WordRepository {
  const WordRepository();

  static const _assetPath = 'assets/data/words_data.json';

  /// 加载并解析全部单词（3000 条）。由 allWordsProvider 调一次后缓存。
  Future<List<Word>> loadAll() async {
    final raw = await rootBundle.loadString(_assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// 在 [all] 内按等级过滤。
  static List<Word> byLevel(List<Word> all, WordLevel level) =>
      all.where(level.matches).toList(growable: false);

  /// 模糊搜索：对单词或中文释义做大小写无关子串匹配。空查询返回空。
  static List<Word> search(List<Word> all, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return all
        .where((w) =>
            w.w.toLowerCase().contains(q) || w.cn.toLowerCase().contains(q))
        .toList(growable: false);
  }
}

final wordRepositoryProvider =
    Provider<WordRepository>((ref) => const WordRepository());
