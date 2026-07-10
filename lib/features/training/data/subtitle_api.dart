import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/config/env.dart';

/// 拉取字幕文件（COS/CDN 上的纯文本，非业务信封 JSON）。
///
/// 带**磁盘缓存**：字幕内容按 URL 不可变，加载过即写入 app 缓存目录，
/// 下次直接读本地（免网络、免等待、可离线），跨重启有效。
///
/// 用**裸 Dio**（不挂鉴权/信封拦截器）：字幕是公开静态资源、绝对 URL，
/// 返回体不是 `{code,msg,data}` 信封，走主 dio 会被 EnvelopeInterceptor 拦截。
class SubtitleApi {
  SubtitleApi(this._dio);
  final Dio _dio;

  Future<String> fetch(String url) async {
    // 1) 命中磁盘缓存直接返回
    final cached = await _readCache(url);
    if (cached != null && cached.isNotEmpty) return cached;

    // 2) 回源
    final resp = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );
    final data = resp.data ?? '';

    // 3) 写缓存（失败静默，不影响主流程）
    if (data.isNotEmpty) unawaited(_writeCache(url, data));
    return data;
  }

  Future<Directory> _cacheDir() async {
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/subtitles');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<File> _fileFor(String url) async =>
      File('${(await _cacheDir()).path}/${_hash(url)}.srtx');

  Future<String?> _readCache(String url) async {
    try {
      final f = await _fileFor(url);
      if (await f.exists()) return await f.readAsString();
    } catch (_) {
      // 缓存不可用则回源
    }
    return null;
  }

  Future<void> _writeCache(String url, String data) async {
    try {
      await (await _fileFor(url)).writeAsString(data);
    } catch (_) {
      // 写缓存失败无妨
    }
  }

  /// URL → 稳定文件名（FNV-1a，避免引入 crypto 依赖）。
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }
}

final subtitleApiProvider = Provider<SubtitleApi>((ref) {
  final dio = Dio(BaseOptions(
    connectTimeout: Env.connectTimeout,
    receiveTimeout: Env.receiveTimeout,
  ));
  return SubtitleApi(dio);
});
