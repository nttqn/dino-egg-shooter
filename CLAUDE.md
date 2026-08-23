# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository. It also doubles as a playbook for future Flutter+Flame casual mobile games built the same way — the "Reusable playbook" sections below aren't specific to this repo.

## What this is

A Flutter + Flame bubble-shooter ("Dynomite"-style: dinosaur eggs, hex grid, match-3) with AdMob ads, 3 game modes, and CI-only Android builds. Vietnamese-language UI. There is no native `android/` directory in this repo — see "Android project is generated, not committed" before assuming any Gradle/Manifest file exists locally.

## Commands

```
flutter pub get                    # install deps
flutter analyze                    # static analysis (also run non-blocking in CI)
flutter test                       # widget test (just checks the app boots)
flutter run -d chrome --release    # fastest way to eyeball changes — no Android device/emulator needed
```

Real APK builds happen in CI, not locally: push to `main` (or trigger `workflow_dispatch`) and GitHub Actions runs `.github/workflows/build-apk.yml`, which uploads `app-release.apk` as a build artifact. No `gh` CLI is installed in this dev environment — GitHub repo creation and any `gh api` inspection of Actions runs has to be done by the user or via the plain REST API with `curl` (which is unauthenticated here and rate-limits fast — see "Don't poll the GitHub API in a tight loop" below).

**Testing portrait-only bugs in Chrome**: `flutter run -d chrome` opens a normal browser window, which defaults to a squarish aspect ratio that hides bugs which only show up on a tall phone screen (this project hit a real one: a hardcoded row cap left a huge empty gap between the pile and the launcher only on portrait). To test properly: open DevTools (`F12`), toggle device toolbar (`Ctrl+Shift+M`), pick a phone preset or a custom size like 411×915 — **then reload the page (`F5`)**. Flutter web sizes its canvas once at startup and does not reliably re-layout just because DevTools' emulated viewport changed after the fact; a reload after enabling device mode is required, not optional.

## Android project is generated, not committed

`android/`, `ios/`, `web/`, etc. are gitignored (see `.gitignore`) so nobody needs the Android/iOS/desktop toolchains installed locally. The CI workflow regenerates `android/` from scratch on every run via `flutter create --platforms=android .`, then patches the result before building:

1. Injects the AdMob App ID (`meta-data` in `AndroidManifest.xml`) — reads the `ADMOB_APP_ID` GitHub secret, falling back to Google's public test App ID if unset. Adds the `INTERNET` permission and sets `android:label`.
2. Forces `minSdk 23` / `compileSdk 36` in `android/app/build.gradle(.kts)` (handles both the Groovy and Kotlin DSL templates, since which one `flutter create` emits depends on the installed Flutter version). `google_mobile_ads` needs a minSdk above Flutter's own default.
3. Turns on `isMinifyEnabled`/`isShrinkResources` for the release build type and appends `tool/proguard-rules-extra.pro` onto the freshly-generated `proguard-rules.pro`. **This keep-rules file exists because of a real crash, not speculatively**: `google_mobile_ads` pulls in WorkManager transitively, and R8 strips `androidx.work.impl.WorkDatabase_Impl` (only referenced via reflection) by default on recent AGP — an unprotected shrunk build crashes on launch on a real device with "Unable to get provider androidx.startup.InitializationProvider" / "Failed to create an instance of androidx.work.impl.WorkDatabase". If some *other* reflection-used class starts getting stripped in a future dependency, this is the file to extend, and the fix pattern (targeted keep rule, not disabling shrinking) is the right one to reach for again.
4. Runs `dart run flutter_launcher_icons` (after `flutter pub get`) to write `assets/icon/icon.png` into every `mipmap-*/ic_launcher` slot. To change the app icon, replace `assets/icon/icon.png` — nothing else needs editing (config lives in `pubspec.yaml`'s `flutter_launcher_icons:` block).

No release-signing step is configured yet (unlike some sibling projects) — a release build here is still debug-signed, fine for sideloading, not for a Play Store upload.

### Don't poll the GitHub API in a tight loop

Checking CI status via `curl https://api.github.com/repos/.../actions/runs` works but is **unauthenticated** in this environment — the public rate limit (60/hour/IP) gets burned through in minutes if you poll every 20s in a loop. Prefer: push, then do one check after a multi-minute wait (a real Flutter Android release build takes 3-8 minutes), or just tell the user to check the Actions tab themselves. If a check comes back `{"message":"API rate limit exceeded..."}`, stop calling the API and wait it out rather than retrying — retries don't help since it's IP-based, not request-based.

## Asset pipeline

`assets_source/` (raw art from the user, full composite sheets/logos) and `sound_src/` (raw audio) are **gitignored** — only the processed files actually used by the app live under `assets/images/`, `assets/audio/`, `assets/icon/`. This machine has no ImageMagick/ffmpeg/Python; **PowerShell + `System.Drawing` (.NET, always available on Windows) is the fallback for image processing** — cropping a composite sheet into individual sprites, making a solid background color transparent (per-pixel `LockBits` scan comparing color distance to a sampled background color, then zeroing the alpha channel), etc. See git history around the egg-sprite and dino-animation commits for working PowerShell scripts if a similar job comes up again.

**MIDI (`.mid`) is a dead end** for Flutter mobile audio — no audio plugin (`audioplayers`/`flame_audio` included) reliably plays raw MIDI across Android/iOS without a bundled synthesizer, and there's no local MIDI→WAV/MP3 conversion tool here either. Ask for pre-rendered WAV/MP3/OGG instead of trying to make MIDI work.

**`FlameAudio.play()` leaks a native `AudioPlayer` per call and never disposes it** — fine for a sound that plays once in a while, but for anything triggered frequently during gameplay (a shoot/hit/pop SFX) it causes audio lag that visibly builds up over a session as player instances pile up. Use `FlameAudio.createPool(file, maxPlayers: N)` once at startup and call `pool.start()` instead — the pool recycles a fixed number of players. See `lib/services/sound_service.dart`.

## Architecture

**`lib/game/grid/hex_grid.dart`** — the board is an offset-coordinate ("odd-r", odd rows shifted right by half a bubble) hex grid, not a square grid. `neighborsOf()`'s two neighbor-delta tables (even row vs. odd row) come straight from the redblobgames offset-coordinate reference and must stay in sync with `cellCenter()`'s shift direction if either ever changes.

**Collision (`lib/game/dino_egg_game.dart`, `_sweepCollision`)** is a proper swept ray-circle intersection against every existing bubble each frame (not just an endpoint distance check — that let fast shots tunnel through the outer shell of a dense cluster). The touch distance is deliberately **0.82× the true diameter**, not the physically-correct full diameter: at exactly 1.0×, a gap exactly one cell wide between two neighbors is mathematically unshootable (closest approach through it is ≈0.866×diameter), which reads to a player as "collision is too generous" rather than as intentional physics. This is a genre-standard forgiveness tweak, not a bug — don't "fix" it back to 1.0 without re-introducing that complaint. Landing-cell choice (`_landingSlotFor`) picks the empty neighbor of the hit cell whose direction best matches the collision normal, falling back to a BFS outward through the occupied mass (never a global-nearest-empty-cell search, which can jump into an unrelated hole deeper in the pile — an earlier, since-reverted approach).

**Game modes (`lib/models/game_mode.dart`, `_boardCleared` in `dino_egg_game.dart`)**: clearing the board never ends a round in any mode — it just refills (`_populateBoard`) and continues. Normal mode advances `level` on every clear and ramps push-down pacing faster each level (`_effectiveShotsPerPushDown`); Endless/Time Trial refill at the same flat pacing forever. A round only actually ends by losing (pile reaches the launcher) or, in Time Trial, the countdown reaching zero (`timeUp` status/overlay) — there's no "win" status.

**Flame render order gotcha**: a component's children render *after* the component's own `render()` call, not before. `DinoNpc`'s held-egg overlay is a separate child component added after the body sprite (not drawn inside `DinoNpc.render()` itself) specifically because of this — drawing it in the parent's own render put it underneath the body sprite. If a future component needs to draw something on top of a child it owns, add a second child after the first rather than trying to draw over it in the parent's `render()`.

**Sound (`lib/services/sound_service.dart`)**: every SFX call is fire-and-forget and swallows its own exceptions (missing audio hardware/permissions must never interrupt gameplay). `enabledNotifier` persists via `shared_preferences` and gates every `_play()` call — the pause menu's toggle is just a `Switch` bound to it.

**High scores (`lib/services/save_service.dart`)** are keyed by `(Difficulty, GameMode)` pair, not difficulty alone — scores across different modes aren't comparable (Endless can run indefinitely, Time Trial is capped at 3 minutes, Normal ramps difficulty by level).
