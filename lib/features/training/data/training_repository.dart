import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/evaluate_result.dart';
import 'training_api.dart';

/// 训练编排层（Day 10 直透传，预留 Day 12 历史/缓存）。
class TrainingRepository {
  TrainingRepository(this._api);

  final TrainingApi _api;

  Future<EvaluateResult> evaluate({
    required String audioPath,
    required int videoId,
    required int sentenceIndex,
    required String text,
  }) {
    return _api.evaluate(
      audioPath: audioPath,
      videoId: videoId,
      sentenceIndex: sentenceIndex,
      text: text,
    );
  }
}

final trainingRepositoryProvider = Provider<TrainingRepository>(
  (ref) => TrainingRepository(ref.watch(trainingApiProvider)),
);
