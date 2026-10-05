import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/models/reader_settings.dart';
import '../../../domain/reading/wpm_scale.dart';
import '../../../routing/routes.dart';
import '../../../services/haptics.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/reader_theme.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/states.dart';
import '../../settings/application/settings_controller.dart';
import '../application/reader_controller.dart';
import '../engine/rsvp_engine.dart';
import 'widgets/chapter_sheet.dart';
import 'widgets/paused_context.dart';
import 'widgets/reader_controls.dart';
import 'widgets/reader_quick_settings.dart';
import 'widgets/rsvp_word_view.dart';
import 'widgets/wpm_picker.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.bookId, this.startIndex, super.key});

  final String bookId;
  final int? startIndex;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> with WidgetsBindingObserver {
  late final ReaderArgs _args = (bookId: widget.bookId, startIndex: widget.startIndex);

  bool _controlsVisible = true;
  bool _exiting = false;
  Timer? _hideTimer;
  final ValueNotifier<String?> _hud = ValueNotifier(null);
  Timer? _hudTimer;
  RsvpEngine? _listenedEngine;

  ReaderController get _controller => ref.read(readerControllerProvider(_args).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listenedEngine?.playing.removeListener(_onPlayingChanged);
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _hud.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _controller.handleLifecycle(state);

  Haptics get _haptics => Haptics(enabled: ref.read(readerSettingsProvider).hapticFeedback);

  // --- controls visibility ---------------------------------------------------

  void _attachEngine(RsvpEngine engine) {
    if (identical(engine, _listenedEngine)) return;
    _listenedEngine?.playing.removeListener(_onPlayingChanged);
    _listenedEngine = engine;
    engine.playing.addListener(_onPlayingChanged);
  }

  void _onPlayingChanged() {
    final playing = _listenedEngine?.isPlaying ?? false;
    if (playing) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
      if (!_controlsVisible) setState(() => _controlsVisible = true);
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!(_listenedEngine?.isPlaying ?? false)) return;
    _hideTimer = Timer(ReaderConstants.controlsAutoHideDelay, () {
      if (mounted && (_listenedEngine?.isPlaying ?? false)) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleHide();
  }

  void _showHud(String message) {
    _hudTimer?.cancel();
    _hud.value = message;
    _hudTimer = Timer(const Duration(milliseconds: 900), () => _hud.value = null);
  }

  // --- gestures --------------------------------------------------------------

  void _onHorizontalSwipe(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < ReaderConstants.minSwipeVelocity) return;
    final delta = v < 0 ? ReaderConstants.skipWordCount : -ReaderConstants.skipWordCount;
    _controller.skip(delta);
    _haptics.selection();
    _showHud(delta > 0 ? '+$delta words' : '$delta words');
  }

  void _onVerticalSwipe(DragEndDetails details, RsvpEngine engine) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < ReaderConstants.minSwipeVelocity) return;
    final next = WpmScale.step(engine.wpm.value, v < 0 ? 1 : -1);
    if (next == engine.wpm.value) return;
    _controller.setWpm(next);
    _haptics.selection();
    _showHud('$next WPM');
  }

  void _onLongPress(RsvpEngine engine) {
    if (!engine.isPlaying) return;
    _controller.pause();
    _haptics.medium();
  }

  void _togglePlay() {
    _controller.togglePlay();
    _haptics.light();
  }

  // --- sheets & exit -----------------------------------------------------------

  Future<void> _openChapters(RsvpEngine engine) async {
    _controller.pause();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChapterSheet(
        content: engine.content,
        position: engine.position.value,
        wpm: engine.wpm.value,
        onChapter: _controller.seekToChapter,
        onFraction: _controller.seekToFraction,
      ),
    );
  }

  Future<void> _openDisplaySettings() async {
    _controller.pause();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ReaderQuickSettings(),
    );
  }

  Future<void> _openWpm(RsvpEngine engine) async {
    _controller.pause();
    await showWpmSheet(context, initial: engine.wpm.value, onChanged: _controller.setWpm);
  }

  Future<void> _exit() async {
    if (_exiting) return;
    _exiting = true;
    final summary = await _controller.finish();
    if (!mounted) return;
    if (summary != null) {
      context.pushReplacement(Routes.sessionSummary, extra: summary);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.library);
    }
  }

  // --- build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readerControllerProvider(_args));
    final settings = ref.watch(readerSettingsProvider);
    final theme = ReaderTheme.of(settings.themeId);

    final Widget body = switch (state.status) {
      ReaderStatus.loading => Center(
          child: SizedBox.square(
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: theme.focal),
          ),
        ),
      ReaderStatus.error => SafeArea(
          child: Center(
            child: ErrorState(
              title: "This book couldn't be opened",
              error: state.error!,
              onRetry: () => context.canPop() ? context.pop() : context.go(Routes.library),
            ),
          ),
        ),
      ReaderStatus.ready => _buildReader(context, state, settings, theme),
    };

    return PopScope(
      canPop: state.status != ReaderStatus.ready,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: theme.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: theme.background,
          body: AnimatedContainer(
            duration: MotionConstants.medium,
            color: theme.background,
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildReader(BuildContext context, ReaderState state, ReaderSettings settings, ReaderTheme theme) {
    final engine = state.engine!;
    _attachEngine(engine);

    return LayoutBuilder(builder: (context, constraints) {
      final isTablet = constraints.maxWidth >= LayoutConstants.tabletBreakpoint;
      final landscape = constraints.maxWidth > constraints.maxHeight;
      final baseSize = isTablet
          ? ReaderConstants.tabletBaseWordSize
          : (constraints.maxWidth * ReaderConstants.baseWordSizeFactor).clamp(28.0, ReaderConstants.maxBaseWordSize);
      final fontSize = baseSize * settings.fontScale;
      final wordStyle = RsvpWordStyle(
        text: AppTypography.readerStyle(
          settings.font,
          size: fontSize,
          weight: FontWeight.values[(settings.weight.value ~/ 100) - 1],
        ),
        wordColor: theme.word,
        focalColor: theme.focal,
        guideColor: theme.guide,
        focalMode: settings.focalMode,
        showGuides: settings.showFocalGuides,
      );
      final wordZoneHeight = fontSize * 3.2;
      // The focal point stays slightly above centre, where the eye rests most
      // comfortably, and never moves when controls appear.
      final focalY = constraints.maxHeight * (landscape ? 0.42 : 0.40);

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onLongPress: () => _onLongPress(engine),
              onHorizontalDragEnd: _onHorizontalSwipe,
              onVerticalDragEnd: (d) => _onVerticalSwipe(d, engine),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: focalY - wordZoneHeight / 2,
            child: IgnorePointer(
              child: RsvpWordView(
                words: engine.content.words,
                position: engine.position,
                style: wordStyle,
                height: wordZoneHeight,
              ),
            ),
          ),
          if (settings.showContextWhenPaused)
            Positioned(
              left: 0,
              right: 0,
              top: focalY + wordZoneHeight / 2 + 8,
              child: IgnorePointer(child: PausedContext(engine: engine, theme: theme)),
            ),
          Positioned(
            left: 0,
            right: 0,
            top: focalY - wordZoneHeight / 2 - 44,
            child: IgnorePointer(child: _Hud(hud: _hud, theme: theme)),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: _FadingControls(
                visible: _controlsVisible,
                onInteract: _scheduleHide,
                child: ReaderTopBar(
                  engine: engine,
                  title: state.book!.title,
                  theme: theme,
                  onClose: _exit,
                  onChapters: () => _openChapters(engine),
                  onDisplaySettings: _openDisplaySettings,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: LayoutConstants.maxContentWidth),
                  child: _FadingControls(
                    visible: _controlsVisible,
                    onInteract: _scheduleHide,
                    child: ReaderBottomPanel(
                      engine: engine,
                      theme: theme,
                      onTogglePlay: _togglePlay,
                      onSkip: _controller.skip,
                      onWpmChanged: _controller.setWpm,
                      onOpenWpm: () => _openWpm(engine),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (state.chapterBreak != null)
            _ReaderOverlay(
              theme: theme,
              eyebrow: 'Chapter complete',
              title: engine.content.chapters[state.chapterBreak!].title,
              message: 'Up next. Take a breath, or keep going.',
              primaryLabel: 'Continue',
              onPrimary: _controller.continueAfterChapterBreak,
              secondaryLabel: 'Finish for now',
              onSecondary: _exit,
            ),
          if (state.finished)
            _ReaderOverlay(
              theme: theme,
              eyebrow: 'The end',
              title: 'You finished ${state.book!.title}',
              message: 'Every word, one at a time. Well read.',
              primaryLabel: 'See your session',
              onPrimary: _exit,
            ),
        ],
      );
    });
  }
}

class _FadingControls extends StatelessWidget {
  const _FadingControls({required this.visible, required this.onInteract, required this.child});

  final bool visible;
  final VoidCallback onInteract;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MotionConstants.medium,
      child: visible
          ? Listener(key: const ValueKey('controls'), onPointerDown: (_) => onInteract(), child: child)
          : const SizedBox.shrink(key: ValueKey('hidden')),
    );
  }
}

class _Hud extends StatelessWidget {
  const _Hud({required this.hud, required this.theme});

  final ValueNotifier<String?> hud;
  final ReaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: hud,
      builder: (context, message, _) => AnimatedOpacity(
        opacity: message == null ? 0 : 1,
        duration: MotionConstants.fast,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: theme.guide, borderRadius: BorderRadius.circular(20)),
            child: Text(
              message ?? '',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: theme.chrome),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderOverlay extends StatelessWidget {
  const _ReaderOverlay({
    required this.theme,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final ReaderTheme theme;
  final String eyebrow;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Positioned.fill(
      child: ColoredBox(
        color: theme.background.withValues(alpha: 0.94),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(eyebrow.toUpperCase(), style: text.labelSmall?.copyWith(color: theme.focal)),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium?.copyWith(color: theme.word),
                ),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center, style: text.bodyLarge?.copyWith(color: theme.chromeMuted)),
                const SizedBox(height: 32),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    children: [
                      PrimaryButton(label: primaryLabel, onPressed: onPrimary),
                      if (secondaryLabel != null) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: onSecondary,
                          child: Text(secondaryLabel!, style: TextStyle(color: theme.chromeMuted)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
