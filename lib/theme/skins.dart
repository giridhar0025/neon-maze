import 'package:flutter/material.dart';

import 'palette.dart';

/// Cosmetic marble finishes. Sparks earned from daily challenges and missions
/// unlock them; they never affect physics or scoring.
class MarbleSkin {
  const MarbleSkin({
    required this.name,
    required this.subtitle,
    required this.core,
    required this.glow,
    required this.price,
  });

  final String name;
  final String subtitle;
  final Color core;
  final Color glow;
  final int price;
}

const List<MarbleSkin> marbleSkins = [
  MarbleSkin(
    name: 'ION',
    subtitle: 'The original cyan glass',
    core: AppColors.cyan,
    glow: AppColors.blue,
    price: 0,
  ),
  MarbleSkin(
    name: 'SOLAR',
    subtitle: 'Warm gold core',
    core: AppColors.gold,
    glow: AppColors.amber,
    price: 250,
  ),
  MarbleSkin(
    name: 'NOVA',
    subtitle: 'Magenta flare',
    core: AppColors.magenta,
    glow: AppColors.violet,
    price: 500,
  ),
  MarbleSkin(
    name: 'GLACIER',
    subtitle: 'Cold blue ice',
    core: AppColors.ice,
    glow: AppColors.cyan,
    price: 850,
  ),
  MarbleSkin(
    name: 'VOID',
    subtitle: 'Deep violet glass',
    core: AppColors.violet,
    glow: AppColors.magenta,
    price: 1400,
  ),
];

MarbleSkin skinFor(int index) =>
    marbleSkins[index.clamp(0, marbleSkins.length - 1)];
