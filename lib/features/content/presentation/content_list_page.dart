import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../application/content_providers.dart';
import 'widgets/video_card.dart';

/// 首页·跟读（1a）：训练模式 tab + 分类 chips + 双列内容网格。
class ContentListPage extends ConsumerWidget {
  const ContentListPage({super.key});

  static const _modes = ['发音', '跟读', '单词', '语句', '听力'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            _categoryChips(ref),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _grid(context, ref)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu),
            color: AppColors.textPrimary,
            onPressed: () => _soon(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final m in _modes) _modeTab(context, m),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            color: AppColors.textPrimary,
            onPressed: () => _soon(context),
          ),
        ],
      ),
    );
  }

  Widget _modeTab(BuildContext context, String mode) {
    final active = mode == '跟读';
    return GestureDetector(
      onTap: active ? null : () => _soon(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode,
              style: AppTypography.h2.copyWith(
                fontSize: 18,
                color: active ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 2.5,
              width: 18,
              decoration: BoxDecoration(
                color: active ? AppColors.primary : Colors.transparent,
                borderRadius: AppRadius.pill,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips(WidgetRef ref) {
    final categories = ref.watch(videoCategoriesProvider);
    final selected = ref.watch(videoListProvider.notifier).category;

    final chips = <({String? raw, String label})>[
      (raw: null, label: '推荐'),
      ...categories.maybeWhen(
        data: (list) => list.map((c) => (raw: c.raw, label: c.label)),
        orElse: () => const [],
      ),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final c = chips[i];
          final isSel = c.raw == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(videoListProvider.notifier).setCategory(c.raw),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: isSel ? AppColors.primaryDeep : Colors.white,
                borderRadius: AppRadius.pill,
                border: Border.all(
                  color: isSel ? AppColors.primaryDeep : AppColors.border,
                ),
              ),
              child: Text(
                c.label,
                style: AppTypography.bodySecondary.copyWith(
                  fontSize: 14,
                  color: isSel ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _grid(BuildContext context, WidgetRef ref) {
    final async = ref.watch(videoListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _errorState(ref, e),
      data: (items) {
        if (items.isEmpty) return _emptyState();
        return RefreshIndicator(
          onRefresh: () => ref.read(videoListProvider.notifier).refresh(),
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm,
                AppSpacing.xl, AppSpacing.xl),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.lg,
              mainAxisSpacing: AppSpacing.xl,
              childAspectRatio: 0.70,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return VideoCard(
                item: item,
                onTap: () => context.push('${AppRoutes.video}/${item.id}'),
              );
            },
          ),
        );
      },
    );
  }

  Widget _errorState(WidgetRef ref, Object e) {
    final msg = e is ApiException ? e.message : '加载失败';
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(msg, style: AppTypography.bodySecondary),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () => ref.read(videoListProvider.notifier).refresh(),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => const Center(
        child: Text('暂无内容', style: AppTypography.bodySecondary),
      );

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('敬请期待')));
  }
}
