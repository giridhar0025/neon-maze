import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'game_screen.dart';
import 'route.dart';
import 'widgets.dart';

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: NebulaBackground(accent: AppColors.cyan, secondary: AppColors.violet),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Column(
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
                      Text('HOW TO PLAY', style: AppText.display(18, letterSpacing: 2.2)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    children: [
                      Center(
                        child: GlowMarble(size: 120, accent: AppColors.cyan, secondary: AppColors.mint),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Your phone is the maze.',
                        textAlign: TextAlign.center,
                        style: AppText.display(26, letterSpacing: -0.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tilt to roll the marble. The board tilts with you, gravity does the rest.',
                        textAlign: TextAlign.center,
                        style: AppText.body(14, height: 1.5),
                      ),
                      const SizedBox(height: 26),
                      const _Step(
                        number: '01',
                        icon: Icons.screen_rotation_alt_rounded,
                        title: 'Calibrate once',
                        body:
                            'Hold your phone flat, face up, and tap Calibrate. This becomes your level. Do it again whenever you change posture.',
                        color: AppColors.cyan,
                      ),
                      const _Step(
                        number: '02',
                        icon: Icons.open_with_rounded,
                        title: 'Tilt to travel',
                        body:
                            'Small tilts give fine control. Big tilts build speed. Drag on the board at any time to switch to touch steering.',
                        color: AppColors.magenta,
                      ),
                      const _Step(
                        number: '03',
                        icon: Icons.blur_on_rounded,
                        title: 'Read the board',
                        body:
                            'Collect every energy orb to unlock the exit. Avoid holes. Gates pulse: bright is solid, dark is passable. Belts push; bumpers redirect; magnets pull or shove.',
                        color: AppColors.gold,
                      ),
                      const _Step(
                        number: '04',
                        icon: Icons.bolt_rounded,
                        title: 'Open new paths',
                        body:
                            'Flow panels only pass with the arrows. Cracked walls shatter on a hard hit and open a shortcut. Both reward planning the entry line, not just speed.',
                        color: AppColors.fracture,
                      ),
                      const _Step(
                        number: '05',
                        icon: Icons.settings_input_component_rounded,
                        title: 'Work the machinery',
                        body:
                            'Conveyor belts push you along, sliding walls sweep a gap across the corridor, and magnets pull or shove. Read the motion first, then choose your line.',
                        color: AppColors.cyan,
                      ),
                      const _Step(
                        number: '06',
                        icon: Icons.timer_outlined,
                        title: 'Chase three stars',
                        body:
                            'Each level has a par time. Beat it for three stars, then push for a faster personal best.',
                        color: AppColors.mint,
                      ),
                      const SizedBox(height: 12),
                      GlassCard(
                        accent: AppColors.danger,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.vibration_rounded, color: AppColors.danger, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No gyroscope? No problem. Drag anywhere on the maze, or use arrow keys on desktop. '
                                'You can tune sensitivity and dead zone any time from the pause menu.',
                                style: AppText.body(13, height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      NeonButton(
                        label: 'START PLAYING',
                        icon: Icons.play_arrow_rounded,
                        onTap: () => Navigator.of(context).pushReplacement(
                          neonRoute(GameScreen(levelId: store.continueLevelId, store: store)),
                        ),
                      ),
                    ],
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
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final String number;
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassCard(
        accent: color,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(number, style: AppText.body(10, weight: 700, color: color, letterSpacing: 1.4)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(title, style: AppText.display(16, weight: 600, letterSpacing: 0.1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(body, style: AppText.body(12.5, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
