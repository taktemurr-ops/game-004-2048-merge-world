import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:game_004_2048_merge_world/game/merge_engine.dart';
import 'package:game_004_2048_merge_world/game/rules.dart';

MergeLevel board(List<int> cells, {int target = 11}) => MergeLevel(
      size: 4,
      start: cells,
      targetExp: target,
      targetScore: 0,
      moveLimit: 0,
      timeLimit: 0,
      seed: 3,
      difficulty: 1,
      zen: false,
    );

void main() {
  final rules = MergeRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('slide left merges pairs once per move', () {
    final g = MergeGame(board([1, 1, 1, 1, 2, 0, 2, 0, 0, 0, 0, 0, 3, 3, 3, 0]));
    expect(g.move(Dir.left), isTrue);
    expect(g.cells.sublist(0, 2), equals([2, 2]));
    expect(g.cells[4], 3);
    expect(g.cells.sublist(12, 14), equals([4, 3]));
    expect(g.score, 4 + 4 + 8 + 16);
  });

  test('stones block sliding and never merge', () {
    final g = MergeGame(board([1, -1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]));
    g.move(Dir.left);
    expect(g.cells[0], 1);
    expect(g.cells[1], -1);
    expect(g.cells[2], 1);
  });

  test('a move that changes nothing is rejected', () {
    final g = MergeGame(board([1, 2, 3, 4, 2, 3, 4, 5, 3, 4, 5, 6, 4, 5, 6, 7]));
    expect(g.move(Dir.left), isFalse);
    expect(g.hasMove, isFalse);
  });

  test('undo and resume restore spawns deterministically', () {
    final l = rules.finalize(rules.build(planner.spec(20)));
    final g = MergeGame(l);
    for (var i = 0; i < 6; i++) {
      g.move(g.bestMove()!);
    }
    final snap = g.serialize();
    final r = MergeGame.restore(l, snap);
    final d = g.bestMove()!;
    g.move(d);
    r.move(d);
    expect(r.serialize(), g.serialize());
    g.undo();
    expect(g.serialize(), snap);
  });

  test('zen mode never runs out of moves', () {
    final g = MergeGame(rules.build(planner.run(GameModeId.zen, 1)).puzzle);
    for (var i = 0; i < 800; i++) {
      final d = g.bestMove();
      expect(d, isNotNull);
      g.move(d!);
    }
  });

  test('campaign levels 1..80 reachable by the AI, sample to 50.000', () {
    for (var n = 1; n <= 80; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
    for (var n = 3000; n <= 50000; n += 9400) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
