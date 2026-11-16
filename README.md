# 2048 Merge World

Game Studio 100 | Android + iOS | Flutter | **prototype in progress**

## Current implemented source

4×4 directional sliding, equal-tile merging, score tracking, tile spawning, game-over detection, swipe and arrow controls.

- Gameplay implementation: `lib/game/merge_2048.dart`
- Unit/EditMode test source: `test/merge_2048_test.dart`
- Interactive Flutter screen: `lib/main.dart`
 
 
**Verification status:** source and test cases are committed, but compilation, test execution,
device builds and complete gameplay verification have NOT been performed.
Run `flutter pub get`, `flutter test`, `flutter run` in a Flutter SDK environment.

## Remaining development

- Game design research: supported competitor feature matrix and user experience improvements
- Full playable levels, UI/UX polish, audio, animations, save/resume and accessibility
- Multiple modes, progression, difficulty and content tooling
- Device testing, CI, privacy permissions and compliant ads/in-app purchases
- Android and iOS release builds and store verification

This is an original prototype, NOT a finished production game.

## Recent iteration
- Undo the previous successful move; restores the exact prior board, score and move count.
- Up to 20 undo snapshots, no history generated for no-op moves.
- Added unit tests for undo restoration.
