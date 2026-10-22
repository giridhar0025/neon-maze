import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'palette.dart';

/// Shared type ramp. Display type uses Space Grotesk, UI text uses Inter.
class AppText {
  const AppText._();

  static TextStyle display(
    double size, {
    double weight = 700,
    double letterSpacing = -0.5,
    Color color = AppColors.ink,
    double height = 1.0,
  }) {
    return TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: size,
      fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
      fontVariations: [FontVariation('wght', weight)],
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  static TextStyle body(
    double size, {
    double weight = 400,
    Color color = AppColors.inkDim,
    double height = 1.35,
    double letterSpacing = 0.0,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
      fontVariations: [FontVariation('wght', weight)],
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static const label = TextStyle(
    fontFamily: 'Inter',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
    color: AppColors.inkFaint,
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.cyan,
    onPrimary: AppColors.bg,
    secondary: AppColors.magenta,
    onSecondary: Colors.white,
    surface: AppColors.panel,
    onSurface: AppColors.ink,
    error: AppColors.danger,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    fontFamily: 'Inter',
    splashFactory: InkSparkle.splashFactory,
    textTheme: TextTheme(
      displayLarge: AppText.display(52, letterSpacing: -1.6),
      displayMedium: AppText.display(40, letterSpacing: -1.2),
      headlineLarge: AppText.display(30, letterSpacing: -0.8),
      headlineMedium: AppText.display(24, letterSpacing: -0.4),
      titleLarge: AppText.display(20, weight: 600, letterSpacing: 0.2),
      titleMedium: AppText.body(16, weight: 600, color: AppColors.ink),
      bodyLarge: AppText.body(16),
      bodyMedium: AppText.body(14),
      bodySmall: AppText.body(12, color: AppColors.inkFaint),
      labelLarge: AppText.body(13, weight: 600, color: AppColors.ink),
    ),
    dividerColor: AppColors.line,
    iconTheme: const IconThemeData(color: AppColors.ink),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : Colors.white.withValues(alpha: 0.12),
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(1),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.bg : AppColors.inkDim,
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 3,
      activeTrackColor: AppColors.cyan,
      inactiveTrackColor: AppColors.line,
      thumbColor: AppColors.ink,
      overlayColor: AppColors.cyan.withValues(alpha: 0.14),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
    ),
  );
}

/// A reusable vertical gradient used behind screens.
const backgroundGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF070C1A), Color(0xFF04060D), Color(0xFF080714)],
  stops: [0.0, 0.55, 1.0],
);
