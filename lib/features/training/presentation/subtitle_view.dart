import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/evaluate_result.dart';
import '../domain/sentence_shadow.dart';
import '../domain/subtitle.dart';

/// 字幕显示语言：中英 / 仅英 / 仅中 / 无。
enum SubtitleLang { both, en, cn, none }

/// 字幕区（2a/2b）：可滚动句列表 + 当前句高亮。
///
/// - `shadowMode=false`：当前句放大高亮，其余灰化（跟随播放进度）。
/// - `shadowMode=true`：当前句展开为白卡 + 原位控制排（播放原声 / 跟读录制 /
///   跟读播放 / 分数环）。录制/评测/评分态由 `shadow` 驱动。
class SubtitleView extends StatefulWidget {
  const SubtitleView({
    super.key,
    required this.sentences,
    required this.currentIndex,
    required this.shadowMode,
    required this.onTapSentence,
    required this.onPlayOriginal,
    required this.onRecord,
    required this.onPlayback,
    this.shadow = SentenceShadow.idle,
    this.subtitleLang = SubtitleLang.both,
    required this.originalProgress,
    this.playingRecording = false,
  });

  final List<Sentence> sentences;
  final int currentIndex;
  final bool shadowMode;
  final ValueChanged<int> onTapSentence;
  final VoidCallback onPlayOriginal;
  final VoidCallback onRecord;
  final VoidCallback onPlayback;

  /// 当前句的录音/评测态。
  final SentenceShadow shadow;

  /// 字幕语言显示（作用于句列表；跟读态当前句英文始终保留）。
  final SubtitleLang subtitleLang;

  /// 播放原声进度（0..1，-1=不显示进度环）。
  final ValueListenable<double> originalProgress;

  /// 是否正在回放录音（回放按钮动画）。
  final bool playingRecording;

  bool get showEn =>
      subtitleLang == SubtitleLang.both || subtitleLang == SubtitleLang.en;
  bool get showCn =>
      subtitleLang == SubtitleLang.both || subtitleLang == SubtitleLang.cn;

  @override
  State<SubtitleView> createState() => _SubtitleViewState();
}

class _SubtitleViewState extends State<SubtitleView>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _currentKey = GlobalKey();

  /// 评分详情展开（发音/流利度/完整度）。出分自动展开。
  bool _showDetail = false;

  /// 回放录音时的脉冲动画。
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant SubtitleView old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex ||
        old.shadowMode != widget.shadowMode) {
      _ensureCurrentVisible();
    }
    // 新出分 → 自动展开详情；换句/重录 → 收起。
    final wasScored = old.shadow.isScored;
    final nowScored = widget.shadow.isScored;
    if (nowScored && !wasScored) {
      _showDetail = true;
    } else if (!nowScored && _showDetail) {
      _showDetail = false;
    }
  }

  void _ensureCurrentVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _currentKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.only(top: 18, bottom: 44),
          itemCount: widget.sentences.length,
          separatorBuilder: (_, _) => const SizedBox(height: 22),
          itemBuilder: (context, i) {
            final s = widget.sentences[i];
            final isCurrent = i == widget.currentIndex;
            if (!isCurrent) return _dimmed(s, i);
            return KeyedSubtree(
              key: _currentKey,
              child: widget.shadowMode ? _currentCard(s) : _currentPlain(s),
            );
          },
        ),
        // 底部渐隐
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 32,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withValues(alpha: 0),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // —— 非当前句：灰化，可点跳转 ——
  Widget _dimmed(Sentence s, int i) {
    return Opacity(
      opacity: 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onTapSentence(i),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showEn)
                Text(s.textEn,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: AppTypography.fallback,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    )),
              if (widget.showCn && s.textCn.isNotEmpty) ...[
                if (widget.showEn) const SizedBox(height: 4),
                Text(s.textCn,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: AppTypography.fallback,
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // —— 当前句（非跟读态）：放大高亮，无卡片 ——
  Widget _currentPlain(Sentence s) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onPlayOriginal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _currentText(s),
      ),
    );
  }

  // —— 当前句（跟读态）：白卡 + 控制排 + 评分详情 ——
  Widget _currentCard(Sentence s) {
    final scored = widget.shadow.isScored && widget.shadow.result != null;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _currentText(s),
          const SizedBox(height: 16),
          _controlRow(),
          if (scored && _showDetail) ...[
            const SizedBox(height: 14),
            _scoreDetail(widget.shadow.result!),
          ],
        ],
      ),
    );
  }

  Widget _currentText(Sentence s) {
    // 跟读态当前句英文始终显示（评测/播放原声需要）；否则按语言设置。
    final enOn = widget.showEn || widget.shadowMode;
    final cnOn = widget.showCn && s.textCn.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (enOn) _enText(s),
        if (cnOn) ...[
          if (enOn) const SizedBox(height: 6),
          // 当前句中文加深加重，与灰化句明显区分（对齐设计稿 2b）。
          Text(s.textCn,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontFamilyFallback: AppTypography.fallback,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.6,
                color: Color(0xFF5B6459),
              )),
        ],
      ],
    );
  }

  static const _enStyle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.fallback,
    fontSize: 19,
    fontWeight: FontWeight.w600,
    height: 1.55,
    color: AppColors.textPrimary,
  );

  /// 当前句英文：出分后按词级评分上色，否则纯文本。
  Widget _enText(Sentence s) {
    final r = widget.shadow.result;
    if (!widget.shadowMode ||
        !widget.shadow.isScored ||
        r == null ||
        r.words.isEmpty) {
      return Text(s.textEn, style: _enStyle);
    }
    final tokens = s.textEn.split(RegExp(r'\s+'));
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < tokens.length; i++)
            TextSpan(
              text: i == tokens.length - 1 ? tokens[i] : '${tokens[i]} ',
              style: _enStyle.copyWith(
                color: _wordColor(i < r.words.length ? r.words[i].score : null),
              ),
            ),
        ],
      ),
    );
  }

  // —— 控制排：播放原声 / 跟读录制 / 跟读播放 / 分数环 ——
  Widget _controlRow() {
    return Row(
      children: [
        _playOriginalButton(),
        const SizedBox(width: 20),
        _recordButton(),
        const SizedBox(width: 20),
        _playbackButton(),
        const Spacer(),
        _scoreRing(),
      ],
    );
  }

  /// 播放原声：外圈进度环显示当前句播放进度。
  Widget _playOriginalButton() {
    return GestureDetector(
      onTap: widget.onPlayOriginal,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ValueListenableBuilder<double>(
              valueListenable: widget.originalProgress,
              builder: (context, p, _) => p < 0
                  ? const SizedBox.shrink()
                  : SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: p,
                        strokeWidth: 3,
                        backgroundColor: AppColors.primaryTint,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.primary, size: 24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordButton() {
    switch (widget.shadow.status) {
      case ShadowStatus.recording:
        return _circleBtn(
          size: 48,
          bg: AppColors.danger,
          icon: Icons.stop_rounded,
          iconColor: Colors.white,
          iconSize: 26,
          shadow: true,
          onTap: widget.onRecord,
        );
      case ShadowStatus.evaluating:
        return Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.primaryDeep,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          ),
        );
      case ShadowStatus.idle:
      case ShadowStatus.scored:
      case ShadowStatus.error:
        return _circleBtn(
          size: 48,
          bg: AppColors.primaryDeep,
          icon: Icons.mic,
          iconColor: Colors.white,
          iconSize: 22,
          shadow: true,
          onTap: widget.onRecord,
        );
    }
  }

  Widget _playbackButton() {
    final enabled = widget.shadow.canPlayback;
    final playing = widget.playingRecording && enabled;
    final icon = Icon(
      playing ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
      color: enabled ? AppColors.primary : AppColors.textMuted,
      size: 22,
    );
    return GestureDetector(
      onTap: enabled ? widget.onPlayback : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryTint : AppColors.border,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: playing
            ? ScaleTransition(
                scale: Tween(begin: 0.82, end: 1.12).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: icon,
              )
            : icon,
      ),
    );
  }

  Widget _circleBtn({
    required double size,
    required Color bg,
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required VoidCallback? onTap,
    bool shadow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: shadow
              ? [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }

  Widget _scoreRing() {
    final r = widget.shadow.result;
    final scored = widget.shadow.isScored && r != null;
    final degraded = scored && r.degraded;
    final showNum = scored && !degraded;
    final label = showNum ? '${r.overall.round()}' : (degraded ? '!' : '--');
    final color = showNum
        ? _scoreColor(r.overall)
        : (degraded ? AppColors.warning : AppColors.textMuted);
    return GestureDetector(
      onTap: scored ? () => setState(() => _showDetail = !_showDetail) : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryTint,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.fallback,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  // —— 评分详情：发音/流利度/完整度；降级显示提示 ——
  Widget _scoreDetail(EvaluateResult result) {
    if (result.degraded) {
      final msg = result.message;
      return Text(
        (msg != null && msg.isNotEmpty) ? msg : '评测暂不可用，请稍后重试',
        style: AppTypography.bodySecondary.copyWith(color: AppColors.warning),
      );
    }
    return Row(
      children: [
        _metric('发音', result.accuracy),
        _metric('流利度', result.fluency),
        _metric('完整度', result.integrity),
      ],
    );
  }

  Widget _metric(String label, double value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '${value.round()}',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.fallback,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _scoreColor(value),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.caption.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }

  Color _wordColor(double? score) {
    if (score == null) return AppColors.textPrimary;
    if (score >= 85) return AppColors.primary;
    if (score < 60) return AppColors.warning;
    return AppColors.textPrimary;
  }

  Color _scoreColor(double overall) {
    if (overall >= 85) return AppColors.primary;
    if (overall < 60) return AppColors.warning;
    return AppColors.primaryDeep;
  }
}
