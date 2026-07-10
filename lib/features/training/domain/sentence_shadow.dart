import 'evaluate_result.dart';

/// 单句跟读状态机的状态。
enum ShadowStatus { idle, recording, evaluating, scored, error }

/// 某一句（按 seq）的跟读态：录音路径 + 评测结果。
class SentenceShadow {
  const SentenceShadow({
    this.status = ShadowStatus.idle,
    this.recordPath,
    this.result,
    this.error,
  });

  final ShadowStatus status;
  final String? recordPath;
  final EvaluateResult? result;
  final String? error;

  bool get isRecording => status == ShadowStatus.recording;
  bool get isEvaluating => status == ShadowStatus.evaluating;
  bool get isScored => status == ShadowStatus.scored;

  /// 录过音即可回放（出分或评测失败都保留录音）。
  bool get canPlayback =>
      recordPath != null &&
      (status == ShadowStatus.scored || status == ShadowStatus.error);

  static const idle = SentenceShadow();
}
