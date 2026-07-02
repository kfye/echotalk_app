import 'package:flutter/material.dart';

/// 注册页占位（T5 填：邮箱/密码/昵称/验证码 + 发送验证码 → 注册成功自动登录）。
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: const Center(child: Text('Register（占位，T5 实现）')),
    );
  }
}
