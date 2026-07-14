import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

/// 单词发音播放器。
///
/// 分工（实测有道 dictvoice 只能合成单个单词，多词/句子一律 500）：
///   - 单词：有道词典发音 `https://dict.youdao.com/dictvoice?audio=<word>&type=1|2`
///     （type=1 英式、type=2 美式），just_audio 播放 + setSpeed 变速不变调。
///   - 例句：设备系统 TTS（flutter_tts）。设备无英文 TTS 引擎时静默跳过。
class WordAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  static Uri _voiceUrl(String word, {required bool us}) => Uri.https(
        'dict.youdao.com',
        '/dictvoice',
        {'audio': word, 'type': us ? '2' : '1'},
      );

  /// 有道单词发音，await 到播放结束。失败会抛出（由调用方兜底提示）。
  Future<void> _playYoudaoWord(String word,
      {required bool us, double speed = 1.0}) async {
    if (word.trim().isEmpty) return;
    await _player.setUrl(_voiceUrl(word, us: us).toString());
    await _player.setSpeed(speed);
    await _player.seek(Duration.zero);
    // just_audio 的 play() 在播放自然结束时才 complete。
    await _player.play();
  }

  /// 设备 TTS 读例句，尽力而为：无引擎/语言不可用/引擎挂死则静默跳过。
  ///
  /// 关键：某些设备/模拟器的 TTS 引擎会崩溃或不回调完成，导致 speak() 永久挂起
  /// 冻住播放态。故整体加超时兜底，超时即 stop 并返回。
  Future<void> _speakExample(String text,
      {required bool us, double speed = 1.0}) async {
    if (text.trim().isEmpty) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage(us ? 'en-US' : 'en-GB');
      // flutter_tts 语速 0.0–1.0，约 0.5 为正常语速；按倍速线性映射。
      await _tts.setSpeechRate((0.5 * speed).clamp(0.0, 1.0));
      await _tts.speak(text).timeout(
        const Duration(seconds: 12),
        onTimeout: () async {
          await _tts.stop();
          return 1;
        },
      );
    } catch (_) {
      // 设备无 TTS 引擎或引擎异常，例句发音跳过。
      await _tts.stop().catchError((_) {});
    }
  }

  /// 只播单词发音。
  Future<void> playWord(String word, {required bool us, double speed = 1.0}) =>
      _playYoudaoWord(word, us: us, speed: speed);

  /// 依次播放：单词发音（有道）→ 例句发音（设备 TTS，尽力而为）。
  /// 单词失败会抛出；例句失败被吞掉不影响单词。
  Future<void> playWordThenExample(
    String word,
    String example, {
    required bool us,
    double speed = 1.0,
  }) async {
    await _playYoudaoWord(word, us: us, speed: speed);
    await _speakExample(example, us: us, speed: speed);
  }

  Future<void> stop() async {
    await _player.stop();
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
    await _tts.stop();
  }
}

final wordAudioPlayerProvider = Provider<WordAudioPlayer>((ref) {
  final p = WordAudioPlayer();
  ref.onDispose(p.dispose);
  return p;
});
