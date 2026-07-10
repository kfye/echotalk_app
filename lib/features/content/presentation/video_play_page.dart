import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../../../core/audio/clip_player.dart';
import '../../../core/audio/recorder_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../training/application/subtitle_providers.dart';
import '../../training/data/training_repository.dart';
import '../../training/domain/sentence_shadow.dart';
import '../../training/domain/subtitle.dart';
import '../../training/presentation/subtitle_view.dart';
import '../application/content_providers.dart';
import '../domain/video.dart';
import 'fullscreen_video_page.dart';
import 'slideshow_page.dart';

/// 播放模式：阅读（默认）/ AB 复读。全屏、幻灯片为“动作”（push 新页），不常驻。
enum PlayMode { reading, abRepeat }

/// 播放模式菜单项（含全屏/幻灯片动作）。
enum _PlayModeMenu { reading, ab, fullscreen, slideshow }

/// 进度条轨道：在默认轨道之上叠画 AB 琥珀区段。
/// 层级：原轨道 → 琥珀区段 → 当前进度指示点（thumb 由 Slider 在轨道后绘制，天然在上）。
class _AbTrackShape extends RoundedRectSliderTrackShape {
  const _AbTrackShape({this.abRange});

  /// AB 归一化区间 (fa, fb)；null 表示不画。
  final (double, double)? abRange;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    super.paint(
      context,
      offset,
      parentBox: parentBox,
      sliderTheme: sliderTheme,
      enableAnimation: enableAnimation,
      textDirection: textDirection,
      thumbCenter: thumbCenter,
      secondaryOffset: secondaryOffset,
      isDiscrete: isDiscrete,
      isEnabled: isEnabled,
      additionalActiveTrackHeight: additionalActiveTrackHeight,
    );
    final range = abRange;
    if (range == null) return;
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final left = rect.left + range.$1 * rect.width;
    final right = rect.left + range.$2 * rect.width;
    final cy = rect.center.dy;
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, cy - 2, right, cy + 2),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.warning,
    );
  }
}

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

class _ShadowPlayer extends ConsumerStatefulWidget {
  const _ShadowPlayer({required this.detail});
  final VideoDetail detail;

  @override
  ConsumerState<_ShadowPlayer> createState() => _ShadowPlayerState();
}

class _ShadowPlayerState extends ConsumerState<_ShadowPlayer> {
  VideoPlayerController? _controller;
  String? _error;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];
  double _speed = 1.0;

  // 影子跟读态
  Subtitle? _subtitle; // 由 subtitleProvider 异步注入
  int _currentIndex = -1; // 当前句（-1=未到首句起点，不高亮）
  bool _shadowMode = false; // 「跟读原文」展开
  bool _loopSingle = false; // 「单句播放」循环
  int? _playOnceUntilMs; // 非空=正在单句播放一次，播到该毫秒即暂停
  int? _seekTargetMs; // 手动 seek 目标；未落定前忽略旧位置的高亮回跳

  // 逐句录音/评测态（key=seq），录音全局互斥。
  final Map<int, SentenceShadow> _shadows = {};
  int? _recordingSeq;

  SentenceShadow _shadowFor(int seq) => _shadows[seq] ?? SentenceShadow.idle;

  // 播放页增强
  SubtitleLang _subtitleLang = SubtitleLang.both; // 字幕语言显示
  bool _skipGap = false; // 跳过背景音（句间空档直接跳读）

  // 菜单锚点（从按钮位置弹出）
  final _speedKey = GlobalKey();
  final _subtitleKey = GlobalKey();
  final _playModeKey = GlobalKey();

  // 播放模式 + AB 复读
  PlayMode _playMode = PlayMode.reading;
  int? _abStart; // AB 起点句 index
  int? _abEnd; // AB 终点句 index
  bool _abPlaying = false; // AB 已确认、循环播放中
  final ValueNotifier<double> _originalProgress = ValueNotifier(-1); // 播放原声进度环（-1=隐藏）
  bool _playingRecording = false; // 录音回放中（回放按钮动画）
  StreamSubscription<bool>? _recPlaySub;

  @override
  void initState() {
    super.initState();
    final url = widget.detail.hlsUrl!;
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    c.addListener(_onTick);
    c.initialize().then((_) {
      if (mounted) setState(() {});
    }).catchError((_) {
      if (mounted) setState(() => _error = '视频加载失败，请重试');
    });
    // 录音回放播放态 → 回放按钮动画
    _recPlaySub = ref.read(clipPlayerProvider).playingStream.listen((p) {
      if (mounted) setState(() => _playingRecording = p);
    });
  }

  @override
  void deactivate() {
    // 离开播放页（返回上一级）即停播，避免视频/音频在后台继续。
    _controller?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _recPlaySub?.cancel();
    _originalProgress.dispose();
    _controller?.removeListener(_onTick);
    _controller?.pause();
    _controller?.dispose();
    super.dispose();
  }

  /// 播放进度回调：播完复位 + 单句一次/循环 + 当前句高亮跟随。
  void _onTick() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    // 播放结束：复位到视频开头（暂停、清空高亮）。
    if (c.value.isCompleted) {
      c.seekTo(Duration.zero);
      c.pause();
      _clearPlayOnce();
      if (_currentIndex != -1) setState(() => _currentIndex = -1);
      return;
    }

    final ms = c.value.position.inMilliseconds;

    // 单句播放一次（跟读态·播放原声）：更新进度环；播到句尾自动暂停。
    final until = _playOnceUntilMs;
    if (until != null) {
      _updateOriginalProgress(ms, until);
      if (c.value.isPlaying && ms >= until) {
        c.pause();
        _clearPlayOnce();
      }
      return;
    }

    final sub = _subtitle;
    if (sub == null || sub.isEmpty) return;

    // AB 复读：从 A 起点循环播到 B 终点，支持倍速；高亮在 A..B 内跟随。
    if (_playMode == PlayMode.abRepeat &&
        _abPlaying &&
        _abStart != null &&
        _abEnd != null) {
      final a = sub.sentences[_abStart!];
      final b = sub.sentences[_abEnd!];
      if (c.value.isPlaying && ms >= b.endMs) {
        c.seekTo(Duration(milliseconds: a.startMs));
        return;
      }
      _syncHighlight(ms);
      return;
    }

    // 单句循环：播到句尾拉回句首，且不自动切句。
    if (_loopSingle && _currentIndex >= 0 && _currentIndex < sub.sentences.length) {
      final cur = sub.sentences[_currentIndex];
      if (c.value.isPlaying && ms >= cur.endMs) {
        c.seekTo(Duration(milliseconds: cur.startMs));
        return;
      }
      return;
    }

    // 手动 seek 未落定前，位置还是旧值：跳过，避免高亮回跳到旧句。
    final target = _seekTargetMs;
    if (target != null) {
      if ((ms - target).abs() > 400) return;
      _seekTargetMs = null;
    }

    // 跳过背景音：当前句已放完、离下一句起点还有空档 → 直接跳到下一句起点。
    if (_skipGap &&
        c.value.isPlaying &&
        _currentIndex >= 0 &&
        _currentIndex + 1 < sub.sentences.length) {
      final cur = sub.sentences[_currentIndex];
      final next = sub.sentences[_currentIndex + 1];
      if (ms >= cur.endMs && next.startMs > ms + 150) {
        _seekTargetMs = next.startMs;
        c.seekTo(Duration(milliseconds: next.startMs));
        setState(() => _currentIndex = _currentIndex + 1);
        return;
      }
    }

    // 常规：高亮跟随进度（含 seek 到任意位置）。
    _syncHighlight(ms);
  }

  /// 更新播放原声进度环（0..1）。
  void _updateOriginalProgress(int ms, int untilMs) {
    final sub = _subtitle;
    if (sub == null || _currentIndex < 0 || _currentIndex >= sub.sentences.length) {
      return;
    }
    final start = sub.sentences[_currentIndex].startMs;
    final span = untilMs - start;
    _originalProgress.value =
        span <= 0 ? 0 : ((ms - start) / span).clamp(0.0, 1.0);
  }

  void _clearPlayOnce() {
    _playOnceUntilMs = null;
    _originalProgress.value = -1;
  }

  /// 按播放毫秒把高亮同步到最合理的当前句（首句前为 -1，不高亮）。
  void _syncHighlight(int ms) {
    final sub = _subtitle;
    if (sub == null || sub.isEmpty) return;
    final idx = sub.indexAt(ms);
    if (idx != _currentIndex) setState(() => _currentIndex = idx);
  }

  void _togglePlay() {
    _exitShadow();
    _clearPlayOnce(); // 恢复整段连续播放
    _seekTargetMs = null;
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  // —— 影子跟读交互 ——

  /// 跳到第 i 句、定位到句首。
  /// [autoplay]=true 连续播放（导航）；false 只 seek 并**暂停**在句首
  /// （跟读态下点句：不播视频，仅停在该句起点，等「播放原声」触发）。
  void _gotoSentence(int i, {bool autoplay = true}) {
    final sub = _subtitle;
    final c = _controller;
    if (sub == null || sub.isEmpty || c == null) return;
    if (_recordingSeq != null) _cancelRecording();
    _clearPlayOnce();
    _seekTargetMs = null;
    final idx = i.clamp(0, sub.sentences.length - 1);
    setState(() => _currentIndex = idx);
    c.seekTo(Duration(milliseconds: sub.sentences[idx].startMs));
    autoplay ? c.play() : c.pause();
  }

  /// 播放当前句原声：从句首播到句尾**仅一次**，不续播下一句。
  ///
  /// 先 `await seekTo` 让位置真正落到句首，再设句尾边界并播放——否则
  /// 上一次单句播放停在句尾时，位置尚是旧句尾 >= 边界，会被立即暂停
  /// （表现为“要点两次才播”）。
  Future<void> _playCurrentSentence() async {
    final sub = _subtitle;
    final c = _controller;
    if (sub == null || sub.isEmpty || c == null) return;
    final idx = _currentIndex.clamp(0, sub.sentences.length - 1);
    final cur = sub.sentences[idx];
    _clearPlayOnce();
    _seekTargetMs = null;
    await c.seekTo(Duration(milliseconds: cur.startMs));
    if (!mounted || _controller != c) return;
    _playOnceUntilMs = cur.endMs; // 播到句尾自动暂停（见 _onTick）
    c.play();
  }

  void _toggleShadow() {
    setState(() {
      _shadowMode = !_shadowMode;
      // 进入跟读态必须有当前句：未到首句时默认聚焦第 0 句。
      if (_shadowMode && _currentIndex < 0) _currentIndex = 0;
    });
    // 进入跟读态：暂停整段播放，聚焦当前句（原声由「播放原声」驱动）。
    if (_shadowMode) _controller?.pause();
  }

  /// 退出跟读态（字幕区以外的操作触发，倍速除外）。
  void _exitShadow() {
    if (_recordingSeq != null) _cancelRecording();
    if (_shadowMode) setState(() => _shadowMode = false);
  }

  void _toggleLoop() {
    _exitShadow();
    setState(() => _loopSingle = !_loopSingle);
  }

  void _prev() {
    _exitShadow();
    _gotoSentence(_currentIndex - 1);
  }

  void _next() {
    _exitShadow();
    _gotoSentence(_currentIndex + 1);
  }

  // —— 逐句录音 / 评测 / 回放 ——

  /// 录制按钮：非录音态 → 开录；录音态 → 停录并上传评测。
  Future<void> _toggleRecord() async {
    final sub = _subtitle;
    if (sub == null || sub.isEmpty) return;
    final seq = _currentIndex.clamp(0, sub.sentences.length - 1);
    if (_shadowFor(seq).isRecording) {
      await _stopAndEvaluate(seq, sub.sentences[seq]);
    } else {
      await _startRecord(seq);
    }
  }

  Future<void> _startRecord(int seq) async {
    final recorder = ref.read(recorderServiceProvider);
    if (!await recorder.hasPermission()) {
      _toast('需要麦克风权限才能跟读录音');
      return;
    }
    await _cancelRecording(); // 录音互斥：先丢弃别句未完成的录音
    _controller?.pause();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/rec_${widget.detail.id}_$seq.wav';
    try {
      await recorder.start(path);
    } catch (_) {
      _toast('录音启动失败');
      return;
    }
    if (!mounted) return;
    _recordingSeq = seq;
    setState(() => _shadows[seq] =
        SentenceShadow(status: ShadowStatus.recording, recordPath: path));
  }

  Future<void> _stopAndEvaluate(int seq, Sentence cur) async {
    _recordingSeq = null;
    String? stopped;
    try {
      stopped = await ref.read(recorderServiceProvider).stop();
    } catch (_) {}
    final path = stopped ?? _shadowFor(seq).recordPath;
    if (path == null) {
      if (mounted) setState(() => _shadows[seq] = SentenceShadow.idle);
      return;
    }
    setState(() => _shadows[seq] =
        SentenceShadow(status: ShadowStatus.evaluating, recordPath: path));
    try {
      final result = await ref.read(trainingRepositoryProvider).evaluate(
            audioPath: path,
            videoId: widget.detail.id,
            sentenceIndex: seq,
            text: cur.textEn,
          );
      if (!mounted) return;
      setState(() => _shadows[seq] = SentenceShadow(
            status: ShadowStatus.scored,
            recordPath: path,
            result: result,
          ));
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : '评测失败，请重试';
      setState(() => _shadows[seq] = SentenceShadow(
            status: ShadowStatus.error,
            recordPath: path,
            error: msg,
          ));
      _toast(msg);
    }
  }

  /// 停止并丢弃当前进行中的录音（导航/退出跟读时调用）。
  Future<void> _cancelRecording() async {
    final seq = _recordingSeq;
    if (seq == null) return;
    _recordingSeq = null;
    try {
      await ref.read(recorderServiceProvider).stop();
    } catch (_) {}
    if (mounted) setState(() => _shadows[seq] = SentenceShadow.idle);
  }

  /// 回放当前句录音（just_audio）。
  Future<void> _playRecording() async {
    final sub = _subtitle;
    if (sub == null || sub.isEmpty) return;
    final seq = _currentIndex.clamp(0, sub.sentences.length - 1);
    final path = _shadowFor(seq).recordPath;
    if (path == null) return;
    _controller?.pause();
    try {
      await ref.read(clipPlayerProvider).playFile(path);
    } catch (_) {
      _toast('回放失败');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // —— 播放页增强交互 ——

  void _toggleSkipGap() {
    _exitShadow();
    setState(() => _skipGap = !_skipGap);
  }

  /// 进入横屏全屏播放（复用当前 controller）。退出后同步倍速。
  Future<void> _enterFullscreen() async {
    _exitShadow();
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FullscreenVideoPage(
          controller: c,
          subtitle: _subtitle,
          subtitleLang: _subtitleLang,
          speeds: _speeds,
          speed: _speed,
          onSpeedChanged: (s) => _speed = s,
        ),
      ),
    );
    if (mounted) setState(() {}); // 返回后刷新倍速显示等
  }

  Future<void> _enterSlideshow() async {
    _exitShadow();
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    c.play();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SlideshowPage(
          controller: c,
          subtitle: _subtitle,
          subtitleLang: _subtitleLang,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  // —— 播放模式菜单（从按钮位置弹出、宽度适配文本）——
  Future<void> _openPlayModeMenu() async {
    _exitShadow();
    final picked = await _showAnchoredMenu<_PlayModeMenu>(_playModeKey, [
      (_PlayModeMenu.reading, '阅读模式', _playMode == PlayMode.reading),
      (_PlayModeMenu.ab, 'AB 复读', _playMode == PlayMode.abRepeat),
      (_PlayModeMenu.fullscreen, '全屏模式', false),
      (_PlayModeMenu.slideshow, '幻灯片模式', false),
    ]);
    if (!mounted || picked == null) return;
    switch (picked) {
      case _PlayModeMenu.reading:
        setState(() => _playMode = PlayMode.reading);
      case _PlayModeMenu.ab:
        _enterABMode();
      case _PlayModeMenu.fullscreen:
        _enterFullscreen();
      case _PlayModeMenu.slideshow:
        _enterSlideshow();
    }
  }

  // —— AB 复读 ——
  void _enterABMode() {
    setState(() {
      _playMode = PlayMode.abRepeat;
      _loopSingle = false;
      _skipGap = false;
      _abStart = null;
      _abEnd = null;
      _abPlaying = false;
    });
    _clearPlayOnce();
    _controller?.pause();
  }

  void _exitAB() {
    setState(() {
      _playMode = PlayMode.reading;
      _abPlaying = false;
      _abStart = null;
      _abEnd = null;
    });
  }

  void _setAbStart() {
    if (_currentIndex < 0) return;
    setState(() {
      _abStart = _currentIndex;
      if (_abEnd != null && _abEnd! < _abStart!) _abEnd = _abStart;
    });
  }

  void _setAbEnd() {
    if (_currentIndex < 0) return;
    setState(() {
      _abEnd = _currentIndex;
      if (_abStart != null && _abStart! > _abEnd!) _abStart = _abEnd;
    });
  }

  void _confirmAB() {
    final sub = _subtitle;
    final c = _controller;
    if (sub == null || c == null || _abStart == null || _abEnd == null) return;
    setState(() {
      _abPlaying = true;
      _currentIndex = _abStart!;
    });
    c.seekTo(Duration(milliseconds: sub.sentences[_abStart!].startMs));
    c.play();
  }

  void _resetAB() {
    setState(() {
      _abPlaying = false;
      _abStart = null;
      _abEnd = null;
    });
    _controller?.pause();
  }

  Future<void> _openSpeedMenu() async {
    final picked = await _showAnchoredMenu<double>(_speedKey, [
      for (final s in _speeds) (s, '${s}x', s == _speed),
    ]);
    if (picked != null && mounted) {
      setState(() => _speed = picked);
      _controller?.setPlaybackSpeed(picked);
    }
  }

  Future<void> _openSubtitleMenu() async {
    _exitShadow();
    final picked = await _showAnchoredMenu<SubtitleLang>(_subtitleKey, [
      (SubtitleLang.cn, '中文字幕', _subtitleLang == SubtitleLang.cn),
      (SubtitleLang.en, '英文字幕', _subtitleLang == SubtitleLang.en),
      (SubtitleLang.both, '中英字幕', _subtitleLang == SubtitleLang.both),
      (SubtitleLang.none, '无', _subtitleLang == SubtitleLang.none),
    ]);
    if (picked != null && mounted) setState(() => _subtitleLang = picked);
  }

  /// 从 [anchorKey] 对应按钮**上方**弹出菜单，宽度随内容自适应；
  /// 轻微上升 + 淡入动画（非 0→100 高度展开）。
  Future<T?> _showAnchoredMenu<T>(
      GlobalKey anchorKey, List<(T, String, bool)> items) {
    final ctx = anchorKey.currentContext;
    if (ctx == null) return Future<T?>.value(null);
    final box = ctx.findRenderObject() as RenderBox;
    final buttonRect = box.localToGlobal(Offset.zero) & box.size;
    final screen = MediaQuery.of(context).size;
    final rightAligned = buttonRect.center.dx > screen.width / 2;

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '菜单',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dctx, _, _) {
        return Stack(
          children: [
            Positioned(
              left: rightAligned ? null : buttonRect.left,
              right: rightAligned ? screen.width - buttonRect.right : null,
              // 菜单底边落在按钮上方 8px → 从按钮上方展开
              bottom: screen.height - buttonRect.top + 8,
              child: Material(
                color: AppColors.surface,
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final it in items)
                        InkWell(
                          onTap: () => Navigator.of(dctx).pop(it.$1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                            child: Row(
                              children: [
                                Text(it.$2,
                                    style: TextStyle(
                                      fontFamily: AppTypography.fontFamily,
                                      fontFamilyFallback:
                                          AppTypography.fallback,
                                      fontSize: 14,
                                      fontWeight: it.$3
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: it.$3
                                          ? AppColors.primaryDeep
                                          : AppColors.textPrimary,
                                    )),
                                if (it.$3) ...[
                                  const SizedBox(width: 16),
                                  const Icon(Icons.check,
                                      size: 18,
                                      color: AppColors.primaryDeep),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (dctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  /// 视频底部叠加字幕（按语言设置显示当前句；none/无当前句时隐藏）。
  /// 叠在视频画面底部，白字描边，像播放器内嵌字幕。
  Widget _videoCaption() {
    final sub = _subtitle;
    if (_subtitleLang == SubtitleLang.none ||
        sub == null ||
        _currentIndex < 0 ||
        _currentIndex >= sub.sentences.length) {
      return const SizedBox.shrink();
    }
    final s = sub.sentences[_currentIndex];
    final lines = <String>[
      if ((_subtitleLang == SubtitleLang.en ||
              _subtitleLang == SubtitleLang.both) &&
          s.textEn.isNotEmpty)
        s.textEn,
      if ((_subtitleLang == SubtitleLang.cn ||
              _subtitleLang == SubtitleLang.both) &&
          s.textCn.isNotEmpty)
        s.textCn,
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Positioned(
      left: 12,
      right: 12,
      bottom: 8,
      child: IgnorePointer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lines.length; i++)
              Text(
                lines[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontFamilyFallback: AppTypography.fallback,
                  fontSize: i == 0 ? 15 : 13,
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                  color: i == 0 ? Colors.white : Colors.white70,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _videoArea(),
          Expanded(child: _subtitleArea()),
          _controlPanel(),
        ],
      ),
    );
  }

  Widget _subtitleArea() {
    final url = widget.detail.subtitleEnUrl;
    if (url == null || url.isEmpty) return _subtitlePlaceholder();
    final async = ref.watch(subtitleProvider(url));
    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, _) => _subtitlePlaceholder(),
      data: (sub) {
        // 注入进度回调所需的字幕（无论 provider 是否已缓存都能拿到）。
        _subtitle = sub;
        if (sub.isEmpty) return _subtitlePlaceholder();
        final inRange = _currentIndex >= 0 && _currentIndex < sub.sentences.length;
        return SubtitleView(
          sentences: sub.sentences,
          currentIndex: _currentIndex, // -1/越界 = 无当前句，交由视图处理
          shadowMode: _shadowMode,
          shadow: inRange ? _shadowFor(_currentIndex) : SentenceShadow.idle,
          // 字幕切换仅作用于视频底部字幕；列表恒显示中英。
          originalProgress: _originalProgress,
          playingRecording: _playingRecording,
          // 跟读态/AB 选段时点句：只 seek 并暂停在句首，不自动播放；否则连播。
          onTapSentence: (i) => _gotoSentence(i,
              autoplay: !_shadowMode && _playMode != PlayMode.abRepeat),
          onPlayOriginal: _playCurrentSentence,
          onRecord: _toggleRecord,
          onPlayback: _playRecording,
        );
      },
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
          // 视频底部叠加字幕（字幕切换控制其语言）
          _videoCaption(),
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
          _playMode == PlayMode.abRepeat ? _abControlRow() : _toolRow(),
          const SizedBox(height: AppSpacing.sm),
          _progress(),
          _bottomControls(),
        ],
      ),
    );
  }

  // 跟读工具排。
  Widget _toolRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToolButton(
          asset: 'assets/icons/tool_single.svg',
          label: '单句播放',
          active: _loopSingle,
          onTap: _toggleLoop,
        ),
        _ToolButton(
          asset: 'assets/icons/tool_skip_bg.svg',
          label: '跳过背景音',
          active: _skipGap,
          onTap: _toggleSkipGap,
        ),
        _ToolButton(
          key: _playModeKey,
          asset: 'assets/icons/tool_play_mode.svg',
          label: '播放模式',
          onTap: _openPlayModeMenu,
        ),
        _ToolButton(
          asset: 'assets/icons/tool_mic.svg',
          label: '跟读原文',
          active: _shadowMode,
          onTap: _toggleShadow,
        ),
        _ToolButton(
          key: _subtitleKey,
          asset: 'assets/icons/tool_subtitle.svg',
          label: '字幕切换',
          onTap: _openSubtitleMenu,
        ),
      ],
    );
  }

  // AB 复读控制排：设A / 设B / 确认 / 重置 / 退出。
  Widget _abControlRow() {
    String seqLabel(int? i) => i == null ? '—' : '句${i + 1}';
    final canConfirm = _abStart != null &&
        _abEnd != null &&
        _abStart! <= _abEnd! &&
        !_abPlaying;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _abBtn('起点 ${seqLabel(_abStart)}', Icons.flag_outlined,
            active: _abStart != null, onTap: _setAbStart),
        _abBtn('终点 ${seqLabel(_abEnd)}', Icons.outlined_flag,
            active: _abEnd != null, onTap: _setAbEnd),
        _abBtn(_abPlaying ? '播放中' : '确认', Icons.check_circle_outline,
            active: _abPlaying,
            onTap: canConfirm ? _confirmAB : null),
        _abBtn('重置', Icons.refresh, onTap: _resetAB),
        _abBtn('退出', Icons.close, onTap: _exitAB),
      ],
    );
  }

  Widget _abBtn(String label, IconData icon,
      {bool active = false, VoidCallback? onTap}) {
    final color = onTap == null
        ? AppColors.textMuted
        : (active ? AppColors.primaryDeep : Colors.black);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 23, color: color),
          const SizedBox(height: 4),
          Text(label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              )),
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
                // AB 复读时，琥珀区段画在轨道之上、指示点之下（层级：轨道→琥珀→当前位置）。
                trackShape: _AbTrackShape(abRange: _abTrackRange(max)),
              ),
              child: Slider(
                value: pos,
                max: max,
                onChanged: (v) {
                  _exitShadow();
                  _clearPlayOnce();
                  final ms = v.toInt();
                  _seekTargetMs = ms; // 标记目标，屏蔽 seek 落定前的回跳
                  c.seekTo(Duration(milliseconds: ms));
                  _syncHighlight(ms); // 高亮即时跟随拖动位置
                },
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

  /// AB 复读时的 A→B 归一化区间 (fa, fb)；非 AB / 未设范围返回 null。
  (double, double)? _abTrackRange(double maxMs) {
    final sub = _subtitle;
    if (_playMode != PlayMode.abRepeat ||
        _abStart == null ||
        _abEnd == null ||
        sub == null ||
        maxMs <= 0) {
      return null;
    }
    final fa = (sub.sentences[_abStart!].startMs / maxMs).clamp(0.0, 1.0);
    final fb = (sub.sentences[_abEnd!].endMs / maxMs).clamp(0.0, 1.0);
    return (fa, fb);
  }

  Widget _bottomControls() {
    final c = _controller;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 倍速：弹菜单选择；定宽避免切换不同倍速时挤动右侧按钮。
        SizedBox(
          key: _speedKey,
          width: 60,
          child: GestureDetector(
            onTap: _openSpeedMenu,
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
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous),
          iconSize: 30,
          color: Colors.black,
          onPressed: _prev, // 上一句
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
          onPressed: _next, // 下一句
        ),
        IconButton(
          icon: const Icon(Icons.fullscreen),
          iconSize: 28,
          color: Colors.black,
          onPressed: _enterFullscreen, // 横屏全屏
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

/// 跟读工具按钮。图标用设计稿原始 SVG；激活态（单句播放/跟读原文）主色加粗。
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    super.key,
    required this.asset,
    required this.label,
    required this.onTap,
    this.active = false,
  });
  final String asset;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primaryDeep : Colors.black;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            asset,
            width: 23,
            height: 23,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: AppTypography.caption.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              )),
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
