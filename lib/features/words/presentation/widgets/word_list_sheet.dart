import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/word.dart';

/// 单词列表弹层（设计稿 2d）：列出当前可练列表，可切「显示/隐藏释义」，
/// 点某词回调选中并关闭。
class WordListSheet extends StatefulWidget {
  const WordListSheet({
    super.key,
    required this.words,
    required this.currentWord,
    required this.onSelect,
  });

  final List<Word> words;

  /// 当前词（高亮），可空。
  final String? currentWord;
  final ValueChanged<Word> onSelect;

  /// 便捷弹出。
  static Future<void> show(
    BuildContext context, {
    required List<Word> words,
    required String? currentWord,
    required ValueChanged<Word> onSelect,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      isScrollControlled: true,
      builder: (_) => WordListSheet(
        words: words,
        currentWord: currentWord,
        onSelect: onSelect,
      ),
    );
  }

  @override
  State<WordListSheet> createState() => _WordListSheetState();
}

class _WordListSheetState extends State<WordListSheet> {
  bool _showMeaning = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: AppRadius.pill,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
            child: Row(
              children: [
                Text('单词列表', style: AppTypography.h2),
                const SizedBox(width: AppSpacing.sm),
                Text('${widget.words.length}', style: AppTypography.bodySecondary),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showMeaning = !_showMeaning),
                  icon: Icon(
                    _showMeaning ? Icons.visibility : Icons.visibility_off,
                    size: 18,
                  ),
                  label: Text(_showMeaning ? '隐藏释义' : '显示释义'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.words.isEmpty
                ? const Center(
                    child: Text('暂无单词', style: AppTypography.bodySecondary))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    itemCount: widget.words.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final w = widget.words[i];
                      final active = w.w == widget.currentWord;
                      return ListTile(
                        title: Text(
                          w.w,
                          style: AppTypography.body.copyWith(
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? AppColors.primaryDeep
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: _showMeaning
                            ? Text(w.primaryMeaning,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodySecondary)
                            : null,
                        trailing: active
                            ? const Icon(Icons.check,
                                color: AppColors.primary, size: 20)
                            : null,
                        onTap: () {
                          widget.onSelect(w);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
