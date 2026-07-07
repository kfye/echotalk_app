import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../application/content_providers.dart';
import '../domain/video.dart';

/// 播放页（2a）：顶部 16:9 视频区 + 中部句级字幕区（Day 10）+ 底部控制条。
/// Day 9 可用：HLS 播放/暂停、进度拖动、倍速。跟读按钮/上下句/全屏为占位。
class VideoPlayPage extends ConsumerWidget {
  const VideoPlayPage({super.key, required this.videoId});

  final int videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(videoDetailProvider(videoId));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _CenteredMessage(
          message: e is ApiException ? e.message : '加载失败',
          onBack: () => context.pop(),
        ),
        data: (detail) {
          if (detail.locked || (detail.hlsUrl ?? '').isEmpty) {
            return _LockedView(detail: detail);
          }
          return _ShadowPlayer(detail: detail);
        },
      ),
    );
  }
}

/// 会员内容占位（付费墙 Day 11）。
class _LockedView extends StatelessWidget {
  const _LockedView({required this.detail});
  final VideoDetail detail;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _TopBar(title: detail.title, cefr: detail.cefrLabel, dark: false),
          const Spacer(),
          const Icon(Icons.lock_outline, size: 48, color: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Text('该内容为会员内容', style: AppTypography.body),
          const SizedBox(height: AppSpacing.xs),
          Text('开通会员后可跟读（付费墙 Day 11）',
              style: AppTypography.bodySecondary),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _ShadowPlayer extends StatefulWidget {
  const _ShadowPlayer({required this.detail});
  final VideoDetail detail;

  @override
  State<_ShadowPlayer> createState() => _ShadowPlayerState();
}

class _ShadowPlayerState extends State<_ShadowPlayer> {
  VideoPlayerController? _controller;
  String? _error;

  static const _speeds = [0.75, 1.0, 1.25, 1.5];
  double _speed = 1.0;

  @override
  void initState() {
    super.initState();
    final url = widget.detail.hlsUrl!;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    c.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() => _error = '视频加载失败，请重试');
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  void _cycleSpeed() {
    final i = _speeds.indexOf(_speed);
    setState(() => _speed = _speeds[(i + 1) % _speeds.length]);
    _controller?.setPlaybackSpeed(_speed);
  }

  void _soon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('该功能 Day 10 上线')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _videoArea(),
          Expanded(child: _subtitlePlaceholder()),
          _controlPanel(),
        ],
      ),
    );
  }

  Widget _videoArea() {
    final c = _controller;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          if (c != null)
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: c,
              builder: (context, v, _) {
                if (!v.isInitialized) {
                  return Center(
                    child: _error != null
                        ? Text(_error!,
                            style: AppTypography.bodySecondary
                                .copyWith(color: Colors.white70))
                        : const CircularProgressIndicator(
                            color: Colors.white),
                  );
                }
                return GestureDetector(
                  onTap: _togglePlay,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 视频完整显示、居中：宽于 16:9 上下留黑边，高于 16:9 左右留黑边。
                      Center(
                        child: AspectRatio(
                          aspectRatio: v.aspectRatio,
                          child: VideoPlayer(c),
                        ),
                      ),
                      if (!v.isPlaying)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow,
                                color: AppColors.primaryDeep, size: 40),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          // 顶部返回/标题/等级
          _TopBar(
            title: widget.detail.title,
            cefr: widget.detail.cefrLabel,
            dark: true,
          ),
        ],
      ),
    );
  }

  Widget _subtitlePlaceholder() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.primaryTint.withValues(alpha: 0.45),
          borderRadius: AppRadius.largeCard,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.subtitles_outlined,
                size: 34, color: AppColors.primary),
            const SizedBox(height: AppSpacing.sm),
            Text('句级字幕即将上线',
                style: AppTypography.body
                    .copyWith(color: AppColors.primaryDeep)),
            const SizedBox(height: AppSpacing.xs),
            Text('跟读 · 高亮 · 评分（Day 10）',
                style: AppTypography.bodySecondary),
          ],
        ),
      ),
    );
  }

  Widget _controlPanel() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 跟读按钮排（占位禁用）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _ToolButton(asset: 'assets/icons/tool_single.svg', label: '单句播放'),
              _ToolButton(
                  asset: 'assets/icons/tool_skip_bg.svg', label: '跳过背景音'),
              _ToolButton(
                  asset: 'assets/icons/tool_play_mode.svg', label: '播放模式'),
              _ToolButton(asset: 'assets/icons/tool_mic.svg', label: '跟读原文'),
              _ToolButton(
                  asset: 'assets/icons/tool_subtitle.svg', label: '字幕切换'),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _progress(),
          _bottomControls(),
        ],
      ),
    );
  }

  Widget _progress() {
    final c = _controller;
    if (c == null) return const SizedBox(height: 32);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (context, value, _) {
        final dur = value.duration.inMilliseconds.toDouble();
        final max = dur <= 0 ? 1.0 : dur;
        final pos = value.position.inMilliseconds.toDouble().clamp(0.0, max);
        return Column(
          children: [
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: AppColors.primaryTint,
                thumbColor: AppColors.primary,
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8.5),
              ),
              child: Slider(
                value: pos,
                max: max,
                onChanged: (v) =>
                    c.seekTo(Duration(milliseconds: v.toInt())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  Text(_fmt(value.position), style: _timeStyle),
                  const Spacer(),
                  Text(_fmt(value.duration), style: _timeStyle),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _bottomControls() {
    final c = _controller;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 倍速（可用）
        GestureDetector(
          onTap: _cycleSpeed,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${_speed}x',
                  style: AppTypography.h2.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black)),
              Text('倍速',
                  style: AppTypography.caption
                      .copyWith(fontSize: 12, color: Colors.black)),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 30,
          color: Colors.black,
          onPressed: _soon, // 上一句 Day 10
        ),
        // 播放/暂停（可用）
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: AppColors.primaryDeep,
              shape: BoxShape.circle,
            ),
            child: c == null
                ? const SizedBox()
                : ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: c,
                    builder: (context, v, _) => Icon(
                      v.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 30,
          color: Colors.black,
          onPressed: _soon, // 下一句 Day 10
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen),
          iconSize: 28,
          color: Colors.black,
          onPressed: _soon, // 全屏 Day 10
        ),
      ],
    );
  }

  static const _timeStyle = TextStyle(
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.fallback,
    fontSize: 12,
    color: Colors.black,
  );

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// 视频区顶部叠加：返回 + 标题 + CEFR。dark=true 时用于深色视频上。
class _TopBar extends StatelessWidget {
  const _TopBar(
      {required this.title, required this.cefr, required this.dark});
  final String title;
  final String cefr;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : AppColors.textPrimary;
    final bar = Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: fg),
          onPressed: () => context.pop(),
        ),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.h2.copyWith(fontSize: 16, color: fg),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // 视频上（dark）只显示等级文字，不加背景；locked 页用浅绿药丸。
        dark
            ? Text(cefr,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: AppTypography.fallback,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ))
            : Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(cefr,
                    style: const TextStyle(
                      fontFamily: AppTypography.fontFamily,
                      fontFamilyFallback: AppTypography.fallback,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDeep,
                    )),
              ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
    if (!dark) return bar;
    // 深色视频上加顶部渐变，保证文字可读
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: bar,
      ),
    );
  }
}

/// 跟读工具按钮（Day 9 占位禁用）。图标用设计稿原始 SVG，统一黑色。
class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.asset, required this.label});
  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    void soon() => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('该功能 Day 10 上线')));
    return GestureDetector(
      onTap: soon,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            asset,
            width: 23,
            height: 23,
            colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: Colors.black, fontSize: 12)),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({required this.message, required this.onBack});
  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: onBack),
          ),
          const Spacer(),
          Text(message, style: AppTypography.bodySecondary),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}
