import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/auth_events.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

/// 全局鉴权状态（三态）。
sealed class AuthState {
  const AuthState();
}

/// 启动态：尚未判定（splash 阶段）。
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// 未登录 / 会话失效。
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// 已登录，携带个人信息。
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.profile);
  final UserProfile profile;
}

/// 鉴权状态机。UI 只读 [AuthState]，登录/注册/登出经方法驱动。
///
/// 订阅 [authEventsProvider]：拦截器刷新失败广播时 → 立即置未登录 → 路由守卫跳登录。
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final events = ref.watch(authEventsProvider);
    final sub = events.stream.listen((_) {
      state = const AuthUnauthenticated();
    });
    ref.onDispose(sub.cancel);
    return const AuthUnknown();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);

  /// 冷启动判定：无 token → 未登录；有 token → 拉 profile（过期会经拦截器自动刷新），
  /// 成功 → 已登录；最终失败（含刷新失败）→ 未登录。
  Future<void> bootstrap() async {
    final token = await _storage.readAccess();
    if (token == null || token.isEmpty) {
      state = const AuthUnauthenticated();
      return;
    }
    try {
      final profile = await _repo.profile();
      state = AuthAuthenticated(profile);
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  /// 登录 → 存 pair（repo 内完成）→ 拉 profile → 已登录。异常上抛给页面提示。
  Future<void> login(String phone, String password) async {
    await _repo.login(phone, password);
    final profile = await _repo.profile();
    state = AuthAuthenticated(profile);
  }

  /// 注册 → 复用 login 自动登录。异常上抛给页面提示。
  Future<void> register(
    String phone,
    String password, {
    String? nickname,
    required String code,
  }) async {
    await _repo.register(phone, password, nickname: nickname, code: code);
    await login(phone, password);
  }

  /// best-effort 登出（repo 内已保证清本地 token）→ 未登录。
  Future<void> logout() async {
    await _repo.logout();
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
