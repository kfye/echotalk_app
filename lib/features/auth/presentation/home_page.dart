import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

/// 首页占位（个人中心雏形）：展示已登录用户信息 + 登出。
/// 用于验证会话有效与「登出 → 守卫跳登录」闭环；正式首页后续迭代。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final profile = auth is AuthAuthenticated ? auth.profile : null;

    final nickname =
        (profile?.nickname.isNotEmpty ?? false) ? profile!.nickname : '学习者';
    final phone = profile?.phone ?? '';
    final initial = nickname.characters.first.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    initial,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(nickname,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(phone,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.graphic_eq_rounded),
                      title: Text('影子跟读'),
                      subtitle: Text('核心功能开发中'),
                      trailing: Icon(Icons.chevron_right),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.workspace_premium_outlined,
                          color: theme.colorScheme.primary),
                      title: const Text('会员'),
                      subtitle: const Text('付费墙开发中'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('退出登录'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
