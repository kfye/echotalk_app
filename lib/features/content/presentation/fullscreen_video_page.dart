import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../training/domain/subtitle.dart';
import '../../training/presentation/subtitle_view.dart' show SubtitleLang;

/// 横屏全屏播放页。复用外部传入的 [controller]（不重建），
/// 进入横屏 + 沉浸式；退出恢复竖屏 + 系统栏。
class FullscreenVideoPage extends StatefulWidget {
  const FullscreenVideoPage({
    super.key,
    required this.controller,
    required this.subtitle,
    required this.subtitleLang,
    required this.speeds,
    required this.speed,
    required this.onSpeedChanged,
  });

  final VideoPlayerController controller;
  final Subtitle? subtitle;
  final SubtitleLang subtitleLang;
  final List<double> speeds;
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage> {
  bool _controlsVisible = true;
  Timer? _hideTimer;
  late double _speed = widget.speed;

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
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // 恢复竖屏 + 系统栏
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _togglePlay() {
    final c = widget.controller;
    if (!c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
    _scheduleHide();
  }

  void _openSpeedMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text('播放速度', style: AppTypography.h2.copyWith(fontSize: 15)),
            const SizedBox(height: AppSpacing.xs),
            for (final s in widget.speeds)
              ListTile(
                title: Text('${s}x',
                    style: TextStyle(
                      fontWeight:
                          s == _speed ? FontWeight.w700 : FontWeight.w400,
                      color: s == _speed
                          ? AppColors.primaryDeep
                          : AppColors.textPrimary,
                    )),
                trailing: s == _speed
                    ? const Icon(Icons.check, color: AppColors.primaryDeep)
                    : null,
                onTap: () {
                  setState(() => _speed = s);
                  widget.controller.setPlaybackSpeed(s);
                  widget.onSpeedChanged(s);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (context, v, _) => v.isInitialized
                    ? AspectRatio(
                        aspectRatio: v.aspectRatio,
                        child: VideoPlayer(c),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
              ),
            ),
            _caption(),
            if (_controlsVisible) _controls(),
          ],
        ),
      ),
    );
  }

  Widget _caption() {
    final sub = widget.subtitle;
    if (widget.subtitleLang == SubtitleLang.none || sub == null || sub.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      left: 24,
      right: 24,
      bottom: _controlsVisible ? 96 : 40,
      child: IgnorePointer(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: widget.controller,
          builder: (context, v, _) {
            final idx = sub.indexAt(v.position.inMilliseconds);
            if (idx < 0 || idx >= sub.sentences.length) {
              return const SizedBox.shrink();
            }
            final s = sub.sentences[idx];
            final lines = <String>[
              if (_showEn && s.textEn.isNotEmpty) s.textEn,
              if (_showCn && s.textCn.isNotEmpty) s.textCn,
            ];
            if (lines.isEmpty) return const SizedBox.shrink();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < lines.length; i++)
                  Text(
                    lines[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: AppTypography.fallback,
                      fontSize: i == 0 ? 18 : 15,
                      fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                      color: Colors.white,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _controls() {
    final c = widget.controller;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.28),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部：退出
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Spacer(),
              // 中间：播放/暂停
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: c,
                builder: (context, v, _) => GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      v.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.primaryDeep,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // 底部：进度 + 倍速 + 退出全屏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: [
                    _progress(),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _openSpeedMenu,
                          behavior: HitTestBehavior.opaque,
                          child: Text('${_speed}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              )),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.fullscreen_exit,
                              color: Colors.white, size: 26),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progress() {
    final c = widget.controller;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        final dur = value.duration.inMilliseconds.toDouble();
        final max = dur <= 0 ? 1.0 : dur;
        final pos = value.position.inMilliseconds.toDouble().clamp(0.0, max);
        return Row(
          children: [
            Text(_fmt(value.position),
                style: const TextStyle(color: Colors.white, fontSize: 12)),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: pos,
                  max: max,
                  onChanged: (v) {
                    c.seekTo(Duration(milliseconds: v.toInt()));
                    _scheduleHide();
                  },
                ),
              ),
            ),
            Text(_fmt(value.duration),
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
