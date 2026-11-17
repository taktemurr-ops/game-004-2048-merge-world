import 'package:flutter_test/flutter_test.dart';
import 'package:game_004_2048_merge_world/game/merge_2048.dart';

void main() {
  test('hint favors an immediate merge and leaves state unchanged', () {
    final game = Merge2048.fromBoard([
      [2, 2, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    final before = game.toSnapshot().toString();
    expect(game.suggestedMove, SlideDirection.left);
    expect(game.toSnapshot().toString(), before);
    expect(game.score, 0);
    expect(game.moves, 0);
    expect(game.canUndo, false);
  });

  test('hint returns null for full board without possible merges', () {
    final game = Merge2048.fromBoard([
      [2, 4, 8, 16],
      [32, 64, 128, 256],
      [4, 8, 16, 32],
      [64, 128, 256, 512],
    ]);
    expect(game.gameOver, true);
    expect(game.suggestedMove, isNull);
  });

  test('hint is available without watching an ad', () {
    final game = Merge2048.fromBoard([
      [0, 2, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    expect(game.suggestedMove, isNotNull);
  });
}
