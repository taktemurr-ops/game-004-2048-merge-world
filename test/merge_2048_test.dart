import 'package:flutter_test/flutter_test.dart';
import 'package:game_004_2048_merge_world/game/merge_2048.dart';

void main() {
  test('snapshot restores tiles, score and moves without spawning', () {
    final game = Merge2048.fromBoard([
      [2, 2, 0, 0], [0, 0, 0, 0],
      [0, 0, 0, 0], [0, 0, 0, 0],
    ]);
    game.slide(SlideDirection.left, addTile: false);
    final restored = Merge2048.fromSnapshot(game.toSnapshot());
    expect(restored.board, game.board);
    expect(restored.score, 4);
    expect(restored.moves, 1);
    expect(restored.canUndo, false);
  });
  test('snapshot rejects invalid board and negative counters', () {
    expect(() => Merge2048.fromSnapshot({
      'version': 1, 'board': [[2]], 'score': 0, 'moves': 0,
    }), throwsFormatException);
    expect(() => Merge2048.fromSnapshot({
      'version': 1,
      'board': List.generate(4, (_) => [0, 0, 0, 0]),
      'score': -1, 'moves': 0,
    }), throwsFormatException);
  });
  test('5x5 mode supports merges and undo', () {
    final game = Merge2048.fromBoard([
      [2, 2, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0],
    ]);
    expect(game.size, 5);
    expect(game.slide(SlideDirection.left, addTile: false), isTrue);
    expect(game.board[0], [4, 0, 0, 0, 0]);
    expect(game.undo(), isTrue);
    expect(game.board[0], [2, 2, 0, 0, 0]);
  });
  test('new 5x5 game starts with two tiles', () {
    final game = Merge2048(size: 5);
    expect(game.board.length, 5);
    expect(game.board.expand((row) => row).where((v) => v != 0).length, 2);
  });
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
  test('undo restores board, score and moves after a merge', () {
    final game = Merge2048.fromBoard([
      [2,2,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]
    ]);
    expect(game.slide(SlideDirection.left, addTile:false), true);
    expect(game.canUndo, true);
    expect(game.score, 4);
    expect(game.undo(), true);
    expect(game.board[0], [2,2,0,0]);
    expect(game.score, 0);
    expect(game.moves, 0);
    expect(game.canUndo, false);
  });
  test('no-op does not generate an undo snapshot', () {
    final game = Merge2048.fromBoard([
      [2,4,8,16],[0,0,0,0],[0,0,0,0],[0,0,0,0]
    ]);
    expect(game.slide(SlideDirection.left, addTile:false), false);
    expect(game.canUndo, false);
  });
}
