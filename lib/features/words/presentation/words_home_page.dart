import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../application/word_providers.dart';
import '../domain/word.dart';

/// 首页·单词（设计稿 1c）：只有一张深绿 Hero 卡（高频3000单词·口语速练），
/// 下方留白（其余模块后续再加）。嵌入 ContentListPage 的「单词」tab。
class WordsHomeView extends ConsumerWidget {
  const WordsHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl),
      children: [
        _HeroCard(onStart: () {
          ref.read(requestedWordLevelProvider.notifier).set(WordLevel.a1);
          context.push(AppRoutes.wordPractice);
        }),
      ],
    );
  }
}

/// 深绿 Hero 卡。
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    // 设计稿卡片长宽比 ≈ 16:10（实测 W/H=1.60）。
    return AspectRatio(
      aspectRatio: 1.6,
      child: ClipRRect(
        borderRadius: AppRadius.largeCard,
        child: Container(
          color: AppColors.primaryDeep,
          child: Stack(
            children: [
              // 右侧装饰圆环
              Positioned(
                right: -20,
                top: -40,
                child: _circle(180, Colors.white.withValues(alpha: 0.06)),
              ),
              Positioned(
                right: 10,
                bottom: -60,
                child: _circle(150, Colors.white.withValues(alpha: 0.05)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('高频 3000 单词',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            )),
                        const Text('口语速练',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            )),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'A1 入门·初中基础   A2 基础日常对话\n'
                          'B1 独立交流·高中/PET   B2 流利交流·四级+\n'
                          'C1 熟练·六级/考研',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12.5,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDeep,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                      ),
                      child: const Text('开始速练'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
