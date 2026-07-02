import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echotalk_app/app.dart';
import 'package:echotalk_app/core/storage/token_storage.dart';

/// 内存空存储：无 token，模拟未登录冷启动（避免 secure_storage 平台依赖）。
class _EmptyStorage extends TokenStorage {
  @override
  Future<String?> readAccess() async => null;
  @override
  Future<String?> readRefresh() async => null;
  @override
  Future<void> save({required String access, required String refresh}) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('冷启动无 token → splash 判定后跳登录页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [tokenStorageProvider.overrideWithValue(_EmptyStorage())],
        child: const EchoTalkApp(),
      ),
    );

    // 初始帧：splash 的 loading。
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // bootstrap 判定为未登录 → 路由守卫跳 /login。
    await tester.pumpAndSettle();
    expect(find.text('去注册'), findsOneWidget);
  });
}
