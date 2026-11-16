import 'package:flutter_test/flutter_test.dart';
import 'package:game_004_2048_merge_world/game/merge_2048.dart';

void main() {
  test('two pairs merge once per move', () {
    final game = Merge2048.fromBoard([
      [2,2,2,2],[0,0,0,0],[0,0,0,0],[0,0,0,0]
    ]);
    expect(game.slide(SlideDirection.left, addTile:false), true);
    expect(game.board[0], [4,4,0,0]);
    expect(game.score, 8);
  });
  test('merged tile does not merge twice in one turn', () {
    final game = Merge2048.fromBoard([
      [2,2,4,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]
    ]);
    game.slide(SlideDirection.left, addTile:false);
    expect(game.board[0], [4,4,0,0]);
  });
  test('no-op does not increase move count', () {
    final game = Merge2048.fromBoard([
      [2,4,8,16],[0,0,0,0],[0,0,0,0],[0,0,0,0]
    ]);
    expect(game.slide(SlideDirection.left, addTile:false), false);
    expect(game.moves, 0);
  });
  test('no moves possible is game over', () {
    final game = Merge2048.fromBoard([
      [2,4,2,4],[4,2,4,2],[2,4,2,4],[4,2,4,2]
    ]);
    expect(game.gameOver, true);
  });
}
