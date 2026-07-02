import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_controller.dart';

/// 首页占位（T5 填个人中心：昵称/邮箱展示等）。这里先展示已登录信息 + 登出，
/// 用于验证会话有效与登出→跳登录的守卫闭环。
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final nickname =
        auth is AuthAuthenticated ? auth.profile.nickname : '(未知)';
    final email = auth is AuthAuthenticated ? auth.profile.email : '';

    return Scaffold(
      appBar: AppBar(title: const Text('首页')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('已登录：$nickname'),
            Text(email),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              child: const Text('登出'),
            ),
          ],
        ),
      ),
    );
  }
}
