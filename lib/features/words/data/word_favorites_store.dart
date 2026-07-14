import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 单词收藏本地持久化。以单词字符串为键，存一个字符串集合。
///
/// 非机密数据，用 shared_preferences（不占用 auth 的 secure_storage）。
/// 参考 core/storage/token_storage.dart 的封装 + Provider 写法。
class WordFavoritesStore {
  const WordFavoritesStore();

  static const _key = 'word_favorites';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> save(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, favorites.toList());
  }
}

final wordFavoritesStoreProvider =
    Provider<WordFavoritesStore>((ref) => const WordFavoritesStore());
