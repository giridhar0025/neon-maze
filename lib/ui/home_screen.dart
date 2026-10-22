import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../game/levels.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'level_select_screen.dart';
import 'route.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final continueLevel = store.continueLevelId;
        final chapter = continueLevel ~/ LevelCatalog.levelsPerChapter;
        final theme = ChapterTheme.of(chapter);

        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: NebulaBackground()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final hPad = math.max(22.0, (constraints.maxWidth - 460) / 2);
                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: height),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _TopBar(onSettings: () => _openSettings(context)),
                                    const Spacer(),
                                    Center(
                                      child: GlowMarble(
                                        size: math.min(158, math.max(96, height * 0.19)),
                                        accent: theme.a,
                                        secondary: theme.b,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const _Wordmark(),
                                    const SizedBox(height: 10),
                                    Center(
                                      child: Text(
                                        'TILT  ·  ROLL  ·  ESCAPE',
                                        style: AppText.body(
                                          11.5,
                                          weight: 600,
                                          color: AppColors.inkFaint,
                                          letterSpacing: 3.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Center(
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: [
                                          Pill(
                                            label: '${store.totalStars} / ${LevelCatalog.total * 3} stars',
                                            icon: Icons.star_rounded,
                                            color: AppColors.gold,
                                          ),
                                          Pill(
                                            label: '${store.clearedCount} cleared',
                                            icon: Icons.flag_rounded,
                                            color: AppColors.mint,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    NeonButton(
                                      label: 'CONTINUE  ·  ${'${continueLevel + 1}'.padLeft(2, '0')}',
                                      icon: Icons.play_arrow_rounded,
                                      accent: theme.a,
                                      onTap: () => _openLevel(context, continueLevel),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: NeonButton(
                                            label: 'CHAPTERS',
                                            icon: Icons.grid_view_rounded,
                                            primary: false,
                                            compact: true,
                                            onTap: () => _openLevels(context),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: NeonButton(
                                            label: 'HOW TO PLAY',
                                            icon: Icons.help_outline_rounded,
                                            primary: false,
                                            compact: true,
                                            onTap: () => _openHowTo(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Center(
                                      child: Text(
                                        'Neon Maze  ·  v1.0  ·  offline & ad-free',
                                        style: AppText.body(
                                          11,
                                          color: AppColors.inkFaint.withValues(alpha: 0.8),
                                        ),
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
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openLevel(BuildContext context, int id) async {
    await Navigator.of(context).push(neonRoute(GameScreen(levelId: id, store: store)));
  }

  Future<void> _openLevels(BuildContext context) async {
    await Navigator.of(context).push(neonRoute(LevelSelectScreen(store: store)));
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(neonRoute(SettingsScreen(store: store)));
  }

  Future<void> _openHowTo(BuildContext context) async {
    await Navigator.of(context).push(neonRoute(HowToPlayScreen(store: store)));
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.cyan, AppColors.magenta],
            ),
          ),
          child: const Icon(Icons.blur_circular_rounded, color: AppColors.bg, size: 22),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NEON MAZE', style: AppText.display(14, weight: 700, letterSpacing: 1.6)),
            Text('tilt lab', style: AppText.body(10, color: AppColors.inkFaint, letterSpacing: 1.4)),
          ],
        ),
        const Spacer(),
        IconButton(
          onPressed: onSettings,
          tooltip: 'Settings',
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.04),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            minimumSize: const Size(44, 44),
          ),
          icon: const Icon(Icons.tune_rounded, size: 20),
        ),
      ],
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, AppColors.cyan, AppColors.violet, AppColors.magenta],
        stops: [0.0, 0.42, 0.72, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Column(
        children: [
          Text(
            'NEON',
            textAlign: TextAlign.center,
            style: AppText.display(56, letterSpacing: 8, height: 0.95),
          ),
          Text(
            'MAZE',
            textAlign: TextAlign.center,
            style: AppText.display(56, letterSpacing: 8, height: 0.95),
          ),
        ],
      ),
    );
  }
}
