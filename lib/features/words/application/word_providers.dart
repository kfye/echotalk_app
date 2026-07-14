import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_favorites_store.dart';
import '../data/word_repository.dart';
import '../domain/word.dart';

/// 全量单词（3000 条），加载一次后常驻内存。
final allWordsProvider = FutureProvider<List<Word>>((ref) {
  ref.keepAlive();
  return ref.watch(wordRepositoryProvider).loadAll();
});

/// 进入速练页时的初始等级（1c 点某档位卡时设置；默认 A1）。
/// 速练页每次进入会重建控制器并读取本值。
class RequestedWordLevel extends Notifier<WordLevel> {
  @override
  WordLevel build() => WordLevel.a1;

  void set(WordLevel level) => state = level;
}

final requestedWordLevelProvider =
    NotifierProvider<RequestedWordLevel, WordLevel>(RequestedWordLevel.new);

/// 单词速练页状态（不可变快照）。
class WordPracticeState {
  const WordPracticeState({
    required this.level,
    required this.index,
    required this.workingList,
    required this.levelTotal,
    required this.maskMeaning,
    required this.favOnly,
    required this.us,
    required this.speed,
    required this.revealed,
    required this.favorites,
  });

  /// 当前等级筛选。
  final WordLevel level;

  /// 当前词在 [workingList] 中的位置。
  final int index;

  /// 当前等级(∩收藏，若 favOnly)下的可练列表。
  final List<Word> workingList;

  /// 当前等级在全量里的总数（表头「A1 · 共 832」用，不受 favOnly 影响）。
  final int levelTotal;

  /// 遮语义：隐藏中文释义。
  final bool maskMeaning;

  /// 只看收藏。
  final bool favOnly;

  /// 发音口音：false=英式(type1)、true=美式(type2)。
  final bool us;

  /// 发音语速。
  final double speed;

  /// 遮语义模式下，当前词释义是否已点开。
  final bool revealed;

  /// 收藏词集合（单词字符串）。
  final Set<String> favorites;

  Word? get current =>
      (index >= 0 && index < workingList.length) ? workingList[index] : null;

  bool get hasFavorites => favorites.isNotEmpty;

  bool get isCurrentFavorite {
    final c = current;
    return c != null && favorites.contains(c.w);
  }

  WordPracticeState copyWith({
    WordLevel? level,
    int? index,
    List<Word>? workingList,
    int? levelTotal,
    bool? maskMeaning,
    bool? favOnly,
    bool? us,
    double? speed,
    bool? revealed,
    Set<String>? favorites,
  }) {
    return WordPracticeState(
      level: level ?? this.level,
      index: index ?? this.index,
      workingList: workingList ?? this.workingList,
      levelTotal: levelTotal ?? this.levelTotal,
      maskMeaning: maskMeaning ?? this.maskMeaning,
      favOnly: favOnly ?? this.favOnly,
      us: us ?? this.us,
      speed: speed ?? this.speed,
      revealed: revealed ?? this.revealed,
      favorites: favorites ?? this.favorites,
    );
  }
}

/// 单词速练控制器：加载全量+收藏，管理筛选/翻词/遮语义/收藏等交互。
class WordPracticeController extends AsyncNotifier<WordPracticeState> {
  List<Word> _all = const [];

  @override
  Future<WordPracticeState> build() async {
    _all = await ref.watch(allWordsProvider.future);
    final favorites = await ref.watch(wordFavoritesStoreProvider).load();
    // 进入时的等级由 1c 选择（点档位卡/开始速练），默认 A1。
    final level = ref.read(requestedWordLevelProvider);
    final working = _filtered(level, false, favorites);
    return WordPracticeState(
      level: level,
      index: 0,
      workingList: working,
      levelTotal: _levelTotal(level),
      maskMeaning: false,
      favOnly: false,
      us: false,
      speed: 1.0,
      revealed: false,
      favorites: favorites,
    );
  }

  int _levelTotal(WordLevel level) => _all.where(level.matches).length;

  List<Word> _filtered(WordLevel level, bool favOnly, Set<String> favorites) {
    return _all
        .where(level.matches)
        .where((w) => !favOnly || favorites.contains(w.w))
        .toList(growable: false);
  }

  /// 切等级：重算列表，若当前词仍在则保位置，否则跳首。
  /// 「全部」天然含当前词，故不会跳（满足需求：点全部不影响当前单词）。
  void setLevel(WordLevel level) {
    final s = state.value;
    if (s == null || s.level == level) return;
    final working = _filtered(level, s.favOnly, s.favorites);
    final current = s.current;
    final keep = current == null ? -1 : working.indexWhere((w) => w.w == current.w);
    state = AsyncData(s.copyWith(
      level: level,
      workingList: working,
      levelTotal: _levelTotal(level),
      index: keep >= 0 ? keep : 0,
      revealed: false,
    ));
  }

  void next() => _move(1);
  void prev() => _move(-1);

  /// 直接定位到某下标（滑动翻页用）。越界或相同则忽略。
  void setIndex(int index) {
    final s = state.value;
    if (s == null || index == s.index) return;
    if (index < 0 || index >= s.workingList.length) return;
    state = AsyncData(s.copyWith(index: index, revealed: false));
  }

  void _move(int delta) {
    final s = state.value;
    if (s == null || s.workingList.isEmpty) return;
    final n = s.workingList.length;
    final i = (s.index + delta) % n;
    state = AsyncData(s.copyWith(index: i < 0 ? i + n : i, revealed: false));
  }

  /// 跳到指定词。若不在当前列表内（如跨等级搜索命中），切到「全部」保证在池内。
  void jumpTo(Word word) {
    final s = state.value;
    if (s == null) return;
    final inList = s.workingList.indexWhere((w) => w.w == word.w);
    if (inList >= 0) {
      state = AsyncData(s.copyWith(index: inList, revealed: false));
      return;
    }
    final working = _filtered(WordLevel.all, false, s.favorites);
    final i = working.indexWhere((w) => w.w == word.w);
    state = AsyncData(s.copyWith(
      level: WordLevel.all,
      favOnly: false,
      workingList: working,
      levelTotal: _levelTotal(WordLevel.all),
      index: i >= 0 ? i : 0,
      revealed: false,
    ));
  }

  void toggleMask() {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(maskMeaning: !s.maskMeaning, revealed: false));
  }

  void reveal() {
    final s = state.value;
    if (s == null || s.revealed) return;
    state = AsyncData(s.copyWith(revealed: true));
  }

  void setAccent(bool us) {
    final s = state.value;
    if (s == null || s.us == us) return;
    state = AsyncData(s.copyWith(us: us));
  }

  void setSpeed(double speed) {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(speed: speed));
  }

  /// 只看收藏开关。收藏为空时不可开（UI 已置灰，此处再兜底）。
  void toggleFavOnly() {
    final s = state.value;
    if (s == null) return;
    final favOnly = !s.favOnly;
    if (favOnly && s.favorites.isEmpty) return;
    final working = _filtered(s.level, favOnly, s.favorites);
    final current = s.current;
    final keep = current == null ? -1 : working.indexWhere((w) => w.w == current.w);
    state = AsyncData(s.copyWith(
      favOnly: favOnly,
      workingList: working,
      index: keep >= 0 ? keep : 0,
      revealed: false,
    ));
  }

  /// 收藏/取消当前词并持久化。favOnly 下取消会使其移出列表，索引兜正。
  Future<void> toggleFavorite() async {
    final s = state.value;
    final current = s?.current;
    if (s == null || current == null) return;
    final favorites = {...s.favorites};
    if (!favorites.add(current.w)) favorites.remove(current.w);
    await ref.read(wordFavoritesStoreProvider).save(favorites);

    if (s.favOnly) {
      final working = _filtered(s.level, true, favorites);
      final index = working.isEmpty ? 0 : s.index.clamp(0, working.length - 1);
      state = AsyncData(s.copyWith(
        favorites: favorites,
        workingList: working,
        index: index,
      ));
    } else {
      state = AsyncData(s.copyWith(favorites: favorites));
    }
  }
}

final wordPracticeProvider =
    AsyncNotifierProvider<WordPracticeController, WordPracticeState>(
  WordPracticeController.new,
);
