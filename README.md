# 2048 Merge World — Game Studio 100 / Game 004

Flutter 3.3+ offline-first 2048 variant for Android and iOS, extending the
existing `game-004-2048-merge-world` repository (not a new project).

## Implemented in source
- Correct 2048 merge rules, scoring, one-merge-per-tile, legal moves and undo.
- **Classic 4×4, Big Board 5×5 (4096 goal), daily, Zen, timed (180 seconds)**.
- Swipe, accessible directional buttons and desktop keyboard arrows.
- Hints (free, offline), responsive animated tiles and pause/resume flow.
- Local save/resume, best score per mode, session stats and highest tile.
- Turkish/English/Arabic strings, privacy screen, sound/vibration/contrast.
- Clear local data; no accounts, analytics, ad network or payments enabled.
- Engine, storage and widget test coverage; Android and iOS CI configuration.

```bash
flutter create --platforms=android,ios --project-name game_004_2048_merge_world .
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build apk --debug
```

A source commit is **not** an app-store release. Physical device testing,
signed release builds, store assets, IAP/ads and policy verification are not
claimed. Refer to `docs/RELEASE_READINESS.md` and release issue #1.
