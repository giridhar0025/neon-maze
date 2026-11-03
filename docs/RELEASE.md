# Release checklist

## 1. Identity

| Field | Current value | Change before publishing |
|---|---|---|
| Application id | `dev.pulichara.neon_maze` | Use a domain you control, e.g. `com.yourstudio.neonmaze` |
| Version | `1.5.0+12` (`pubspec.yaml`) | Bump `versionName+versionCode` for every upload |
| Display name | Neon Maze | Android label + iOS `CFBundleDisplayName` already set |
| Target SDK | 36 | Keep current for Play requirements |
| Level gate | All levels open by default (QA) | Add `--dart-define=NM_UNLOCK_ALL=false` for the store build |

If you change the application id, update `android/app/build.gradle.kts`, the Kotlin
package folder under `android/app/src/main/kotlin/`, and `namespace`.

## 2. Signing

Debug keys are used by default so `flutter run --release` works. For Play:

```bash
keytool -genkey -v -keystore ~/neon-maze-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Create `android/key.properties` (never commit it):

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/Users/you/neon-maze-upload.jks
```

Then in `android/app/build.gradle.kts`:

```kotlin
val keystoreProperties = java.util.Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

**Keep minification off.** `shared_preferences_android` uses JNI bindings, and R8/AGP 9
renames the methods JNI looks up, which crashes at launch with
`NoSuchMethodError ... SharedPreferencesApiRegistrar.getAll`. `isMinifyEnabled = false`
is set in `android/app/build.gradle.kts`. If you re-enable R8, add keep rules for
`io.flutter.plugins.sharedpreferences.**` and test a cold launch before shipping.

Build:

```bash
flutter build appbundle --release   # preferred for Play
flutter build apk --release         # sideload/testing
```

Outputs: `build/app/outputs/bundle/release/app-release.aab` and
`build/app/outputs/flutter-apk/app-release.apk`.

## 3. Store listing copy

**Short description (80 chars)**

> Tilt through 800 neon mazes. Grab superpowers. Chase stars offline.

**Full description**

> Neon Maze turns your phone into a hand-held labyrinth. Tilt to roll a glass marble
> through glowing corridors, collect every energy orb and reach the exit before par time.
>
> 800 LEVELS ACROSS EIGHT CHAPTERS
> Every chapter has one hundred levels split into five acts. Holes, energy orbs, pulse
> gates, portals, one-way flow panels, conveyor belts, breakable walls, sliding walls,
> magnets, bumpers and blackout are introduced one idea at a time, then combined.
> Late-game boards stay readable: difficulty comes from longer routes and smarter hazard
> placement, not from shrinking the maze.
>
> FIVE SUPERPOWERS
> Find Shield, Magnet, Phase, Slow Field and Reveal charges on optional detours. They
> fill a three-slot belt and are tapped exactly when the board calls for them.
>
> A REASON TO COME BACK
> A date-seeded Daily Challenge pays sparks and builds a streak. Three daily missions
> reset at midnight. Spend sparks on five cosmetic marble finishes in the Marble Lab.
>
> BUILT FOR YOUR HANDS
> Calibrate once, then tune sensitivity, dead zone and axis direction. No gyroscope?
> Drag anywhere to steer. Synthesised SFX and a looping soundtrack, both switchable.
>
> RESPECTS YOUR TIME
> No ads. No in-app purchases. No account. No internet permission. Instant retry,
> pause-safe timer, and a reduce-motion mode for comfortable play.

**Category:** Games → Puzzle (or Arcade). **Content rating:** Everyone.
**Data safety:** No data collected, no data shared. The release manifest has no
`INTERNET` permission; `SharedPreferences` stores progress locally only.

## 4. App Store / Play Console specifics

### iOS

- `ios/Runner/PrivacyInfo.xcprivacy` is included and declares:
  - no tracking, no collected data;
  - `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` for
    `shared_preferences`.
- `Info.plist` sets `ITSAppUsesNonExemptEncryption = false`, so the export-compliance
  prompt is skipped.
- Supported orientations are portrait only (portrait + upside down on iPad).
- Bundle id is `dev.pulichara.neonMaze` in the Runner target; change it to a domain you
  control before creating the App Store record.
- App Privacy answers: **Data Not Collected**.
- Age rating: 4+.
- Required screenshots: 6.9" and 6.5" iPhone, plus 13" iPad if you ship iPad support.
  Use the generated `docs/screens/` shots, but recapture after the 1.4 UI changes.

### Google Play

- Build `appbundle`, not APK, for the store. Keep minification off (see note above).
- Data safety: no data collected, no data shared, no internet permission.
- Content rating: Everyone / PEGI 3.
- Use an internal testing track first; install the bundle on a real device and play
  through a chapter transition, a daily challenge and a power-up level.

### Privacy policy

Even with no collection, both stores require a reachable URL. The policy only needs to
state that progress/settings live on-device via `SharedPreferences`, that the app has no
network permission, and that no analytics/ads/accounts are used.

## 5. Assets

- 1024×1024 icon: `assets/icon/icon-1024.png` (already wired into Android/iOS/web).
- Phone screenshots (1080×1920 or higher) at `docs/screens/`:
  home, chapters, gameplay, pause, settings. Add captions in Play Console.
- Feature graphic 1024×500: not generated yet.
- Privacy policy URL: required by Play even with no collection. Host a one-page policy
  stating that the app stores settings/progress locally and transmits nothing.

## 6. Device QA (must be done on a real phone)

Tilt cannot be validated in a browser or emulator.

- [ ] Hold flat → onboarding bubble centres → **Calibrate & Start**.
- [ ] Tilt right → marble rolls right (if not, toggle **Invert left/right**).
- [ ] Tilt top edge up → marble rolls toward the bottom (if not, toggle **Invert forward/back**).
- [ ] Sensitivity presets: Easy feels slow, Expert reacts fast and scores higher.
- [ ] Toggle **Drag** in the HUD and confirm drag steering works mid-level.
- [ ] Wall hits spark + haptic; orb pickup pings; level clear plays the arpeggio.
- [ ] Background music loops without a click and stops when the app is backgrounded.
- [ ] Pause, background the app, return → still paused, music stays paused, timer did not advance.
- [ ] Rotate the phone → stays portrait.
- [ ] Kill and relaunch → progress, stars, best times, calibration, music setting and sparks persist.
- [ ] Chapter 3 (PULSE): a gate is solid when bright, passable when dim.
- [ ] Chapter 4 (RIFT): portal keeps momentum and does not instantly re-teleport.
- [ ] Chapter 7 (BLACKOUT): light follows the marble; Reveal lights the board;
      reduce-motion still playable.
- [ ] Collect each of the five power-ups, confirm the belt slot appears, tap it and
      confirm the effect and timer.
- [ ] Shield save: fall into a hole with Shield active → marble returns to a safe spot,
      the run continues, and the shield charge is consumed.
- [ ] Daily challenge: complete once, confirm sparks/streak persist after relaunch;
      complete the same day again and confirm no duplicate reward.
- [ ] Claim a daily mission, buy a marble finish, equip it, and confirm the marble colour
      changes in-game.
- [ ] Level select shows 100 levels per chapter and scrolls smoothly on a mid-range phone.
- [x] Cold launch on a Galaxy S25 Ultra (Android 17) — no crash (fixed R8/JNI issue).
- [x] Home → Chapter 1 → level → tilt steering → finish → 1 star + best time saved.
- [x] Accelerometer streams at 50 Hz and the marble follows the tilt direction.
- [ ] Pause/background/resume cycle on device.
- [ ] Haptics and SFX on device.
- [ ] Pulse gate, portal, flow-panel, conveyor, slider, magnet and breakable-wall levels on device.
- [ ] 60 fps on a mid-range device; no audio stutter on repeated bumper hits.

## 7. Known gaps before launch

- English-only strings; localise the store listing and in-game strings for the main
  markets (the genre ships in 10+ locales).
- No cloud save or leaderboards yet. Both add SDKs, consent copy and privacy-policy work,
  but they are the next big retention/competition features.
- No share card for daily results or chapter milestones.
- Feature graphic, preview video and store screenshots still need final design production.
- Consider a small in-app "restore purchases" path only if IAP is added later; the current
  1.4 build has no purchases, so there is nothing to restore.
