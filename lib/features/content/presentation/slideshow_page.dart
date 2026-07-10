import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../training/domain/subtitle.dart';
import '../../training/presentation/subtitle_view.dart' show SubtitleLang;

/// 幻灯片模式：黑底白字大号显示当前句字幕，随进度切换。
/// 隐藏视频画面（不渲染 VideoPlayer），但 [controller] 继续播放音频。
/// 横屏沉浸；点按/返回退出，恢复竖屏。
class SlideshowPage extends StatefulWidget {
  const SlideshowPage({
    super.key,
    required this.controller,
    required this.subtitle,
    required this.subtitleLang,
  });

  final VideoPlayerController controller;
  final Subtitle? subtitle;
  final SubtitleLang subtitleLang;

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  bool _controlsVisible = true;

  bool get _showEn =>
      widget.subtitleLang == SubtitleLang.both ||
      widget.subtitleLang == SubtitleLang.en;
  bool get _showCn =>
      widget.subtitleLang == SubtitleLang.both ||
      widget.subtitleLang == SubtitleLang.cn;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 大号字幕
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: widget.controller,
                  builder: (context, v, _) => _subtitle(v),
                ),
              ),
            ),
            // 顶部退出 + 播放/暂停
            if (_controlsVisible)
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            if (_controlsVisible)
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: widget.controller,
                      builder: (context, v, _) => IconButton(
                        icon: Icon(
                          v.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          color: Colors.white70,
                          size: 44,
                        ),
                        onPressed: () {
                          v.isPlaying
                              ? widget.controller.pause()
                              : widget.controller.play();
                        },
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _subtitle(VideoPlayerValue v) {
    final sub = widget.subtitle;
    if (sub == null || sub.isEmpty) {
      return const Text('暂无字幕',
          style: TextStyle(color: Colors.white38, fontSize: 20));
    }
    final idx = sub.indexAt(v.position.inMilliseconds);
    if (idx < 0 || idx >= sub.sentences.length) {
      return const SizedBox.shrink();
    }
    final s = sub.sentences[idx];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showEn && s.textEn.isNotEmpty)
          Text(
            s.textEn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.fallback,
              fontSize: 34,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: Colors.white,
            ),
          ),
        if (_showCn && s.textCn.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            s.textCn,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontFamilyFallback: AppTypography.fallback,
              fontSize: 22,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
        ],
      ],
    );
  }
}
