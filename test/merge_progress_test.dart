import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_004_2048_merge_world/game/merge_2048.dart';
import 'package:game_004_2048_merge_world/game/merge_mode.dart';
import 'package:game_004_2048_merge_world/services/merge_progress.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('a saved 4x4 game round-trips without spawning new tiles', () async {
    final game = Merge2048.fromBoard([
      [2, 2, 0, 0], [0, 0, 0, 0],
      [0, 0, 0, 0], [0, 0, 0, 0],
    ]);
    game.slide(SlideDirection.left, addTile: false);
    final store = MergeProgress();
    await store.saveSession(MergeSave(mode: MergeMode.classic,
      remainingSeconds: 180, paused: true,
      gameData: Map<String, dynamic>.from(game.toSnapshot())));
    final restored = await store.readSession();
    expect(restored?.mode, MergeMode.classic);
    expect(restored?.remainingSeconds, 180);
    final restoredGame = Merge2048.fromSnapshot(restored!.gameData);
    expect(restoredGame.board, game.board);
    expect(restoredGame.score, game.score);
    expect(restoredGame.moves, game.moves);
  });

  test('corrupt saves and board-size mismatches are rejected', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MergeProgress.sessionKey, 'not-json');
    expect(await MergeProgress().readSession(), isNull);
    final raw = MergeSave(mode: MergeMode.bigBoard, remainingSeconds: 180,
      paused: false, gameData: Map<String, dynamic>.from(
        Merge2048(size: 4).toSnapshot())).toJson();
    expect(MergeSave.decode(jsonDecode(jsonEncode(raw))), isNull);
    expect(MergeSave.decode({...raw, 'remainingSeconds': -3}), isNull);
    expect(MergeSave.decode({...raw, 'mode': 'unknown'}), isNull);
  });

  test('record keeping maintains best and highest tile', () async {
    final store = MergeProgress();
    final game = Merge2048.fromBoard([
      [2, 2, 0, 0], [0, 0, 0, 0],
      [0, 0, 0, 0], [0, 0, 0, 0],
    ]);
    game.slide(SlideDirection.left, addTile: false);
    await store.recordRound();
    await store.recordMove(MergeMode.classic, game);
    expect(await store.bestScore(MergeMode.classic), 4);
    final stats = await store.statistics();
    expect(stats.rounds, 1);
    expect(stats.totalMoves, 1);
    expect(stats.highestTile, 4);
    await store.recordMove(MergeMode.classic,
      Merge2048.fromBoard([
        [2, 0, 0, 0], [0, 0, 0, 0],
        [0, 0, 0, 0], [0, 0, 0, 0],
      ]));
    expect(await store.bestScore(MergeMode.classic), 4);
  });

  test('erase removes only game-owned keys and leaves other apps intact', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = MergeProgress();
    await prefs.setString('another_app_key', 'keep');
    await store.setLocale('ar');
    await store.setSound(false);
    await store.erase();
    expect(await store.locale(), 'tr');
    expect(await store.sound(), true);
    expect(prefs.getString('another_app_key'), 'keep');
  });
}
