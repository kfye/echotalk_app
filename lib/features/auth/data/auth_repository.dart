import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../domain/token_pair.dart';
import '../domain/user.dart';
import 'auth_api.dart';

/// 账号数据仓库：编排 AuthApi + TokenStorage，供 T4 的 auth_controller 调用。
///
/// controller 只依赖本类，不碰 dio；网络/存储细节收敛在 data 层。
class AuthRepository {
  AuthRepository(this._api, this._storage);

  final AuthApi _api;
  final TokenStorage _storage;

  /// 登录成功即持久化 token（领域模型 ↔ 字符串的映射点）。
  Future<void> login(String phone, String password) async {
    final TokenPair pair = await _api.login(phone, password);
    await _storage.save(
      access: pair.accessToken,
      refresh: pair.refreshToken,
    );
  }

  /// 仅注册（不自动登录）；"注册后自动登录"由 controller 编排 register→login。
  Future<User> register(
    String phone,
    String password, {
    String? nickname,
    required String code,
  }) {
    return _api.register(phone, password, nickname: nickname, code: code);
  }

  Future<void> sendCode(String phone) => _api.sendCode(phone);

  Future<UserProfile> profile() => _api.profile();

  /// best-effort 登出：后端失败也要清本地 token，避免"登不出去"。
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // 忽略后端登出错误，仍清本地会话。
    } finally {
      await _storage.clear();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authApiProvider),
    ref.watch(tokenStorageProvider),
  ),
);
