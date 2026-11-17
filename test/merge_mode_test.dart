import 'package:flutter_test/flutter_test.dart';
import 'package:game_004_2048_merge_world/game/merge_mode.dart';

void main() {
  test('modes specify correct board sizes, timers and goals', () {
    expect(MergeMode.classic.boardSize, 4);
    expect(MergeMode.bigBoard.boardSize, 5);
    expect(MergeMode.bigBoard.target, 4096);
    expect(MergeMode.daily.boardSize, 4);
    expect(MergeMode.zen.timeLimitSeconds, isNull);
    expect(MergeMode.timed.timeLimitSeconds, 180);
  });

  test('UTC daily seed is stable across locations and changes each day', () {
    final d = DateTime.utc(2026, 11, 17, 12);
    expect(dailySeed(d), dailySeed(d.toLocal()));
    expect(dailySeed(d), dailySeed(DateTime.utc(2026, 11, 17, 23)));
    expect(dailySeed(d), isNot(dailySeed(DateTime.utc(2026, 11, 18, 0))));
  });

  test('direction normalization rejects invalid inputs', () {
    expect(normalizedDirection(' UP '), 'up');
    expect(() => normalizedDirection('diagonal'), throwsArgumentError);
  });
}
