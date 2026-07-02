import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 会话失效事件广播。
///
/// 当刷新 token 失败（refresh 也过期/无效）时，AuthInterceptor 向此流推一个事件；
/// T4 的 auth_controller 监听它 → 置 unauthenticated → 路由守卫跳登录。
///
/// 这样 core 网络层无需反向依赖 features/auth 的 controller，单向解耦。
final authEventsProvider = Provider<StreamController<void>>((ref) {
  final controller = StreamController<void>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});
