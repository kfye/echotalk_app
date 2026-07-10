import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_call.dart';
import '../../../core/network/dio_client.dart';
import '../domain/evaluate_result.dart';

/// 训练 / 评测 HTTP 端点（openapi tags: training）。
/// 走主 dio（带鉴权 + 信封剥离），multipart 上传录音。
class TrainingApi {
  TrainingApi(this._dio);

  final Dio _dio;

  /// 上传一段录音（16K/16bit/单声道 WAV）评测。
  Future<EvaluateResult> evaluate({
    required String audioPath,
    required int videoId,
    required int sentenceIndex,
    required String text,
  }) {
    return guardApiCall(() async {
      final form = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioPath,
          filename: 'rec_${videoId}_$sentenceIndex.wav',
        ),
        'video_id': videoId,
        'sentence_index': sentenceIndex,
        'text': text,
      });
      final resp = await _dio.post<dynamic>('/training/evaluate', data: form);
      return EvaluateResult.fromJson(resp.data as Map<String, dynamic>);
    });
  }
}

final trainingApiProvider = Provider<TrainingApi>(
  (ref) => TrainingApi(ref.watch(dioProvider)),
);
