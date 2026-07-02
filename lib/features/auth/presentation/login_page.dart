import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';

/// 登录页占位（T5 填真实表单：邮箱/密码 + 登录 + 错误提示 + loading）。
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Login（占位，T5 实现）'),
            TextButton(
              onPressed: () => context.push(AppRoutes.register),
              child: const Text('去注册'),
            ),
          ],
        ),
      ),
    );
  }
}
