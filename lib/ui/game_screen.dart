import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/audio.dart';
import '../core/haptics.dart';
import '../data/store.dart';
import '../game/levels.dart';
import '../game/particles.dart';
import '../game/simulation.dart';
import '../game/tilt.dart';
import '../render/scene_painter.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'route.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

enum GamePhase { onboarding, countdown, playing, paused, won, fallen }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.levelId, required this.store});

  final int levelId;
  final AppStore store;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameResult {
  const _GameResult({
    required this.timeMs,
    required this.stars,
    required this.score,
    required this.isBest,
  });

  final int timeMs;
  final int stars;
  final int score;
  final bool isBest;
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final LevelSpec _spec = LevelCatalog.byId(widget.levelId);
  late final LevelRuntime _level = LevelRuntime.build(_spec);
  late final ChapterTheme _theme = ChapterTheme.of(_spec.chapter);
  late final Simulation _sim = Simulation(_level);
  late final TiltController _tilt = TiltController(widget.store.settings)..start();
  late final ParticleField _particles = ParticleField();
  late final BoardRenderer _renderer = BoardRenderer();
  late final Sfx _sfx = Sfx(enabled: widget.store.settings.sound);
  late final Haptics _haptics = Haptics(enabled: widget.store.settings.haptics);

  late final Ticker _ticker;
  final ValueNotifier<int> _repaint = ValueNotifier(0);
  final ValueNotifier<int> _hud = ValueNotifier(0);
  final ValueNotifier<int> _countdown = ValueNotifier(3);
  final ValueNotifier<String?> _banner = ValueNotifier<String?>(null);
  Timer? _bannerTimer;

  GamePhase _phase = GamePhase.onboarding;
  Duration _lastTick = Duration.zero;
  double _elapsedMs = 0;
  double _countdownLeft = 3.2;
  double _fallLeft = 0;
  _GameResult? _result;
  int _lastHudBucket = -1;
  Size? _builtSize;
  int? _builtLevel;
  Offset _drag = Offset.zero;
  final Set<LogicalKeyboardKey> _keys = <LogicalKeyboardKey>{};
  bool _attemptRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_sfx.init());
    unawaited(widget.store.setLastLevel(_spec.id));
    _phase = widget.store.tutorialSeen ? GamePhase.countdown : GamePhase.onboarding;
    _ticker = createTicker(_onTick)..start();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _tilt.dispose();
    _repaint.dispose();
    _hud.dispose();
    _countdown.dispose();
    _renderer.dispose();
    _sfx.dispose();
    _bannerTimer?.cancel();
    _banner.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (_phase == GamePhase.playing) {
        setState(() => _phase = GamePhase.paused);
      }
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastTick = elapsed;

    // Paused / onboarding screens are static: skip painting to save battery.
    if (_phase == GamePhase.paused || _phase == GamePhase.onboarding) {
      return;
    }

    _sim.visualTime += dt;

    switch (_phase) {
      case GamePhase.countdown:
        _countdownLeft -= dt;
        final value = _countdownLeft.ceil().clamp(0, 3);
        if (_countdown.value != value) _countdown.value = value;
        if (_countdownLeft <= 0) {
          setState(() => _phase = GamePhase.playing);
          if (_level.orbs.isNotEmpty) {
            _showBanner('COLLECT ALL ORBS TO UNLOCK THE EXIT');
          }
        }
      case GamePhase.playing:
        _updateKeyboard();
        _sim.step(dt, _tilt.value);
        if (_tilt.sensorAvailable &&
            widget.store.settings.autoCalibrate &&
            _sim.isResting &&
            _tilt.value.distance < 0.05) {
          _tilt.autoZero(dt * 0.10);
        }
        _elapsedMs += dt * 1000;
        _particles.update(dt);
        _consumeEvents();
        _pumpHud();
      case GamePhase.fallen:
        _fallLeft -= dt;
        _particles.update(dt);
        if (_fallLeft <= 0) _respawn();
      case GamePhase.won:
      case GamePhase.paused:
      case GamePhase.onboarding:
        _particles.update(dt);
    }

    _repaint.value++;
  }

  void _pumpHud() {
    final bucket = (_elapsedMs / 100).floor();
    if (bucket != _lastHudBucket) {
      _lastHudBucket = bucket;
      _hud.value++;
    }
  }

  void _updateKeyboard() {
    if (_keys.isEmpty) return;
    var x = 0.0;
    var y = 0.0;
    if (_keys.contains(LogicalKeyboardKey.arrowLeft) || _keys.contains(LogicalKeyboardKey.keyA)) {
      x -= 1;
    }
    if (_keys.contains(LogicalKeyboardKey.arrowRight) || _keys.contains(LogicalKeyboardKey.keyD)) {
      x += 1;
    }
    if (_keys.contains(LogicalKeyboardKey.arrowUp) || _keys.contains(LogicalKeyboardKey.keyW)) {
      y -= 1;
    }
    if (_keys.contains(LogicalKeyboardKey.arrowDown) || _keys.contains(LogicalKeyboardKey.keyS)) {
      y += 1;
    }
    final v = Offset(x, y);
    _tilt.feedFallback(v.distance == 0 ? Offset.zero : v / v.distance);
  }

  void _consumeEvents() {
    for (final event in _sim.drainEvents()) {
      switch (event.type) {
        case SimEventType.breakWall:
          _haptics.bump(event.strength);
          _sfx.play(SfxNames.bump, volume: 0.65);
          _particles.burst(event.position, AppColors.amber, count: 18, speed: 2.8, streak: true);
          _particles.burst(event.position, _theme.b, count: 10, speed: 1.6);
        case SimEventType.orb:
          _haptics.orb();
          _sfx.play(SfxNames.orb);
          _particles.burst(event.position, AppColors.gold, count: 16, speed: 2.4);
          _hud.value++;
          if (_sim.allOrbsCollected) {
            _sfx.play(SfxNames.star, volume: 0.4);
            _particles.burst(_level.exit, AppColors.mint, count: 20, speed: 2.0);
            _showBanner('EXIT OPEN', accent: AppColors.mint);
          }
        case SimEventType.portal:
          _haptics.portal();
          _sfx.play(SfxNames.tap, volume: 0.5);
          _particles.burst(event.position, _theme.b, count: 14, speed: 2.0);
          _particles.burst(_sim.ball, _theme.a, count: 10, speed: 1.6);
        case SimEventType.bumper:
          _haptics.bump(3.0);
          _sfx.play(SfxNames.bump, volume: 0.5);
          _particles.burst(event.position, _theme.b, count: 10, speed: 2.6, streak: true);
        case SimEventType.fall:
          _startFall();
        case SimEventType.win:
          _completeLevel();
      }
    }
  }

  void _startFall() {
    if (_phase != GamePhase.playing) return;
    _haptics.fall();
    _sfx.play(SfxNames.fall, volume: 0.7);
    _particles.burst(_sim.ball, AppColors.danger, count: 26, speed: 3.0, streak: true);
    if (!_attemptRecorded) {
      _attemptRecorded = true;
      unawaited(widget.store.recordAttempt(_spec.id));
    }
    setState(() {
      _phase = GamePhase.fallen;
      _fallLeft = 1.05;
    });
  }

  void _respawn() {
    _sim.reset();
    _particles.clear();
    _countdownLeft = 1.6;
    _countdown.value = 2;
    setState(() => _phase = GamePhase.countdown);
  }

  void _completeLevel() {
    if (_phase != GamePhase.playing) return;
    final timeMs = _elapsedMs.round();
    final stars = _spec.starsFor(timeMs);
    final score = _sim.score(timeMs, widget.store.settings.scoreMultiplier);
    final previousBest = widget.store.bestMsFor(_spec.id);
    final isBest = previousBest == 0 || timeMs < previousBest;
    _result = _GameResult(timeMs: timeMs, stars: stars, score: score, isBest: isBest);
    _haptics.win();
    _sfx.play(SfxNames.clear, volume: 0.8);
    _particles.burst(_level.exit, AppColors.mint, count: 34, speed: 3.2);
    _particles.burst(_sim.ball, _theme.a, count: 22, speed: 2.6);
    unawaited(widget.store.recordWin(_spec.id, stars, timeMs));
    unawaited(widget.store.setLastLevel(
      (_spec.id + 1).clamp(0, LevelCatalog.total - 1),
    ));
    setState(() => _phase = GamePhase.won);
  }

  void _restart() {
    _sim.reset();
    _particles.clear();
    _elapsedMs = 0;
    _result = null;
    _attemptRecorded = false;
    _countdownLeft = 3.2;
    _countdown.value = 3;
    _hud.value++;
    setState(() => _phase = GamePhase.countdown);
  }

  void _startFromOnboarding() {
    final zero = _tilt.calibrate();
    unawaited(widget.store.updateSettings(
      widget.store.settings.copyWith(calX: zero.dx, calY: zero.dy),
    ));
    unawaited(widget.store.markTutorialSeen());
    _countdownLeft = 3.2;
    _countdown.value = 3;
    setState(() => _phase = GamePhase.countdown);
  }

  void _startWithDrag() {
    _tilt.setTouchMode(true);
    _tilt.feedFallback(Offset.zero);
    unawaited(widget.store.markTutorialSeen());
    _countdownLeft = 3.2;
    _countdown.value = 3;
    setState(() => _phase = GamePhase.countdown);
  }

  void _recalibrate() {
    if (!_tilt.sensorAvailable) {
      _snack('Motion sensor not ready yet.');
      return;
    }
    final zero = _tilt.calibrate();
    unawaited(widget.store.updateSettings(
      widget.store.settings.copyWith(calX: zero.dx, calY: zero.dy),
    ));
    _snack('Recalibrated. Hold the phone this way while you play.');
  }

  void _togglePause() {
    if (_phase == GamePhase.playing) {
      setState(() => _phase = GamePhase.paused);
    } else if (_phase == GamePhase.paused) {
      setState(() => _phase = GamePhase.playing);
    }
  }

  void _toggleTouchMode() {
    final next = !_tilt.touchMode;
    _tilt.setTouchMode(next);
    _tilt.feedFallback(Offset.zero);
    _snack(next ? 'Drag anywhere on the board to steer.' : 'Tilt steering enabled.');
    setState(() {});
  }

  void _showBanner(String message, {Color? accent}) {
    _banner.value = message;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) _banner.value = null;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: AppText.body(12.5, color: AppColors.ink)),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.panelHi,
          duration: const Duration(milliseconds: 1600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(neonRoute(SettingsScreen(store: widget.store)));
    if (!mounted) return;
    _syncSettings();
  }

  void _syncSettings() {
    _tilt.applySettings(widget.store.settings);
    _sfx.enabled = widget.store.settings.sound;
    _haptics.enabled = widget.store.settings.haptics;
    setState(() {});
  }

  void _goToChapters() {
    Navigator.of(context).pushAndRemoveUntil(
      neonRoute(LevelSelectScreen(store: widget.store)),
      (route) => route.isFirst,
    );
  }

  void _nextLevel() {
    final next = _spec.id + 1;
    if (next >= LevelCatalog.total) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      neonRoute(GameScreen(levelId: next, store: widget.store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.store.settings;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          final key = event.logicalKey;
          if (event is KeyDownEvent) {
            _keys.add(key);
          } else if (event is KeyUpEvent) {
            _keys.remove(key);
            if (_keys.isEmpty) _tilt.feedFallback(Offset.zero);
          }
          return KeyEventResult.ignored;
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            final dpr = MediaQuery.devicePixelRatioOf(context);
            if (_builtSize != size || _builtLevel != _spec.id) {
              _builtSize = size;
              _builtLevel = _spec.id;
              _renderer.build(
                level: _level,
                size: size,
                dpr: dpr,
                theme: _theme,
                colorblind: settings.colorblind,
              );
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _drag = Offset.zero,
                  onPanUpdate: (details) {
                    if (!_tilt.touchMode && _tilt.sensorAvailable) return;
                    _drag += details.delta / 110.0;
                    final m = _drag.distance;
                    if (m > 1) _drag = _drag / m;
                    _tilt.feedFallback(_drag);
                  },
                  onPanEnd: (_) {
                    _drag = Offset.zero;
                    _tilt.feedFallback(Offset.zero);
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: ScenePainter(
                        sim: _sim,
                        level: _level,
                        theme: _theme,
                        renderer: _renderer,
                        particles: _particles,
                        settings: settings,
                        tilt: _tilt,
                        repaint: _repaint,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                _buildHud(settings),
                _buildBanner(),
                _buildOverlays(settings),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHud(GameSettings settings) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        child: Column(
          children: [
            Row(
              children: [
                // Default: orb count left, pause right. Left-handed swaps them
                // so the pause control sits under the left thumb.
                if (settings.leftHanded) _pauseButton() else _orbChip(),
                const Spacer(),
                ValueListenableBuilder<int>(
                  valueListenable: _hud,
                  builder: (context, _, _) => _TimerChip(
                    milliseconds: _elapsedMs.round(),
                    parMs: _spec.parMs,
                    accent: _theme.a,
                  ),
                ),
                const Spacer(),
                if (settings.leftHanded) _orbChip() else _pauseButton(),
              ],
            ),
            const Spacer(),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _ModeChip(
                  touchMode: _tilt.touchMode || !_tilt.sensorAvailable,
                  onTap: _toggleTouchMode,
                ),
                _MechanicChip(spec: _spec, accent: _theme.a),
                _InfoChip(label: 'PAR ${formatDuration(_spec.parMs)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _orbChip() {
    return ValueListenableBuilder<int>(
      valueListenable: _hud,
      builder: (context, _, _) => _OrbChip(
        collected: _sim.collected.length,
        total: _level.orbs.length,
        accent: AppColors.gold,
      ),
    );
  }

  Widget _pauseButton() {
    return _GlassIconButton(
      icon: _phase == GamePhase.paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
      onTap: _phase == GamePhase.won ? null : _togglePause,
    );
  }

  Widget _buildBanner() {
    return Positioned(
      top: 84,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<String?>(
        valueListenable: _banner,
        builder: (context, message, _) {
          return IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: message == null
                  ? const SizedBox.shrink()
                  : Center(
                      key: ValueKey(message),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.bg.withValues(alpha: 0.82),
                          border: Border.all(color: _theme.a.withValues(alpha: 0.35)),
                          boxShadow: [
                            BoxShadow(
                              color: _theme.a.withValues(alpha: 0.14),
                              blurRadius: 18,
                              spreadRadius: -4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: _theme.a),
                            const SizedBox(width: 8),
                            Text(
                              message,
                              style: AppText.body(
                                10.5,
                                weight: 700,
                                color: AppColors.ink,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverlays(GameSettings settings) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_phase == GamePhase.onboarding)
          _OnboardingOverlay(
            tilt: _tilt,
            settings: settings,
            onStart: _startFromOnboarding,
            onUseDrag: _startWithDrag,
          ),
        if (_phase == GamePhase.countdown)
          _CountdownOverlay(countdown: _countdown, accent: _theme.a, level: _spec),
        if (_phase == GamePhase.paused)
          _PauseOverlay(
            spec: _spec,
            theme: _theme,
            settings: settings,
            onResume: _togglePause,
            onRestart: _restart,
            onSettings: _openSettings,
            onRecalibrate: _recalibrate,
            onQuit: _goToChapters,
          ),
        if (_phase == GamePhase.fallen)
          _FallenOverlay(accent: _theme.a, onRetry: _respawn),
        if (_phase == GamePhase.won && _result != null)
          _WinOverlay(
            spec: _spec,
            theme: _theme,
            result: _result!,
            isChapterEnd: _spec.indexInChapter == LevelCatalog.levelsPerChapter - 1,
            onNext: _nextLevel,
            onReplay: _restart,
            onMap: _goToChapters,
          ),
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.bg.withValues(alpha: 0.55),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Icon(icon, size: 21, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.milliseconds, required this.parMs, required this.accent});

  final int milliseconds;
  final int parMs;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final overPar = milliseconds > parMs;
    final progress = (milliseconds / (parMs <= 0 ? 1 : parMs)).clamp(0.0, 1.0);
    final paceColor = overPar
        ? AppColors.danger
        : progress > 0.78
            ? AppColors.amber
            : accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.bg.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: paceColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatDuration(milliseconds),
                style: AppText.display(
                  17,
                  weight: 600,
                  letterSpacing: 0.4,
                  color: overPar ? AppColors.danger : AppColors.ink,
                ),
              ),
              const SizedBox(width: 3),
              Text('s', style: AppText.body(10, color: AppColors.inkFaint)),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 68,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation(paceColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbChip extends StatelessWidget {
  const _OrbChip({required this.collected, required this.total, required this.accent});

  final int collected;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const SizedBox(width: 44);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.bg.withValues(alpha: 0.55),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            collected >= total ? Icons.lock_open_rounded : Icons.blur_on_rounded,
            size: 15,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text('$collected/$total',
              style: AppText.body(13, weight: 600, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.touchMode, required this.onTap});

  final bool touchMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: AppColors.bg.withValues(alpha: 0.62),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                touchMode ? Icons.pan_tool_alt_rounded : Icons.screen_rotation_alt_rounded,
                size: 13,
                color: AppColors.inkDim,
              ),
              const SizedBox(width: 6),
              Text(
                touchMode ? 'DRAG' : 'TILT',
                style: AppText.body(10.5, weight: 700, color: AppColors.inkDim, letterSpacing: 1.0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MechanicChip extends StatelessWidget {
  const _MechanicChip({required this.spec, required this.accent});

  final LevelSpec spec;
  final Color accent;

  IconData get _icon => switch (spec.mechanicIcon) {
        'blackout' => Icons.visibility_off_rounded,
        'magnet' => Icons.radar_rounded,
        'slider' => Icons.swap_horiz_rounded,
        'conveyor' => Icons.fast_forward_rounded,
        'fracture' => Icons.bolt_rounded,
        'flow' => Icons.arrow_forward_rounded,
        'portal' => Icons.sync_alt_rounded,
        'gate' => Icons.power_settings_new_rounded,
        'surface' => Icons.ac_unit_rounded,
        'orb' => Icons.blur_on_rounded,
        _ => Icons.blur_circular_rounded,
      };

  String get _label => switch (spec.mechanicIcon) {
        'blackout' => 'BLACKOUT',
        'magnet' => 'MAGNETS',
        'slider' => 'SLIDER',
        'conveyor' => 'BELT',
        'fracture' => 'BREAKABLE',
        'flow' => 'FLOW',
        'portal' => 'PORTALS',
        'gate' => 'GATES',
        'surface' => spec.iceZones > 0 && spec.tarZones > 0
            ? 'ICE + TAR'
            : spec.iceZones > 0
                ? 'ICE'
                : 'TAR',
        'orb' => 'ORBS',
        _ => 'HOLES',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 13, color: accent),
          const SizedBox(width: 5),
          Text(
            _label,
            style: AppText.body(9.5, weight: 700, color: accent, letterSpacing: 0.9),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: AppColors.bg.withValues(alpha: 0.5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(
        label,
        style: AppText.body(9.5, weight: 600, color: AppColors.inkFaint, letterSpacing: 0.8),
      ),
    );
  }
}

class _CountdownOverlay extends StatelessWidget {
  const _CountdownOverlay({required this.countdown, required this.accent, required this.level});

  final ValueNotifier<int> countdown;
  final Color accent;
  final LevelSpec level;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<int>(
        valueListenable: countdown,
        builder: (context, value, _) {
          return Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween<double>(begin: 0.8, end: 1).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
                ),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Column(
                key: ValueKey(value),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value <= 0 ? 'GO' : '$value',
                    style: AppText.display(94, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LEVEL ${level.number}  ·  ${ChapterTheme.of(level.chapter).name}',
                    style: AppText.body(11, weight: 600, color: accent, letterSpacing: 2.4),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FallenOverlay extends StatelessWidget {
  const _FallenOverlay({required this.accent, required this.onRetry});

  final Color accent;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('DOWN THE HOLE', style: AppText.display(24, color: AppColors.danger, letterSpacing: 1.0)),
            const SizedBox(height: 8),
            Text('Resetting the marble…', style: AppText.body(12, color: AppColors.inkDim)),
          ],
        ),
      ),
    );
  }
}

class _OnboardingOverlay extends StatelessWidget {
  const _OnboardingOverlay({
    required this.tilt,
    required this.settings,
    required this.onStart,
    required this.onUseDrag,
  });

  final TiltController tilt;
  final GameSettings settings;
  final VoidCallback onStart;
  final VoidCallback onUseDrag;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('HOLD FLAT', style: AppText.display(34, letterSpacing: 4)),
                const SizedBox(height: 8),
                Text(
                  'Place your phone face-up, exactly how you plan to play.\nCenter the bubble, then capture your level.',
                  textAlign: TextAlign.center,
                  style: AppText.body(13, height: 1.5),
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: tilt,
                  builder: (context, _) => CustomPaint(
                    size: const Size(210, 210),
                    painter: SpiritLevelPainter(
                      tilt: tilt,
                      color: AppColors.cyan,
                      deadzone: settings.deadzone,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AnimatedBuilder(
                  animation: tilt,
                  builder: (context, _) {
                    final ready = tilt.sensorAvailable;
                    final failed = tilt.sensorFailed;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!ready)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              failed
                                  ? 'Motion sensor unavailable. Use drag steering on this device.'
                                  : 'Move the phone gently — waiting for motion data.',
                              textAlign: TextAlign.center,
                              style: AppText.body(11.5, color: AppColors.gold),
                            ),
                          ),
                        if (!ready && !failed)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.inkFaint,
                              ),
                            ),
                          ),
                        NeonButton(
                          label: ready
                              ? 'CALIBRATE & START'
                              : failed
                                  ? 'START WITH DRAG'
                                  : 'WAITING FOR SENSOR',
                          icon: ready
                              ? Icons.gps_fixed_rounded
                              : Icons.pan_tool_alt_rounded,
                          onTap: ready ? onStart : (failed ? onUseDrag : null),
                        ),
                        if (!failed) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: onUseDrag,
                            child: Text(
                              'Start with drag instead',
                              style: AppText.body(12, color: AppColors.inkFaint),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.spec,
    required this.theme,
    required this.settings,
    required this.onResume,
    required this.onRestart,
    required this.onSettings,
    required this.onRecalibrate,
    required this.onQuit,
  });

  final LevelSpec spec;
  final ChapterTheme theme;
  final GameSettings settings;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onSettings;
  final VoidCallback onRecalibrate;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        color: AppColors.bg.withValues(alpha: 0.55),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: GlassCard(
                accent: theme.a,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('PAUSED', style: AppText.display(28, letterSpacing: 3)),
                    const SizedBox(height: 6),
                    Text(
                      'Level ${spec.number}  ·  ${theme.name}',
                      style: AppText.body(12, color: theme.a, weight: 600, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final mechanic in spec.mechanics)
                          Pill(label: mechanic, color: theme.a),
                        Pill(
                          label: '${settings.preset.label} tilt',
                          color: AppColors.inkFaint,
                          icon: Icons.screen_rotation_alt_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    NeonButton(
                      label: 'RESUME',
                      icon: Icons.play_arrow_rounded,
                      accent: theme.a,
                      onTap: onResume,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: NeonButton(
                            label: 'RESTART',
                            icon: Icons.refresh_rounded,
                            primary: false,
                            compact: true,
                            onTap: onRestart,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: NeonButton(
                            label: 'SETTINGS',
                            icon: Icons.tune_rounded,
                            primary: false,
                            compact: true,
                            onTap: onSettings,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: onRecalibrate,
                      icon: const Icon(Icons.gps_fixed_rounded, size: 16, color: AppColors.cyan),
                      label: Text(
                        'Recalibrate tilt now',
                        style: AppText.body(12.5, color: AppColors.cyan),
                      ),
                    ),
                    TextButton(
                      onPressed: onQuit,
                      child: Text(
                        'Quit to chapters',
                        style: AppText.body(12.5, color: AppColors.inkFaint),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WinOverlay extends StatelessWidget {
  const _WinOverlay({
    required this.spec,
    required this.theme,
    required this.result,
    required this.isChapterEnd,
    required this.onNext,
    required this.onReplay,
    required this.onMap,
  });

  final LevelSpec spec;
  final ChapterTheme theme;
  final _GameResult result;
  final bool isChapterEnd;
  final VoidCallback onNext;
  final VoidCallback onReplay;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg.withValues(alpha: 0.72),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isChapterEnd
                        ? 'CHAPTER CLEAR'
                        : result.isBest
                            ? 'NEW BEST'
                            : 'ESCAPED',
                    style: AppText.display(15, color: theme.a, letterSpacing: 4),
                  ),
                  const SizedBox(height: 6),
                  Text('LEVEL ${spec.number}', style: AppText.display(46, letterSpacing: 2)),
                  if (isChapterEnd) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${theme.name}  ·  ${theme.subtitle}',
                      style: AppText.body(11, color: theme.a, weight: 600, letterSpacing: 1.2),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutBack,
                    builder: (context, value, _) {
                      return Transform.scale(
                        scale: 0.7 + value * 0.3,
                        child: StarRow(stars: result.stars, size: 46, gap: 8),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  GlassCard(
                    accent: theme.a,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat(label: 'TIME', value: '${formatDuration(result.timeMs)}s'),
                        _Stat(label: 'PAR', value: '${formatDuration(spec.parMs)}s'),
                        _Stat(label: 'SCORE', value: '${result.score}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  NeonButton(
                    label: spec.id + 1 >= LevelCatalog.total
                        ? 'FINISH'
                        : isChapterEnd
                            ? 'NEXT CHAPTER'
                            : 'NEXT LEVEL',
                    icon: Icons.arrow_forward_rounded,
                    accent: theme.a,
                    onTap: onNext,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: NeonButton(
                          label: 'REPLAY',
                          icon: Icons.refresh_rounded,
                          primary: false,
                          compact: true,
                          onTap: onReplay,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NeonButton(
                          label: 'CHAPTERS',
                          icon: Icons.grid_view_rounded,
                          primary: false,
                          compact: true,
                          onTap: onMap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: AppText.body(9, weight: 700, color: AppColors.inkFaint, letterSpacing: 1.4)),
        const SizedBox(height: 4),
        Text(value, style: AppText.display(18, weight: 600)),
      ],
    );
  }
}
