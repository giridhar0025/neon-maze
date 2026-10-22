import 'package:flutter/material.dart';

/// Core palette for the neon-glass look.
class AppColors {
  const AppColors._();

  static const bg = Color(0xFF04060D);
  static const bgSoft = Color(0xFF080D1A);
  static const panel = Color(0xFF0D1528);
  static const panelHi = Color(0xFF16223D);
  static const line = Color(0xFF223156);

  static const ink = Color(0xFFEAF2FF);
  static const inkDim = Color(0xFF93A4C4);
  static const inkFaint = Color(0xFF5C6C8C);

  static const cyan = Color(0xFF3BF2E2);
  static const blue = Color(0xFF4C8DFF);
  static const magenta = Color(0xFFB44CFF);
  static const violet = Color(0xFF7A5CFF);
  static const gold = Color(0xFFFFC857);
  static const amber = Color(0xFFFF9F45);
  static const mint = Color(0xFF52FFB8);
  static const danger = Color(0xFFFF5C7A);
  static const ice = Color(0xFF6FD3FF);
  static const tar = Color(0xFF8B5CF6);
  static const flow = Color(0xFF5CFF9D);
  static const fracture = Color(0xFFFF7A45);
}

/// Per-chapter identity: two accent colors used across board, UI and glow.
class ChapterTheme {
  const ChapterTheme({
    required this.name,
    required this.subtitle,
    required this.a,
    required this.b,
    required this.hazard,
    required this.mechanic,
    required this.tip,
  });

  final String name;
  final String subtitle;
  final Color a;
  final Color b;
  final Color hazard;
  final String mechanic;
  final String tip;

  static const List<ChapterTheme> all = [
    ChapterTheme(
      name: 'FIRST LIGHT',
      subtitle: 'Find your feet',
      a: AppColors.cyan,
      b: AppColors.blue,
      hazard: AppColors.danger,
      mechanic: 'Holes',
      tip: "Holes are permanent. Study the board before you tilt, and use the outer wall as a brake.",
    ),
    ChapterTheme(
      name: 'ORBIT',
      subtitle: 'Collect to escape',
      a: AppColors.magenta,
      b: AppColors.violet,
      hazard: AppColors.danger,
      mechanic: 'Energy orbs',
      tip: "Every orb must be collected before the exit unlocks. Safe route beats short route.",
    ),
    ChapterTheme(
      name: 'MOMENTUM',
      subtitle: 'Ride the push',
      a: AppColors.ice,
      b: AppColors.cyan,
      hazard: AppColors.danger,
      mechanic: 'Belts + bumpers',
      tip: "Conveyor belts push you along and bumpers redirect you. Use the force instead of fighting it.",
    ),
    ChapterTheme(
      name: 'PULSE',
      subtitle: 'Time the gaps',
      a: AppColors.gold,
      b: AppColors.amber,
      hazard: AppColors.danger,
      mechanic: 'Pulse gates',
      tip: "Gates pulse on a fixed cycle. Bright means solid; slip through while the barrier is dark.",
    ),
    ChapterTheme(
      name: 'RIFT',
      subtitle: 'Bend the board',
      a: AppColors.violet,
      b: AppColors.magenta,
      hazard: AppColors.danger,
      mechanic: 'Portals',
      tip: "Portals preserve momentum. Enter fast, then adjust the moment you come out the other side.",
    ),
    ChapterTheme(
      name: 'FLOW',
      subtitle: 'Go with the arrows',
      a: AppColors.flow,
      b: AppColors.cyan,
      hazard: AppColors.danger,
      mechanic: 'One-way panels + belts',
      tip: "Flow panels only let you pass with the arrows, and conveyor belts shove you along. Plan the entry line because the return trip is closed.",
    ),
    ChapterTheme(
      name: 'FRACTURE',
      subtitle: 'Break the short way',
      a: AppColors.fracture,
      b: AppColors.amber,
      hazard: AppColors.danger,
      mechanic: 'Breakable walls + sliders',
      tip: "Cracked walls open when you hit them hard; sliding bars sweep a gap across the corridor. Time the gap, then smash the shortcut.",
    ),
    ChapterTheme(
      name: 'BLACKOUT',
      subtitle: 'Trust the glow',
      a: AppColors.mint,
      b: AppColors.violet,
      hazard: AppColors.danger,
      mechanic: 'Darkness + magnets',
      tip: "Light shrinks to the marble and magnets pull or shove. Memorise the route, then move with short deliberate tilts.",
    ),
  ];

  static ChapterTheme of(int chapter) => all[chapter.clamp(0, all.length - 1)];

  Color get accent => a;
}
