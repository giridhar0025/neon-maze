import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'theme/theme.dart';

class NeonMazeApp extends StatelessWidget {
  const NeonMazeApp({super.key, required this.store, required this.home});

  final AppStore store;
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Maze',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: home,
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF04060D),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
