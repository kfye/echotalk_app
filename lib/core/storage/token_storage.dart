import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// token 安全存储。Android 走 Keystore、iOS 走 Keychain，避免明文落盘。
///
/// 只处理裸字符串，不感知 features/auth 的领域模型（TokenPair）——
/// 领域模型 ↔ 字符串的映射由 T3 的 auth_repository 负责，保持 core 层不反向依赖上层。
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  Future<String?> readAccess() => _storage.read(key: _kAccess);

  Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  Future<void> save({
    required String access,
    required String refresh,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }
}

/// 全局单例 provider，供网络层与 T3/T4 复用。
final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
