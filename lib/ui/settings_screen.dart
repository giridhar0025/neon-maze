import 'package:flutter/material.dart';

import '../data/store.dart';
import '../game/tilt.dart';
import '../render/scene_painter.dart';
import '../theme/palette.dart';
import '../theme/theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final settings = store.settings;
        return Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: NebulaBackground()),
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
                          Text('SETTINGS', style: AppText.display(18, letterSpacing: 2.2)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                        children: [
                          const SectionLabel('Feel'),
                          const SizedBox(height: 10),
                          GlassCard(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sensitivity', style: AppText.display(17, weight: 600)),
                                const SizedBox(height: 4),
                                Text(
                                  'Higher sensitivity reacts faster and earns a bigger score multiplier.',
                                  style: AppText.body(12, height: 1.4),
                                ),
                                const SizedBox(height: 12),
                                SegmentedButton<SensitivityPreset>(
                                  segments: [
                                    for (final preset in SensitivityPreset.values)
                                      ButtonSegment(
                                        value: preset,
                                        label: Text(
                                          preset.label,
                                          style: AppText.body(11.5, weight: 600),
                                        ),
                                      ),
                                  ],
                                  selected: {settings.preset},
                                  showSelectedIcon: false,
                                  style: ButtonStyle(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: WidgetStateProperty.resolveWith(
                                      (states) => states.contains(WidgetState.selected)
                                          ? AppColors.cyan.withValues(alpha: 0.20)
                                          : Colors.white.withValues(alpha: 0.03),
                                    ),
                                    foregroundColor: WidgetStateProperty.resolveWith(
                                      (states) => states.contains(WidgetState.selected)
                                          ? AppColors.cyan
                                          : AppColors.inkDim,
                                    ),
                                    side: WidgetStatePropertyAll(
                                      BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                  ),
                                  onSelectionChanged: (selection) => store.updateSettings(
                                    settings.copyWith(preset: selection.first),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _SliderTile(
                                  label: 'Fine trim',
                                  value: settings.gainAdjust,
                                  min: -0.3,
                                  max: 0.3,
                                  display: '${(settings.gain * 100).round()}%',
                                  onChanged: (v) => store.updateSettings(settings.copyWith(gainAdjust: v)),
                                ),
                                _SliderTile(
                                  label: 'Dead zone',
                                  value: settings.deadzone,
                                  min: 0,
                                  max: 0.20,
                                  display: '${(settings.deadzone * 100).round()}%',
                                  onChanged: (v) => store.updateSettings(settings.copyWith(deadzone: v)),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => store.updateSettings(settings.copyWith(
                                      preset: SensitivityPreset.medium,
                                      gainAdjust: 0.0,
                                      deadzone: const GameSettings().deadzone,
                                      invertX: false,
                                      invertY: false,
                                    )),
                                    child: Text(
                                      'Reset feel to defaults',
                                      style: AppText.body(11.5, color: AppColors.inkFaint),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const SectionLabel('Control'),
                          const SizedBox(height: 10),
                          GlassCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _SwitchTile(
                                  icon: Icons.swap_horiz_rounded,
                                  title: 'Invert left / right',
                                  subtitle: 'For players who read tilt the other way',
                                  value: settings.invertX,
                                  onChanged: (v) =>
                                      store.updateSettings(settings.copyWith(invertX: v)),
                                ),
                                _SwitchTile(
                                  icon: Icons.swap_vert_rounded,
                                  title: 'Invert forward / back',
                                  subtitle: 'Flip the vertical axis',
                                  value: settings.invertY,
                                  onChanged: (v) =>
                                      store.updateSettings(settings.copyWith(invertY: v)),
                                ),
                                _SwitchTile(
                                  icon: Icons.auto_fix_high_rounded,
                                  title: 'Adapt to posture',
                                  subtitle: 'Slowly re-zeros while the marble rests',
                                  value: settings.autoCalibrate,
                                  onChanged: (v) =>
                                      store.updateSettings(settings.copyWith(autoCalibrate: v)),
                                ),
                                _ActionTile(
                                  icon: Icons.explore_rounded,
                                  title: 'Recalibrate now',
                                  subtitle: 'Hold the phone flat and capture a new level',
                                  onTap: () => _showCalibration(context),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const SectionLabel('Feedback'),
                          const SizedBox(height: 10),
                          GlassCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _SwitchTile(
                                  icon: Icons.volume_up_rounded,
                                  title: 'Sound',
                                  subtitle: 'Impact, pickup and clear effects',
                                  value: settings.sound,
                                  onChanged: (v) => store.updateSettings(settings.copyWith(sound: v)),
                                ),
                                _SwitchTile(
                                  icon: Icons.vibration_rounded,
                                  title: 'Haptics',
                                  subtitle: 'Feel wall hits and pickups',
                                  value: settings.haptics,
                                  onChanged: (v) =>
                                      store.updateSettings(settings.copyWith(haptics: v)),
                                ),
                                _SwitchTile(
                                  icon: Icons.motion_photos_off_rounded,
                                  title: 'Reduce motion',
                                  subtitle: 'Turns off parallax, trail and particles',
                                  value: settings.reduceMotion,
                                  onChanged: (v) =>
                                      store.updateSettings(settings.copyWith(reduceMotion: v)),
                                ),
                                _SwitchTile(
                                  icon: Icons.palette_outlined,
                                  title: 'Colourblind accents',
                                  subtitle: 'Swaps orb and exit hues for clarity',
                                  value: settings.colorblind,
                                  onChanged: (v) =>
                                      store.updateSettings(settings.copyWith(colorblind: v)),
                                ),
                                _SwitchTile(
                                  icon: Icons.front_hand_outlined,
                                  title: 'Left-handed HUD',
                                  subtitle: 'Moves the pause control to the left',
                                  value: settings.leftHanded,
                                  onChanged: (v) =>
                                      store.updateSettings(settings.copyWith(leftHanded: v)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const SectionLabel('Data'),
                          const SizedBox(height: 10),
                          GlassCard(
                            padding: EdgeInsets.zero,
                            child: _ActionTile(
                              icon: Icons.restart_alt_rounded,
                              title: 'Reset progress',
                              subtitle: 'Clears stars, best times and unlocks',
                              danger: true,
                              onTap: () => _confirmReset(context),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Center(
                            child: Text(
                              'Neon Maze 1.0.0  ·  made with Flutter',
                              style: AppText.body(11, color: AppColors.inkFaint),
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
      },
    );
  }

  void _showCalibration(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CalibrationSheet(
        settings: store.settings,
        onCalibrated: (zero) {
          store.updateSettings(
            store.settings.copyWith(calX: zero.dx, calY: zero.dy),
          );
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Calibrated. Hold the phone the same way while you play.'),
              backgroundColor: AppColors.panelHi,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Reset everything?', style: AppText.display(20)),
        content: Text(
          'All stars, best times and unlocked levels will be deleted. This cannot be undone.',
          style: AppText.body(13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: AppText.body(13, color: AppColors.inkDim)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Reset', style: AppText.body(13, weight: 600, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await store.resetProgress();
    }
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppText.body(12.5, weight: 500, color: AppColors.inkDim)),
              const Spacer(),
              Text(display, style: AppText.body(12, weight: 600, color: AppColors.cyan)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Icon(icon, size: 19, color: value ? AppColors.cyan : AppColors.inkFaint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.body(13.5, weight: 600, color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppText.body(11, color: AppColors.inkFaint, height: 1.3)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.bg,
            activeTrackColor: AppColors.cyan,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            inactiveThumbColor: AppColors.inkDim,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.cyan;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        child: Row(
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(13.5, weight: 600, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppText.body(11, color: AppColors.inkFaint)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _CalibrationSheet extends StatefulWidget {
  const _CalibrationSheet({required this.settings, required this.onCalibrated});

  final GameSettings settings;
  final ValueChanged<Offset> onCalibrated;

  @override
  State<_CalibrationSheet> createState() => _CalibrationSheetState();
}

class _CalibrationSheetState extends State<_CalibrationSheet> {
  late final TiltController _tilt = TiltController(widget.settings)..start();

  @override
  void dispose() {
    _tilt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      decoration: const BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),
            Text('Calibrate', style: AppText.display(22)),
            const SizedBox(height: 6),
            Text(
              'Hold your phone flat, screen up, exactly how you will play. Center the bubble, then capture.',
              textAlign: TextAlign.center,
              style: AppText.body(12.5, height: 1.45),
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _tilt,
              builder: (context, _) => CustomPaint(
                size: const Size(190, 190),
                painter: SpiritLevelPainter(
                  tilt: _tilt,
                  color: AppColors.cyan,
                  deadzone: widget.settings.deadzone,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_tilt.sensorAvailable)
              Text(
                'No motion sensor detected. Drag steering will be used on this device.',
                textAlign: TextAlign.center,
                style: AppText.body(11.5, color: AppColors.gold),
              ),
            const SizedBox(height: 12),
            NeonButton(
              label: 'CAPTURE LEVEL',
              icon: Icons.gps_fixed_rounded,
              onTap: () {
                final zero = _tilt.calibrate();
                widget.onCalibrated(zero);
              },
            ),
          ],
        ),
      ),
    );
  }
}
