import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio.dart';
import 'data/store.dart';
import 'theme/theme.dart';

class NeonMazeApp extends StatefulWidget {
  const NeonMazeApp({super.key, required this.store, required this.home});

  final AppStore store;
  final Widget home;

  @override
  State<NeonMazeApp> createState() => _NeonMazeAppState();
}

class _NeonMazeAppState extends State<NeonMazeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(_syncAudio);
    _syncAudio();
  }

  @override
  void didUpdateWidget(covariant NeonMazeApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_syncAudio);
      widget.store.addListener(_syncAudio);
      _syncAudio();
    }
  }

  void _syncAudio() {
    unawaited(Music.instance.configure(
      enabled: widget.store.settings.music,
      volume: widget.store.settings.musicVolume,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(Music.instance.pause());
    } else if (state == AppLifecycleState.resumed) {
      unawaited(Music.instance.resume());
      unawaited(widget.store.rollDailyIfNeeded());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.store.removeListener(_syncAudio);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Maze',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.dark,
      home: widget.home,
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
