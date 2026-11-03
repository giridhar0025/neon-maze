# Feature gap: PineSoft `Gyro Maze` (v1.0.4) → Neon Maze

Evidence source: `GyroMaze_1.0.4_APKPure.xapk` (base APK SHA-256 `d6cf4429…7d2b03`).
Analysed with REA 6.7.0 (`identify-flutter-build`, `inspect-dart-aot`), plus Dart AOT
string-pool and class-token inspection. It is a Flutter app with split ABI APKs, no
image/level assets, and all gameplay drawn in code.

## What they actually shipped

| Area | Evidence | Reality |
|---|---|---|
| Engine | `flutter_detected: true`, `libapp.so` 5.75 MB, snapshot `78da37fe…249f3f` | Flutter, Dart AOT, no asset levels |
| Maze | `MazeGenerator`, `MazeCell`, `MazeHole`, `_backtrackingStack`, `_nextSeed` | Seeded backtracker maze, holes as the only hazard |
| Input | `TiltDetector`, `TiltDirection`, `SensorManager`, `MethodChannelSensors`, `GyroCalibrator` | Custom sensor channel + calibration |
| Tuning | `gyromaze_sensitivity`, `gyromaze_sens_preset`, `gyromaze_sens_gain`, `gyromaze_stickiness`, `gyromaze_drift_speed`, `gyromaze_center_bubble_opacity` | 4 sensitivity presets, deadzone/bubble, adaptive drift |
| HUD | `TiltIndicator`, `SpiritLevelPainter`, `FloatingScoreText`, `GameControlBar`, `GamePhase` | Floating bubble level + score popups |
| Progression | `Level`, `best_score`, `unlocked`, `NEW BEST!`, `Next Level`, `PLACEHOLDER_MAZE_ACH_*` | Linear levels, best score, 6 achievements |
| Modes | `gyromaze_timed_mode`, `Time remaining:`, `_onExtraTimeWithAd` | Optional countdown; rewarded ad for extra time |
| Meta | `google_mobile_ads`, `in_app_purchase`, `pinesoft_ads`, `ConsentInformation`, `gyro_age_profile` | Banner/rewarded ads, remove-ads IAP, UMP consent, age gate |
| Online | `games_services`, `PLACEHOLDER_MAZE_LEADERBOARD`, `submitScore` | Play Games leaderboard |
| Locales | `app_localizations_{en,it,es,de,fr,pt,pl,ko,zh,hi}.dart` | 10 locales |
| Art | no images/fonts in assets, `CustomPainter` classes | Flat minimal vector look, single marble |

Their score is `level score × sensitivity multiplier` with an ad-gated timer. There is no
level select, no star rating, no collectibles, no advanced mechanics, and no accessibility
beyond a touch fallback.

## Our product decisions

1. **Original identity** — "Neon Maze", our own levels, palette, fonts, and audio. Inspired
   by the genre, not a copy of their name, art, or level data.
2. **No ads, no IAP, no network** in v1. Removes the consent/age/ad SDK surface and makes
   the game fully offline.
3. **Depth over one mechanic** — eleven mechanics across eight chapters.
4. **Respect the player** — instant retry, no fail screens that punish, pause-safe timer,
   persistent bests, and full control over feel.

## Mechanics we add

| Mechanic | Why it is better |
|---|---|
| Energy orbs (collect all to open exit) | Turns "walk to exit" into routing decisions |
| Pulse gates | Timing puzzle: solid barriers cycle dark and become passable |
| Bumpers | Spring posts: they return more speed than they absorb, so a hit redirects the run instead of ending it |
| Portals | Spatial reasoning, signature "wow" moment |
| One-way flow panels | Route planning: enter with the arrows or not at all |
| Conveyor belts | Directional force changes the line and rewards reading the floor |
| Sliding walls | Timing puzzle with a moving gap instead of an on/off barrier |
| Magnets | Attract/repel fields that bend the route and reward tilt control |
| Breakable walls | Risk/reward shortcuts that reward a fast run-up |
| Blackout | Light radius around marble; tension without jumpscares |
| Star tiers + par times | Replayability with a clear skill goal |
| Soft wall bounce, silent grazes | Physical but never sticky or noisy |
| Ghost best-run trail | Visible self-competition |

## UX we add

- Home with **Continue**, chapter map, and animated marble.
- **Level select** with stars, best times, and locked-state previews.
- 3-2-1 countdown, pause sheet, calibrated "hold flat" onboarding.
- Live **spirit level** and one-tap recalibration; sensitivity presets plus fine slider.
- Settings: deadzone, invert axes, haptics, sound, reduce motion, colorblind accents,
  left/right-handed HUD.
- Win sheet: stars, time vs par, best, next; retry in one tap.
- Resume mid-level after app backgrounding.
- Accessibility: reduce motion disables parallax/particles; colorblind palette swaps
  orb/exit hues; all touch targets ≥ 48 dp.

## What we deliberately do not do

- No APK strings, level seeds, art, or audio from the original are reused.
- No Play Games / Firebase / ads SDK in v1; those are additive later if wanted.

## Delivered in this build

| Promise | Where it lives |
|---|---|
| Seeded maze generation, solvable by construction | `lib/game/maze.dart`, `lib/game/levels.dart` |
| Eleven mechanics + 800-level curve, critical-path placement | `lib/game/levels.dart`, tested in `test/levels_test.dart` |
| Circle/AABB physics with sub-stepping | `lib/game/simulation.dart` |
| Calibrated tilt, dead zone, presets, auto-zero | `lib/game/tilt.dart`, `lib/ui/settings_screen.dart` |
| Cached neon board + live glass marble + power-up auras/skins | `lib/render/scene_painter.dart` |
| Five in-maze superpowers (Shield, Magnet, Phase, Slow, Reveal) | `lib/game/powerups.dart`, `simulation.dart`, `game_screen.dart` |
| Looping menu/game/blackout music + SFX | `tool/gen_audio.py`, `lib/core/audio.dart` |
| Daily challenge, streak, missions, sparks, marble skins | `lib/game/daily.dart`, `lib/data/store.dart`, `ui/home_screen.dart` |
| Stars, best times, unlocks, resume | `lib/data/store.dart`, `lib/ui/level_select_screen.dart` |
| Onboarding, pause, win, retry | `lib/ui/game_screen.dart` |
| Original identity, audio, icon | `tool/gen_audio.py`, `tool/gen_icon.py`, `assets/` |

Deliberate gaps kept for a later release: leaderboards, cloud save, localisation,
share cards, and final store listing assets.
