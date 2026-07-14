import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/word.dart';

/// 单词内容（设计稿 2c）：无卡片容器，直接铺在页面背景上。
/// 大号单词 + ★收藏 / 音标同行(绿字+喇叭) / 跟读 / 释义(可遮) / 分隔线 / 原声·词典 / 例句(高亮词) / 页脚。
class WordCard extends StatelessWidget {
  const WordCard({
    super.key,
    required this.word,
    required this.us,
    required this.maskMeaning,
    required this.revealed,
    required this.isFavorite,
    required this.isRecording,
    required this.onReveal,
    required this.onToggleAccent,
    required this.onPlayAccent,
    required this.onToggleFavorite,
    required this.onToggleRecord,
  });

  final Word word;
  final bool us;
  final bool maskMeaning;
  final bool revealed;
  final bool isFavorite;
  final bool isRecording;
  final VoidCallback onReveal;
  final ValueChanged<bool> onToggleAccent;
  final ValueChanged<bool> onPlayAccent;
  final VoidCallback onToggleFavorite;
  final VoidCallback onToggleRecord;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 大号单词 + 收藏
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                word.w,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: AppTypography.fallback,
                  color: AppColors.textPrimary,
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
            GestureDetector(
              onTap: onToggleFavorite,
              child: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                size: 28,
                color: isFavorite ? AppColors.warning : AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        // 英/美音标同行（绿字，喇叭试听）
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.sm,
          children: [
            _phonetic('英', word.uk, active: !us, accentUs: false),
            _phonetic('美', word.us, active: us, accentUs: true),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        _recordButton(),
        const SizedBox(height: AppSpacing.lg),
        _meaning(),
        const SizedBox(height: AppSpacing.lg),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),
        _exampleHeader(),
        const SizedBox(height: AppSpacing.md),
        _highlightedExample(),
        const SizedBox(height: AppSpacing.sm),
        Text(word.excn, style: AppTypography.bodySecondary),
        const SizedBox(height: AppSpacing.md),
        Text(
          '口语高频3000${word.tag.isEmpty ? '' : ' · ${word.tag}'}',
          style: AppTypography.caption,
        ),
      ],
    );
  }

  Widget _phonetic(String tag, String ipa,
      {required bool active, required bool accentUs}) {
    final color = active ? AppColors.primaryDeep : AppColors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onPlayAccent(accentUs),
          behavior: HitTestBehavior.opaque,
          child: Icon(Icons.volume_up, size: 18, color: color),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => onToggleAccent(accentUs),
          behavior: HitTestBehavior.opaque,
          child: Text(
            '$tag ${ipa.isEmpty ? '—' : '/$ipa/'}',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.fallback,
              color: color,
              fontSize: 15,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  /// 跟读：圆形麦克风按钮 + 独立文本（设计稿：icon 与文本分开）。录音中转暖色。
  Widget _recordButton() {
    final active = isRecording;
    return GestureDetector(
      onTap: onToggleRecord,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: active ? AppColors.warning : AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(active ? Icons.stop : Icons.mic,
                size: 20,
                color: active ? Colors.white : AppColors.primaryDeep),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            active ? '录音中·点击停止' : '跟读',
            style: AppTypography.body.copyWith(
              color: active ? AppColors.warning : AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meaning() {
    final masked = maskMeaning && !revealed;
    // 始终按真实释义占位，遮住时把释义设为透明并叠加占位提示，
    // 保证遮住与否高度一致，下方例句不上移。
    return GestureDetector(
      onTap: masked ? onReveal : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Opacity(
            opacity: masked ? 0 : 1,
            child: Text(word.cn, style: AppTypography.body),
          ),
          if (masked)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('● ● ● ● ●',
                        style: AppTypography.body
                            .copyWith(color: AppColors.textMuted)),
                    const SizedBox(width: AppSpacing.md),
                    Text('点击显示释义', style: AppTypography.bodySecondary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _exampleHeader() {
    return Row(
      children: [
        Icon(Icons.circle, size: 6, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text('暂无原声，例句来自词典',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        // 原声 | 词典（无原声，词典恒选中；选中态为白胶囊）
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: AppRadius.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _seg('原声', selected: false),
              _seg('词典', selected: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seg(String label, {required bool selected}) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: AppRadius.pill,
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: selected ? AppColors.primaryDeep : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      );

  /// 例句中把当前词（含词尾变体）高亮下划线。
  Widget _highlightedExample() {
    final ex = word.ex;
    final style = AppTypography.body.copyWith(fontSize: 18, height: 1.5);
    if (word.w.isEmpty || ex.isEmpty) {
      return Text(ex, style: style);
    }
    final lowerEx = ex.toLowerCase();
    final target = word.w.toLowerCase();
    final matches = <(int, int)>[];
    var from = 0;
    while (true) {
      final i = lowerEx.indexOf(target, from);
      if (i < 0) break;
      final beforeOk = i == 0 || !_isWordChar(lowerEx[i - 1]);
      if (beforeOk) matches.add((i, i + target.length));
      from = i + target.length;
    }
    if (matches.isEmpty) return Text(ex, style: style);

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final (start, end) in matches) {
      if (start > cursor) spans.add(TextSpan(text: ex.substring(cursor, start)));
      spans.add(TextSpan(
        text: ex.substring(start, end),
        style: const TextStyle(
          color: AppColors.primaryDeep,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ));
      cursor = end;
    }
    if (cursor < ex.length) spans.add(TextSpan(text: ex.substring(cursor)));
    return RichText(text: TextSpan(style: style, children: spans));
  }

  bool _isWordChar(String ch) {
    final c = ch.codeUnitAt(0);
    return (c >= 97 && c <= 122) || (c >= 48 && c <= 57);
  }
}
