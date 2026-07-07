import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/video.dart';

/// 内容网格卡片：封面(免费/VIP 角标 + 时长) + 标题 + CEFR 徽标。
class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.item, required this.onTap});

  final VideoListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: AppRadius.card,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _cover(),
                  Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: item.isFree ? _freeBadge() : _vipBadge(),
                  ),
                  Positioned(
                    bottom: AppSpacing.sm,
                    right: AppSpacing.sm,
                    child: _durationBadge(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.h2.copyWith(
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _cefrBadge(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cover() {
    if (item.coverUrl.isEmpty) return _coverPlaceholder();
    return Image.network(
      item.coverUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _coverPlaceholder(loading: true);
      },
      errorBuilder: (_, _, _) => _coverPlaceholder(),
    );
  }

  Widget _coverPlaceholder({bool loading = false}) {
    return Container(
      color: AppColors.primaryTint,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.movie_outlined, color: AppColors.primary, size: 28),
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: AppTypography.fallback,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _freeBadge() =>
      _pill('免费', AppColors.primaryTint, AppColors.primaryDeep);

  Widget _vipBadge() => _pill('VIP', AppColors.warning, Colors.white);

  Widget _durationBadge() =>
      _pill(item.durationText, Colors.black.withValues(alpha: 0.55), Colors.white);

  Widget _cefrBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        item.cefrLabel,
        style: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontFamilyFallback: AppTypography.fallback,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.primaryDeep,
        ),
      ),
    );
  }
}
