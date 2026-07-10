import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

/// 录音服务：产出后端讯飞 ISE 需要的 **16K/16bit/单声道 WAV**。
///
/// `AudioEncoder.wav` 输出 PCM 16-bit WAV；`sampleRate:16000 + numChannels:1`
/// 满足评测接口约束（见 openapi /training/evaluate）。
class RecorderService {
  final AudioRecorder _rec = AudioRecorder();

  /// 是否已授予麦克风权限（未授予会拉起系统权限弹窗）。
  Future<bool> hasPermission() => _rec.hasPermission();

  Future<bool> isRecording() => _rec.isRecording();

  /// 开始录音，写入 [path]（.wav）。
  Future<void> start(String path) {
    return _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
  }

  /// 停止录音，返回落盘路径（失败/未录返回 null）。
  Future<String?> stop() => _rec.stop();

  Future<void> dispose() => _rec.dispose();
}

final recorderServiceProvider = Provider<RecorderService>((ref) {
  final s = RecorderService();
  ref.onDispose(() {
    s.dispose();
  });
  return s;
});
