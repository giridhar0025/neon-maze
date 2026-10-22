import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/store.dart';
import 'ui/game_screen.dart';
import 'ui/home_screen.dart';
import 'ui/how_to_play_screen.dart';
import 'ui/level_select_screen.dart';
import 'ui/settings_screen.dart';

/// Dev-only deep link used while iterating on layouts:
/// `flutter run --dart-define=NM_START=game:12`.
Widget _initialScreen(AppStore store) {
  const start = String.fromEnvironment('NM_START');
  if (start == 'levels') return LevelSelectScreen(store: store);
  if (start == 'settings') return SettingsScreen(store: store);
  if (start == 'howto') return HowToPlayScreen(store: store);
  if (start.startsWith('game:')) {
    final id = int.tryParse(start.substring(5)) ?? 0;
    return GameScreen(levelId: id, store: store);
  }
  return HomeScreen(store: store);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final store = await AppStore.load();
  if (const bool.fromEnvironment('NM_SKIP_ONBOARDING')) {
    await store.markTutorialSeen();
  }
  runApp(NeonMazeApp(store: store, home: _initialScreen(store)));
}
