import 'package:flutter/painting.dart';

import '../theme/palette.dart';

/// In-run superpowers. A pickup goes into the marble's three-slot belt and the
/// player spends it when the board calls for it.
enum PowerUpType { shield, magnet, phase, slow, reveal }

class PowerUpDef {
  const PowerUpDef({
    required this.name,
    required this.shortName,
    required this.description,
    required this.color,
    required this.duration,
    required this.stackable,
  });

  final String name;
  final String shortName;
  final String description;
  final Color color;

  /// Seconds the effect lasts. Zero means the effect is an instant charge.
  final double duration;

  /// Shield charges can stack; timed effects refresh instead of stacking.
  final bool stackable;
}

extension PowerUpTypeX on PowerUpType {
  PowerUpDef get def => switch (this) {
        PowerUpType.shield => const PowerUpDef(
            name: 'Shield',
            shortName: 'SHIELD',
            description: 'Absorbs one fall and drops you back on the last safe spot.',
            color: AppColors.mint,
            duration: 0,
            stackable: true,
          ),
        PowerUpType.magnet => const PowerUpDef(
            name: 'Magnet',
            shortName: 'MAGNET',
            description: 'Pulls every nearby energy orb straight into the marble.',
            color: AppColors.gold,
            duration: 6,
            stackable: false,
          ),
        PowerUpType.phase => const PowerUpDef(
            name: 'Phase',
            shortName: 'PHASE',
            description: 'Lets the marble pass straight through gates and sliding bars.',
            color: AppColors.violet,
            duration: 5,
            stackable: false,
          ),
        PowerUpType.slow => const PowerUpDef(
            name: 'Slow Field',
            shortName: 'SLOW',
            description: 'Cuts the speed of every moving hazard for six seconds.',
            color: AppColors.ice,
            duration: 6,
            stackable: false,
          ),
        PowerUpType.reveal => const PowerUpDef(
            name: 'Reveal',
            shortName: 'REVEAL',
            description: 'Pushes the darkness back so the whole board is readable.',
            color: AppColors.cyan,
            duration: 8,
            stackable: false,
          ),
      };
}

/// A power-up sitting on the board. Unlike orbs these are optional: they are
/// placed on detours so collecting one costs time.
class PowerUpPickup {
  const PowerUpPickup(this.center, this.type);

  final Offset center;
  final PowerUpType type;
}

const double kPowerUpRadius = 0.16;
const int kPowerUpBeltSize = 3;
