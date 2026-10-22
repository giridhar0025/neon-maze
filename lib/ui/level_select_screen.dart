import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/haptics.dart';
import '../data/store.dart';
import '../game/levels.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'game_screen.dart';
import 'route.dart';
import 'widgets.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  int _chapter = 0;

  @override
  void initState() {
    super.initState();
    final current = widget.store.continueLevelId ~/ LevelCatalog.levelsPerChapter;
    _chapter = current.clamp(0, LevelCatalog.chapterCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final theme = ChapterTheme.of(_chapter);
        final levels = LevelCatalog.chapter(_chapter);
        final cleared = levels.where((l) => widget.store.starsFor(l.id) > 0).length;

        return Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: NebulaBackground(accent: theme.a, secondary: theme.b),
              ),
              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          const SizedBox(width: 2),
                          Text('CHAPTERS', style: AppText.display(18, letterSpacing: 2.2)),
                          const Spacer(),
                          Pill(
                            label: '${widget.store.totalStars}',
                            icon: Icons.star_rounded,
                            color: AppColors.gold,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: LevelCatalog.chapterCount,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final t = ChapterTheme.of(index);
                          final selected = index == _chapter;
                          final chapterStars = LevelCatalog.chapter(index)
                              .where((l) => widget.store.starsFor(l.id) > 0)
                              .length;
                          return _ChapterCard(
                            theme: t,
                            index: index,
                            selected: selected,
                            cleared: chapterStars,
                            onTap: () => setState(() => _chapter = index),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(theme.name, style: AppText.display(26, letterSpacing: 0.2)),
                                const SizedBox(height: 2),
                                Text(theme.subtitle, style: AppText.body(13)),
                              ],
                            ),
                          ),
                          Text(
                            '$cleared / ${levels.length}',
                            style: AppText.body(12, weight: 600, color: theme.a),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: cleared / levels.length,
                          minHeight: 4,
                          backgroundColor: Colors.white.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation(theme.a),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: levels.length,
                              itemBuilder: (context, index) {
                                final level = levels[index];
                                return _LevelTile(
                                  level: level,
                                  theme: theme,
                                  record: widget.store.recordFor(level.id),
                                  unlocked: widget.store.isUnlocked(level.id),
                                  onTap: widget.store.isUnlocked(level.id)
                                      ? () => _open(level.id)
                                      : null,
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            _ChapterTip(theme: theme, cleared: cleared, total: levels.length),
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
          ),
        );
      },
    );
  }

  Future<void> _open(int id) async {
    await Navigator.of(context).push(neonRoute(GameScreen(levelId: id, store: widget.store)));
    if (mounted) setState(() {});
  }
}

class _ChapterTip extends StatelessWidget {
  const _ChapterTip({required this.theme, required this.cleared, required this.total});

  final ChapterTheme theme;
  final int cleared;
  final int total;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      accent: theme.a,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, size: 16, color: theme.a),
              const SizedBox(width: 8),
              Text(
                'CHAPTER FOCUS',
                style: AppText.body(9.5, weight: 700, color: theme.a, letterSpacing: 1.6),
              ),
              const Spacer(),
              Pill(label: theme.mechanic, color: theme.a),
            ],
          ),
          const SizedBox(height: 10),
          Text(theme.tip, style: AppText.body(12.5, height: 1.5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : cleared / total,
                    minHeight: 3,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(theme.a),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('$cleared/$total cleared', style: AppText.body(10, color: AppColors.inkFaint)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  const _ChapterCard({
    required this.theme,
    required this.index,
    required this.selected,
    required this.cleared,
    required this.onTap,
  });

  final ChapterTheme theme;
  final int index;
  final bool selected;
  final int cleared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 142,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: selected
                ? [theme.a.withValues(alpha: 0.24), theme.b.withValues(alpha: 0.10)]
                : [Colors.white.withValues(alpha: 0.045), Colors.white.withValues(alpha: 0.02)],
          ),
          border: Border.all(
            color: selected ? theme.a.withValues(alpha: 0.75) : Colors.white.withValues(alpha: 0.07),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: theme.a.withValues(alpha: 0.22), blurRadius: 22, spreadRadius: -6)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '0${index + 1}',
              style: AppText.display(22, color: selected ? theme.a : AppColors.inkFaint),
            ),
            const Spacer(),
            Text(
              theme.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(11.5, weight: 600, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 11, color: selected ? theme.a : AppColors.inkFaint),
                const SizedBox(width: 4),
                Text('$cleared/10', style: AppText.body(10, color: AppColors.inkFaint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.theme,
    required this.record,
    required this.unlocked,
    required this.onTap,
  });

  final LevelSpec level;
  final ChapterTheme theme;
  final LevelRecord? record;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stars = record?.stars ?? 0;
    final played = record != null && record!.bestMs > 0;
    return Opacity(
      opacity: unlocked ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: played
                    ? [theme.a.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.03)]
                    : [Colors.white.withValues(alpha: 0.055), Colors.white.withValues(alpha: 0.02)],
              ),
              border: Border.all(
                color: stars > 0 ? theme.a.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!unlocked)
                    const Icon(Icons.lock_rounded, size: 18, color: AppColors.inkFaint)
                  else
                    Text(
                      level.number,
                      style: AppText.display(21, color: AppColors.ink),
                    ),
                  const SizedBox(height: 4),
                  StarRow(stars: stars, size: 12, gap: 1, dim: true),
                  const SizedBox(height: 4),
                  Text(
                    played ? formatBest(record!.bestMs) : (unlocked ? '—' : 'locked'),
                    style: AppText.body(9, color: AppColors.inkFaint),
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
