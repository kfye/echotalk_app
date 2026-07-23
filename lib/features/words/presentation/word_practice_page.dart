import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/audio/clip_player.dart';
import '../../../core/audio/recorder_service.dart';
import '../../../core/audio/word_audio_player.dart';
import '../../../core/theme/app_theme.dart';
import '../application/word_providers.dart';
import '../data/word_repository.dart';
import '../domain/word.dart';
import 'widgets/word_card.dart';
import 'widgets/word_list_sheet.dart';

/// 单词·口语速练（设计稿 2c）。
class WordPracticePage extends ConsumerStatefulWidget {
  const WordPracticePage({super.key});

  @override
  ConsumerState<WordPracticePage> createState() => _WordPracticePageState();
}

class _WordPracticePageState extends ConsumerState<WordPracticePage> {
  static const _speeds = [0.75, 1.0, 1.25, 1.5];

  bool _playing = false;
  bool _recording = false;

  /// 最近一次跟读录音路径，及其所属单词（切词后失效，避免回放到别的词）。
  String? _recordPath;
  String? _recordWord;

  final PageController _pageController = PageController();
  final GlobalKey _speedKey = GlobalKey();

  WordPracticeController get _ctrl => ref.read(wordPracticeProvider.notifier);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 外部改 index（上一个/下一个/列表/搜索/切级别）时，让 PageView 跟随。
    ref.listen(wordPracticeProvider, (prev, next) {
      final idx = next.value?.index;
      if (idx == null || !_pageController.hasClients) return;
      final cur = _pageController.page?.round();
      if (cur != idx) {
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });

    final async = ref.watch(wordPracticeProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('高频3000单词 · 口语速练',
            style: AppTypography.h2.copyWith(
                fontSize: 16.5, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: _openSearch,
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败：$e', style: AppTypography.bodySecondary),
        ),
        data: (s) => _content(s),
      ),
    );
  }

  Widget _content(WordPracticeState s) {
    return SafeArea(
      top: false,
      child: Column(
        children: [
          _levelChips(s),
          _optionsRow(s),
          _infoRow(s),
          Expanded(
            child: s.workingList.isEmpty ? _empty(s) : _pager(s),
          ),
          if (s.workingList.isNotEmpty) _dots(s),
          _bottomBar(s),
        ],
      ),
    );
  }

  /// 左右滑动翻页看上一个/下一个单词。
  Widget _pager(WordPracticeState s) {
    return PageView.builder(
      controller: _pageController,
      itemCount: s.workingList.length,
      onPageChanged: (i) {
        _discardRecordingOnLeave();
        _ctrl.setIndex(i);
      },
      itemBuilder: (context, i) {
        final word = s.workingList[i];
        final isCurrent = i == s.index;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.lg),
          child: WordCard(
            word: word,
            us: s.us,
            maskMeaning: s.maskMeaning,
            revealed: isCurrent && s.revealed,
            isFavorite: s.favorites.contains(word.w),
            isRecording: isCurrent && _recording,
            hasRecording: isCurrent && _recordPath != null && _recordWord == word.w,
            onReveal: _ctrl.reveal,
            onToggleAccent: _ctrl.setAccent,
            onPlayAccent: _playAccent,
            onToggleFavorite: _ctrl.toggleFavorite,
            onToggleRecord: _toggleRecord,
            onPlayback: _playRecording,
          ),
        );
      },
    );
  }

  /// 翻页圆点（滑窗，指示可左右滑动）。
  Widget _dots(WordPracticeState s) {
    const count = 5;
    final active = s.index % count;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == active ? AppColors.primary : AppColors.border,
                borderRadius: AppRadius.pill,
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(WordPracticeState s) => Center(
        child: Text(
          s.favOnly ? '还没有收藏单词' : '暂无单词',
          style: AppTypography.bodySecondary,
        ),
      );

  // —— 顶部等级 chips（A1–C1 圆形，全部 胶囊）——
  Widget _levelChips(WordPracticeState s) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: WordLevel.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final level = WordLevel.values[i];
          final sel = level == s.level;
          final circle = level != WordLevel.all; // 全部为胶囊，其余圆形
          return Center(
            child: GestureDetector(
              onTap: () => _ctrl.setLevel(level),
              child: Container(
                alignment: Alignment.center,
                width: circle ? 38 : null,
                height: 38,
                padding: circle
                    ? null
                    : const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryDeep : AppColors.primaryTint,
                  shape: circle ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: circle ? null : AppRadius.pill,
                ),
                child: Text(
                  level.label,
                  style: AppTypography.bodySecondary.copyWith(
                    fontSize: 13,
                    color: sel ? Colors.white : AppColors.primaryDeep,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(WordPracticeState s) {
    final levelLabel = s.level == WordLevel.all ? '全部' : s.level.label;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, 0),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${s.index + 1}',
                  style: AppTypography.h2.copyWith(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: ' / ${s.workingList.length}',
                  style: AppTypography.bodySecondary.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: AppRadius.pill,
            ),
            child: Text(
              levelLabel,
              style: AppTypography.caption.copyWith(
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // —— 遮语义 / 只看收藏 / 语速 ——
  Widget _optionsRow(WordPracticeState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.xs, AppSpacing.xl, AppSpacing.xs),
      child: Row(
        children: [
          _speedButton(s),
          const SizedBox(width: AppSpacing.sm),
          _toggle(
            label: '遮语义',
            icon: Icons.visibility_off_outlined,
            active: s.maskMeaning,
            onTap: _ctrl.toggleMask,
          ),
          const SizedBox(width: AppSpacing.sm),
          _toggle(
            label: '只看收藏',
            icon: Icons.star_outline,
            active: s.favOnly,
            // 开着时永远可点（用于关闭恢复全部）；关着时需有收藏才可开。
            enabled: s.favOnly || s.hasFavorites,
            onTap: _ctrl.toggleFavOnly,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _toggle({
    required String label,
    required IconData icon,
    required bool active,
    bool enabled = true,
    required VoidCallback onTap,
  }) {
    final color = !enabled
        ? AppColors.textMuted
        : active
            ? AppColors.primaryDeep
            : AppColors.textSecondary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: active && enabled ? AppColors.primaryTint : Colors.white,
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: active && enabled ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.bodySecondary
                    .copyWith(fontSize: 14, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _speedButton(WordPracticeState s) {
    return GestureDetector(
      onTap: () => _pickSpeed(s.speed),
      child: Container(
        key: _speedKey,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.pill,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('语速 ${_speedLabel(s.speed)}x',
                style: AppTypography.bodySecondary.copyWith(
                    fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  String _speedLabel(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(1) : v.toString();

  /// 语速菜单：与播放页一致，从「语速」按钮位置**向下**锚定展开（非底部弹窗）。
  Future<void> _pickSpeed(double current) async {
    final ctx = _speedKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;

    final picked = await showGeneralDialog<double>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '语速',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dctx, _, _) {
        return Stack(
          children: [
            Positioned(
              left: rect.left,
              // 菜单顶边落在按钮下方 6px → 向下展开
              top: rect.bottom + 6,
              child: Material(
                color: AppColors.surface,
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final sp in _speeds)
                        InkWell(
                          onTap: () => Navigator.of(dctx).pop(sp),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            child: Row(
                              children: [
                                Text('${_speedLabel(sp)}x',
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontFamilyFallback:
                                          AppTypography.fallback,
                                      fontSize: 14,
                                      fontWeight: sp == current
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: sp == current
                                          ? AppColors.primaryDeep
                                          : AppColors.textPrimary,
                                    )),
                                if (sp == current) ...[
                                  const SizedBox(width: 16),
                                  const Icon(Icons.check,
                                      size: 18, color: AppColors.primaryDeep),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (dctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (picked != null) _ctrl.setSpeed(picked);
  }

  // —— 底部：列表(左) + 上一个/播放(大圆)/下一个（屏幕居中，无文字标签）——
  Widget _bottomBar(WordPracticeState s) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xl),
                child: InkResponse(
                  onTap: () => _openList(s),
                  radius: 24,
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CustomPaint(painter: _ListLinesPainter()),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _barIcon(Icons.skip_previous, onTap: _ctrl.prev),
                const SizedBox(width: AppSpacing.xxl),
                _playButton(s),
                const SizedBox(width: AppSpacing.xxl),
                _barIcon(Icons.skip_next, onTap: _ctrl.next),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _barIcon(IconData icon, {required VoidCallback onTap}) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Icon(icon, color: AppColors.textPrimary, size: 26),
    );
  }

  Widget _playButton(WordPracticeState s) {
    return GestureDetector(
      onTap: _playing || s.current == null ? null : () => _play(s),
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: _playing
            ? const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.play_arrow, color: Colors.white, size: 32),
      ),
    );
  }

  Future<void> _play(WordPracticeState s) async {
    final word = s.current;
    if (word == null) return;
    setState(() => _playing = true);
    try {
      await ref.read(wordAudioPlayerProvider).playWordThenExample(
            word.w,
            word.ex,
            us: s.us,
            speed: s.speed,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络')));
      }
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  /// 跟读：点「跟读」开始录音（16K/16bit/单声道 WAV），再点停止并保存；用「播放跟读」回放。
  /// 单词级评测后端暂无对应端点（/training/evaluate 面向视频句），故当前只做「录音+回放」。
  Future<void> _toggleRecord() async {
    final recorder = ref.read(recorderServiceProvider);
    final word = ref.read(wordPracticeProvider).value?.current;
    if (_recording) {
      final path = await recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _recordPath = path;
        _recordWord = word?.w;
      });
      return;
    }
    if (!await recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('需要麦克风权限才能跟读')));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/word_${DateTime.now().millisecondsSinceEpoch}.wav';
    await recorder.start(path);
    if (!mounted) return;
    setState(() => _recording = true);
  }

  /// 回放已录的跟读。
  Future<void> _playRecording() async {
    final path = _recordPath;
    if (path == null) return;
    await ref.read(clipPlayerProvider).playFile(path).catchError((_) {});
  }

  /// 切词时丢弃当前录音：录音中则停止，并清掉可回放状态。
  void _discardRecordingOnLeave() {
    if (_recording) {
      ref.read(recorderServiceProvider).stop().catchError((_) => null);
    }
    if (_recording || _recordPath != null) {
      setState(() {
        _recording = false;
        _recordPath = null;
        _recordWord = null;
      });
    }
  }

  /// 点音标喇叭：切到该口音并试听单词发音（尽力而为，不阻塞播放态）。
  void _playAccent(bool us) {
    final s = ref.read(wordPracticeProvider).value;
    final word = s?.current;
    if (word == null) return;
    _ctrl.setAccent(us);
    ref
        .read(wordAudioPlayerProvider)
        .playWord(word.w, us: us, speed: s!.speed)
        .catchError((_) {});
  }

  void _openList(WordPracticeState s) {
    WordListSheet.show(
      context,
      words: s.workingList,
      currentWord: s.current?.w,
      onSelect: _ctrl.jumpTo,
    );
  }

  Future<void> _openSearch() async {
    final all = ref.read(allWordsProvider).asData?.value ?? const <Word>[];
    final picked = await showSearch<Word?>(
      context: context,
      delegate: _WordSearchDelegate(all),
    );
    if (picked != null) _ctrl.jumpTo(picked);
  }
}

/// 全量模糊搜索：单词或释义子串匹配，选中返回该词。
class _WordSearchDelegate extends SearchDelegate<Word?> {
  _WordSearchDelegate(this.all) : super(searchFieldLabel: '搜索单词');

  final List<Word> all;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _list();

  @override
  Widget buildSuggestions(BuildContext context) => _list();

  Widget _list() {
    final results = WordRepository.search(all, query);
    if (query.trim().isEmpty) {
      return const Center(
        child: Text('输入单词或释义搜索', style: AppTypography.bodySecondary),
      );
    }
    if (results.isEmpty) {
      return const Center(
        child: Text('没有匹配的单词', style: AppTypography.bodySecondary),
      );
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final w = results[i];
        return ListTile(
          title: Text(w.w, style: AppTypography.body),
          subtitle: Text(w.primaryMeaning,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySecondary),
          trailing: Text(w.lv, style: AppTypography.caption),
          onTap: () => close(context, w),
        );
      },
    );
  }
}

/// 单词列表图标：2 长 1 短的三条横线（对齐设计稿）。
class _ListLinesPainter extends CustomPainter {
  const _ListLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.textPrimary
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final ys = [size.height * 0.22, size.height * 0.5, size.height * 0.78];
    final widths = [w, w, w * 0.55]; // 2 长 1 短
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(Offset(0, ys[i]), Offset(widths[i], ys[i]), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
