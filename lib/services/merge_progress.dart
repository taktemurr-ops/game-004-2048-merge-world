import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/merge_2048.dart';
import '../game/merge_mode.dart';

/// Typed and validated save. No user ID or network is used.
class MergeSave {
  final MergeMode mode;
  final int remainingSeconds;
  final bool paused;
  final Map<String, dynamic> gameData;
  const MergeSave({required this.mode, required this.remainingSeconds,
      required this.paused, required this.gameData});

  Map<String, dynamic> toJson() => {
        'schema': 1,
        'mode': mode.name,
        'remainingSeconds': remainingSeconds,
        'paused': paused,
        'game': gameData,
      };

  static MergeSave? decode(Object? raw) {
    try {
      if (raw is! Map<String, dynamic> || raw['schema'] != 1) return null;
      final name = raw['mode'];
      if (name is! String) return null;
      final modes = MergeMode.values.where((m) => m.name == name).toList();
      if (modes.length != 1) return null;
      final remaining = raw['remainingSeconds'];
      final paused = raw['paused'];
      if (remaining is! int || remaining < 0 || remaining > 3600 ||
          paused is! bool || raw['game'] is! Map<String, dynamic>) return null;
      final data = raw['game'] as Map<String, dynamic>;
      final game = Merge2048.fromSnapshot(data);
      if (game.size != modes.single.boardSize) return null;
      return MergeSave(mode: modes.single, remainingSeconds: remaining,
          paused: paused, gameData: data);
    } catch (_) {
      return null;
    }
  }
}

class MergeStatistics {
  final int rounds;
  final int totalMoves;
  final int highestTile;
  const MergeStatistics({this.rounds = 0, this.totalMoves = 0,
      this.highestTile = 0});
}

class MergeProgress {
  static const prefix = 'mergeworld_v2_';
  static const sessionKey = '${prefix}session';
  static const localeKey = '${prefix}locale';
  static const contrastKey = '${prefix}contrast';
  static const soundKey = '${prefix}sound';
  static const hapticsKey = '${prefix}haptics';
  static const roundsKey = '${prefix}rounds';
  static const movesKey = '${prefix}total_moves';
  static const tileKey = '${prefix}highest_tile';

  Future<MergeSave?> readSession() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(sessionKey);
    if (text == null) return null;
    try { return MergeSave.decode(jsonDecode(text)); } catch (_) { return null; }
  }

  Future<void> saveSession(MergeSave session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(sessionKey);
  }

  Future<int> bestScore(MergeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('${prefix}best_${mode.name}') ?? 0;
  }

  Future<void> recordMove(MergeMode mode, Merge2048 game) async {
    final prefs = await SharedPreferences.getInstance();
    final bestKey = '${prefix}best_${mode.name}';
    if (game.score > (prefs.getInt(bestKey) ?? 0)) {
      await prefs.setInt(bestKey, game.score);
    }
    final high = game.board.expand((row) => row).fold<int>(0,
        (previous, tile) => tile > previous ? tile : previous);
    if (high > (prefs.getInt(tileKey) ?? 0)) {
      await prefs.setInt(tileKey, high);
    }
    await prefs.setInt(movesKey, (prefs.getInt(movesKey) ?? 0) + 1);
  }

  Future<void> recordRound() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(roundsKey, (prefs.getInt(roundsKey) ?? 0) + 1);
  }

  Future<MergeStatistics> statistics() async {
    final prefs = await SharedPreferences.getInstance();
    return MergeStatistics(rounds: prefs.getInt(roundsKey) ?? 0,
        totalMoves: prefs.getInt(movesKey) ?? 0,
        highestTile: prefs.getInt(tileKey) ?? 0);
  }

  Future<String> locale() async =>
      (await SharedPreferences.getInstance()).getString(localeKey) ?? 'tr';
  Future<void> setLocale(String v) async =>
      (await SharedPreferences.getInstance()).setString(localeKey, v);
  Future<bool> contrast() async =>
      (await SharedPreferences.getInstance()).getBool(contrastKey) ?? false;
  Future<void> setContrast(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(contrastKey, v);
  Future<bool> sound() async =>
      (await SharedPreferences.getInstance()).getBool(soundKey) ?? true;
  Future<void> setSound(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(soundKey, v);
  Future<bool> haptics() async =>
      (await SharedPreferences.getInstance()).getBool(hapticsKey) ?? true;
  Future<void> setHaptics(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(hapticsKey, v);

  /// A full GDPR-style local reset without clearing unrelated apps' preferences.
  Future<void> erase() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await prefs.remove(key);
    }
  }
}
