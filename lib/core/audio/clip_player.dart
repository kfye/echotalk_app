import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

/// 本地录音回放（just_audio，变速不变调；此处仅原速回放）。
/// 原声回放复用视频播放器，不经此类。
class ClipPlayer {
  final AudioPlayer _player = AudioPlayer();

  /// 是否正在播放录音（用于回放按钮动画）。
  /// 播放结束（processingState=completed）视为“未播放”，让按钮恢复待播态。
  Stream<bool> get playingStream => _player.playerStateStream
      .map((s) =>
          s.playing && s.processingState != ProcessingState.completed)
      .distinct();

  /// 从头播放本地 WAV 文件。
  Future<void> playFile(String path) async {
    await _player.setFilePath(path);
    await _player.seek(Duration.zero);
    await _player.play();
  }

  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}

final clipPlayerProvider = Provider<ClipPlayer>((ref) {
  final p = ClipPlayer();
  ref.onDispose(() {
    p.dispose();
  });
  return p;
});
