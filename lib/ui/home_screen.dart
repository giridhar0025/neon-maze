import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/audio.dart';
import '../core/haptics.dart';
import '../data/store.dart';
import '../game/daily.dart';
import '../game/levels.dart';
import '../theme/palette.dart';
import '../theme/skins.dart';
import '../theme/theme.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'level_select_screen.dart';
import 'route.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    unawaited(Music.instance.play(MusicTrack.menu));
    unawaited(store.rollDailyIfNeeded());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final continueLevel = store.continueLevelId;
        final chapter = continueLevel ~/ LevelCatalog.levelsPerChapter;
        final theme = ChapterTheme.of(chapter);
        final dailySpec = DailyChallenge.specFor(DateTime.now());
        final dailyTheme = ChapterTheme.of(dailySpec.chapter);

        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: NebulaBackground()),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    final hPad = math.max(
                      22.0,
                      (constraints.maxWidth - 460) / 2,
                    );
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
                                _TopBar(
                                  sparks: store.sparks,
                                  onSettings: () => _openSettings(context),
                                ),
                                const Spacer(),
                                Center(
                                  child: GlowMarble(
                                    size: math.min(
                                      146,
                                      math.max(92, height * 0.17),
                                    ),
                                    accent: theme.a,
                                    secondary: theme.b,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const _Wordmark(),
                                const SizedBox(height: 8),
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
                                const SizedBox(height: 14),
                                Center(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      Pill(
                                        label:
                                            '${store.totalStars} / ${LevelCatalog.total * 3} stars',
                                        icon: Icons.star_rounded,
                                        color: AppColors.gold,
                                      ),
                                      Pill(
                                        label: '${store.clearedCount} cleared',
                                        icon: Icons.flag_rounded,
                                        color: AppColors.mint,
                                      ),
                                      if (AppStore.unlockAllLevels)
                                        const Pill(
                                          label: 'ALL LEVELS OPEN',
                                          icon: Icons.lock_open_rounded,
                                          color: AppColors.mint,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _DailyCard(
                                  store: store,
                                  spec: dailySpec,
                                  theme: dailyTheme,
                                  onTap: () => _openDaily(dailySpec),
                                ),
                                const Spacer(),
                                NeonButton(
                                  label:
                                      'CONTINUE  ·  ${'${continueLevel + 1}'.padLeft(2, '0')}',
                                  icon: Icons.play_arrow_rounded,
                                  accent: theme.a,
                                  onTap: () =>
                                      _openLevel(context, continueLevel),
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
                                        label: 'MISSIONS',
                                        icon:
                                            Icons.assignment_turned_in_rounded,
                                        primary: false,
                                        compact: true,
                                        onTap: () => _openMissions(context),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: NeonButton(
                                        label: 'MARBLE LAB',
                                        icon: Icons.palette_rounded,
                                        primary: false,
                                        compact: true,
                                        onTap: () => _openLab(context),
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
                                const SizedBox(height: 16),
                                Center(
                                  child: Text(
                                    'Neon Maze  ·  offline & ad-free',
                                    style: AppText.body(
                                      11,
                                      color: AppColors.inkFaint.withValues(
                                        alpha: 0.8,
                                      ),
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
    await Navigator.of(
      context,
    ).push(neonRoute(GameScreen(levelId: id, store: store)));
  }

  Future<void> _openDaily(LevelSpec spec) async {
    await Navigator.of(
      context,
    ).push(neonRoute(GameScreen(levelId: 0, store: store, specOverride: spec)));
    if (mounted) setState(() {});
  }

  Future<void> _openLevels(BuildContext context) async {
    await Navigator.of(
      context,
    ).push(neonRoute(LevelSelectScreen(store: store)));
  }

  Future<void> _openSettings(BuildContext context) async {
    await Navigator.of(context).push(neonRoute(SettingsScreen(store: store)));
  }

  Future<void> _openHowTo(BuildContext context) async {
    await Navigator.of(context).push(neonRoute(HowToPlayScreen(store: store)));
  }

  Future<void> _openMissions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MissionsSheet(store: store),
    );
  }

  Future<void> _openLab(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MarbleLabSheet(store: store),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.store,
    required this.spec,
    required this.theme,
    required this.onTap,
  });

  final AppStore store;
  final LevelSpec spec;
  final ChapterTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = store.dailyCompleted;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.a.withValues(alpha: 0.16),
                theme.b.withValues(alpha: 0.05),
              ],
            ),
            border: Border.all(color: theme.a.withValues(alpha: 0.40)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: theme.a.withValues(alpha: 0.14),
                  border: Border.all(color: theme.a.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.bolt_rounded,
                  color: theme.a,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DAILY CHALLENGE',
                          style: AppText.body(
                            9.5,
                            weight: 700,
                            color: theme.a,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (store.dailyStreak > 0) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 12,
                            color: AppColors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${store.dailyStreak}',
                            style: AppText.body(
                              9.5,
                              weight: 700,
                              color: AppColors.amber,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      done
                          ? 'Cleared today  ·  best ${formatDuration(store.dailyBestMs)}s'
                          : '${theme.name}  ·  ${spec.actName.toLowerCase()} remix',
                      style: AppText.body(11.5, color: AppColors.inkDim),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    done ? 'DONE' : '+${AppStore.dailyRewardSparks}',
                    style: AppText.display(
                      15,
                      color: done ? AppColors.mint : AppColors.gold,
                    ),
                  ),
                  Text(
                    done ? '' : 'sparks',
                    style: AppText.body(8.5, color: AppColors.inkFaint),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionsSheet extends StatelessWidget {
  const _MissionsSheet({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'DAILY MISSIONS',
                        style: AppText.display(22, letterSpacing: 1.2),
                      ),
                      const Spacer(),
                      Pill(
                        label: '${store.sparks}',
                        icon: Icons.bolt_rounded,
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Three goals, reset at midnight. Claim sparks, then spend them in the Marble Lab.',
                    style: AppText.body(
                      12,
                      color: AppColors.inkDim,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final mission in store.dailyMissions) ...[
                    _MissionRow(
                      mission: mission,
                      onClaim: () async {
                        final reward = await store.claimMission(mission.id);
                        if (reward > 0 && context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  '+$reward sparks claimed',
                                  style: AppText.body(
                                    12.5,
                                    color: AppColors.ink,
                                  ),
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.panelHi,
                                duration: const Duration(milliseconds: 1400),
                              ),
                            );
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission, required this.onClaim});

  final DailyMission mission;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final canClaim = mission.complete && !mission.claimed;
    final color = mission.claimed ? AppColors.inkFaint : AppColors.cyan;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.035),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mission.title,
                  style: AppText.body(13, weight: 600, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${mission.progress.clamp(0, mission.target)}/${mission.target}',
                style: AppText.body(11, weight: 600, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: mission.fraction,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 13, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(
                '${mission.reward} sparks',
                style: AppText.body(10.5, color: AppColors.inkFaint),
              ),
              const Spacer(),
              if (mission.claimed)
                Text(
                  'CLAIMED',
                  style: AppText.body(
                    9.5,
                    weight: 700,
                    color: AppColors.inkFaint,
                    letterSpacing: 1.2,
                  ),
                )
              else if (canClaim)
                SizedBox(
                  height: 30,
                  child: FilledButton(
                    onPressed: onClaim,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.cyan,
                      foregroundColor: AppColors.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'CLAIM',
                      style: AppText.body(
                        9.5,
                        weight: 700,
                        color: AppColors.bg,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  'IN PROGRESS',
                  style: AppText.body(
                    9.5,
                    weight: 600,
                    color: AppColors.inkFaint,
                    letterSpacing: 1.0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarbleLabSheet extends StatelessWidget {
  const _MarbleLabSheet({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'MARBLE LAB',
                        style: AppText.display(22, letterSpacing: 1.2),
                      ),
                      const Spacer(),
                      Pill(
                        label: '${store.sparks}',
                        icon: Icons.bolt_rounded,
                        color: AppColors.gold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cosmetic glass finishes. Earn sparks from daily challenges and missions.',
                    style: AppText.body(
                      12,
                      color: AppColors.inkDim,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < marbleSkins.length; i++) ...[
                    _SkinRow(
                      index: i,
                      skin: marbleSkins[i],
                      owned: store.ownsSkin(i),
                      equipped: store.settings.marbleSkin == i,
                      onTap: () async {
                        if (store.ownsSkin(i)) {
                          await store.selectSkin(i);
                        } else {
                          final ok = await store.buySkin(i);
                          if (!ok && context.mounted) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Need ${marbleSkins[i].price - store.sparks} more sparks',
                                    style: AppText.body(
                                      12.5,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.panelHi,
                                  duration: const Duration(milliseconds: 1500),
                                ),
                              );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 9),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkinRow extends StatelessWidget {
  const _SkinRow({
    required this.index,
    required this.skin,
    required this.owned,
    required this.equipped,
    required this.onTap,
  });

  final int index;
  final MarbleSkin skin;
  final bool owned;
  final bool equipped;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: equipped
                ? skin.core.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.035),
            border: Border.all(
              color: equipped
                  ? skin.core.withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              _SkinOrb(skin: skin),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skin.name,
                      style: AppText.display(
                        15,
                        weight: 600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      skin.subtitle,
                      style: AppText.body(11, color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (equipped)
                Text(
                  'EQUIPPED',
                  style: AppText.body(
                    9.5,
                    weight: 700,
                    color: skin.core,
                    letterSpacing: 1.0,
                  ),
                )
              else if (owned)
                Text(
                  'TAP TO EQUIP',
                  style: AppText.body(
                    9.5,
                    weight: 700,
                    color: AppColors.inkDim,
                    letterSpacing: 0.8,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 13, color: AppColors.gold),
                    const SizedBox(width: 3),
                    Text(
                      '${skin.price}',
                      style: AppText.body(
                        12,
                        weight: 700,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinOrb extends StatelessWidget {
  const _SkinOrb({required this.skin});

  final MarbleSkin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.35),
          radius: 0.9,
          colors: [
            Colors.white,
            Color.lerp(Colors.white, skin.core, 0.55)!,
            Color.lerp(skin.core, Colors.black, 0.4)!,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: skin.glow.withValues(alpha: 0.35),
            blurRadius: 16,
            spreadRadius: -4,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.sparks, required this.onSettings});

  final int sparks;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const NeonLogoMark(size: 38, radius: 12),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NEON MAZE',
              style: AppText.display(14, weight: 700, letterSpacing: 1.6),
            ),
            Text(
              'tilt lab',
              style: AppText.body(
                10,
                color: AppColors.inkFaint,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
        const Spacer(),
        Pill(label: '$sparks', icon: Icons.bolt_rounded, color: AppColors.gold),
        const SizedBox(width: 8),
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
        colors: [
          Colors.white,
          AppColors.cyan,
          AppColors.violet,
          AppColors.magenta,
        ],
        stops: [0.0, 0.42, 0.72, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Column(
        children: [
          Text(
            'NEON',
            textAlign: TextAlign.center,
            style: AppText.display(52, letterSpacing: 8, height: 0.95),
          ),
          Text(
            'MAZE',
            textAlign: TextAlign.center,
            style: AppText.display(52, letterSpacing: 8, height: 0.95),
          ),
        ],
      ),
    );
  }
}
