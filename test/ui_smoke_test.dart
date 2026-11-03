import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neon_maze/data/store.dart';
import 'package:neon_maze/game/levels.dart';
import 'package:neon_maze/ui/game_screen.dart';
import 'package:neon_maze/ui/home_screen.dart';
import 'package:neon_maze/ui/level_select_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<AppStore> readyStore() async {
    final store = await AppStore.load();
    await store.markTutorialSeen();
    return store;
  }

  void phoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('home renders the daily loop and my new actions', (tester) async {
    phoneSurface(tester);
    final store = await readyStore();

    await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('NEON'), findsOneWidget);
    expect(find.text('DAILY CHALLENGE'), findsOneWidget);
    expect(find.text('MISSIONS'), findsOneWidget);
    expect(find.text('MARBLE LAB'), findsOneWidget);
    expect(find.text('ALL LEVELS OPEN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('level select shows one hundred chapter levels', (tester) async {
    phoneSurface(tester);
    final store = await readyStore();

    await tester.pumpWidget(MaterialApp(home: LevelSelectScreen(store: store)));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('CHAPTERS'), findsOneWidget);
    expect(find.textContaining('0 / 100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('game screen renders a campaign level with a power-up belt', (
    tester,
  ) async {
    phoneSurface(tester);
    final store = await readyStore();
    final spec = LevelCatalog.all.firstWhere((s) => s.powerUps > 0);

    await tester.pumpWidget(
      MaterialApp(
        home: GameScreen(levelId: spec.id, store: store),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('LEVEL ${spec.number}'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
