# Release checklist

## 1. Identity

| Field | Current value | Change before publishing |
|---|---|---|
| Application id | `dev.pulichara.neon_maze` | Use a domain you control, e.g. `com.yourstudio.neonmaze` |
| Version | `1.3.3+7` (`pubspec.yaml`) | Bump `versionName+versionCode` for every upload |
| Display name | Neon Maze | Android label + iOS `CFBundleDisplayName` already set |
| Target SDK | 36 | Keep current for Play requirements |

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

> Tilt to roll a glass marble through 80 neon mazes. Offline. No ads.

**Full description**

> Neon Maze turns your phone into a hand-held labyrinth. Tilt to roll a glass marble
> through glowing corridors, collect every energy orb and reach the exit before par time.
>
> EIGHT CHAPTERS, ELEVEN MECHANICS
> Holes, energy orbs, pulse gates, portals, one-way flow panels,
> conveyor belts, breakable walls, sliding walls, magnets, bumpers and blackout.
> Each chapter adds one idea, so the difficulty curve teaches you as it grows.
>
> BUILT FOR YOUR HANDS
> Calibrate once, then tune sensitivity, dead zone and axis direction. No gyroscope?
> Drag anywhere to steer. Every setting is saved on device.
>
> CHASE THREE STARS
> Each of the 80 levels has a par time. Beat it for three stars, then push your personal
> best. Progress and best times work fully offline.
>
> RESPECTS YOUR TIME
> No ads. No in-app purchases. No account. No internet permission. Instant retry,
> pause-safe timer, and a reduce-motion mode for comfortable play.

**Category:** Games → Puzzle (or Arcade). **Content rating:** Everyone.
**Data safety:** No data collected, no data shared. The release manifest has no
`INTERNET` permission; `SharedPreferences` stores progress locally only.

## 4. Assets

- 1024×1024 icon: `assets/icon/icon-1024.png` (already wired into Android/iOS/web).
- Phone screenshots (1080×1920 or higher) at `docs/screens/`:
  home, chapters, gameplay, pause, settings. Add captions in Play Console.
- Feature graphic 1024×500: not generated yet.
- Privacy policy URL: required by Play even with no collection. Host a one-page policy
  stating that the app stores settings/progress locally and transmits nothing.

## 5. Device QA (must be done on a real phone)

Tilt cannot be validated in a browser or emulator.

- [ ] Hold flat → onboarding bubble centres → **Calibrate & Start**.
- [ ] Tilt right → marble rolls right (if not, toggle **Invert left/right**).
- [ ] Tilt top edge up → marble rolls toward the bottom (if not, toggle **Invert forward/back**).
- [ ] Sensitivity presets: Easy feels slow, Expert reacts fast and scores higher.
- [ ] Toggle **Drag** in the HUD and confirm drag steering works mid-level.
- [ ] Wall hits spark + haptic; orb pickup pings; level clear plays the arpeggio.
- [ ] Pause, background the app, return → still paused, timer did not advance.
- [ ] Rotate the phone → stays portrait.
- [ ] Kill and relaunch → progress, stars, best times, calibration and settings persist.
- [ ] Chapter 3 (PULSE): a gate is solid when bright, passable when dim.
- [ ] Chapter 4 (RIFT): portal keeps momentum and does not instantly re-teleport.
- [ ] Chapter 5 (BLACKOUT): light follows the marble; reduce-motion still playable.
- [x] Cold launch on a Galaxy S25 Ultra (Android 17) — no crash (fixed R8/JNI issue).
- [x] Home → Chapter 1 → level → tilt steering → finish → 1 star + best time saved.
- [x] Accelerometer streams at 50 Hz and the marble follows the tilt direction.
- [ ] Pause/background/resume cycle on device.
- [ ] Haptics and SFX on device.
- [ ] Pulse gate, portal, flow-panel, conveyor, slider, magnet and breakable-wall levels on device.
- [ ] 60 fps on a mid-range device; no audio stutter on repeated bumper hits.

## 6. Known gaps before a 1.1

- English-only strings; the genre ships in 10 locales elsewhere.
- No cloud save or Play Games leaderboards (adds SDKs, consent copy, privacy policy).
- No daily challenge or share card yet.
- Feature graphic and store screenshots still need design production.
