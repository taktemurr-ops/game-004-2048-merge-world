import '../core/level_plan.dart';
import '../core/rng.dart';

enum Dir { up, down, left, right }

/// Cell values are exponents: 1 = 2, 2 = 4, ... 11 = 2048. 0 = empty,
/// -1 = stone (immovable, never merges).
class MergeLevel {
  final int size;
  final List<int> start;
  final int targetExp; // 0 = endless
  final int targetScore; // 0 = none
  final int moveLimit;
  final int timeLimit;
  final int seed;
  final int difficulty;
  final bool zen;
  final int aiMoves;

  const MergeLevel({
    required this.size,
    required this.start,
    required this.targetExp,
    required this.targetScore,
    required this.moveLimit,
    required this.timeLimit,
    required this.seed,
    required this.difficulty,
    required this.zen,
    this.aiMoves = 0,
  });

  bool get endless => targetExp == 0 && targetScore == 0;

  MergeLevel withAi(int ai, int limit) => MergeLevel(
        size: size,
        start: start,
        targetExp: targetExp,
        targetScore: targetScore,
        moveLimit: limit,
        timeLimit: timeLimit,
        seed: seed,
        difficulty: difficulty,
        zen: zen,
        aiMoves: ai,
      );
}

class MergeGame {
  final MergeLevel level;
  final int n;
  late List<int> cells;
  late SeededRandom rng;
  int score = 0;
  int moves = 0;
  int merges = 0;
  int bonusMoves = 0;
  final List<String> _undo = [];
  bool recordUndo = true;

  /// Indices of tiles created by merges in the last move (for animation).
  Set<int> lastMerged = {};
  int lastSpawn = -1;

  MergeGame(this.level) : n = level.size {
    cells = List.of(level.start);
    rng = SeededRandom(level.seed);
    if (cells.where((c) => c > 0).isEmpty) {
      _spawn();
      _spawn();
    }
  }

  int idx(int x, int y) => y * n + x;

  int get maxExp => cells.fold(0, (a, b) => b > a ? b : a);

  void _spawn() {
    final empty = [for (var i = 0; i < cells.length; i++) if (cells[i] == 0) i];
    if (empty.isEmpty) {
      lastSpawn = -1;
      return;
    }
    final i = empty[rng.nextInt(empty.length)];
    cells[i] = rng.nextInt(10) == 0 ? 2 : 1;
    lastSpawn = i;
  }

  /// Lines of indices in the order tiles slide toward.
  List<List<int>> _lines(Dir d) {
    final out = <List<int>>[];
    for (var a = 0; a < n; a++) {
      final line = <int>[];
      for (var b = 0; b < n; b++) {
        switch (d) {
          case Dir.left:
            line.add(idx(b, a));
            break;
          case Dir.right:
            line.add(idx(n - 1 - b, a));
            break;
          case Dir.up:
            line.add(idx(a, b));
            break;
          case Dir.down:
            line.add(idx(a, n - 1 - b));
            break;
        }
      }
      out.add(line);
    }
    return out;
  }

  /// Applies a slide without spawning. Returns gained score or -1 if
  /// nothing moved.
  int _slide(Dir d, Set<int> merged) {
    var moved = false;
    var gained = 0;
    for (final line in _lines(d)) {
      // Stones split the line into independent segments.
      var segStart = 0;
      for (var k = 0; k <= line.length; k++) {
        if (k == line.length || cells[line[k]] == -1) {
          final seg = line.sublist(segStart, k);
          final vals = seg.map((i) => cells[i]).where((v) => v > 0).toList();
          final out = <int>[];
          var j = 0;
          while (j < vals.length) {
            if (j + 1 < vals.length && vals[j] == vals[j + 1]) {
              final v = vals[j] + 1;
              out.add(v);
              gained += 1 << v;
              merges++;
              merged.add(seg[out.length - 1]);
              j += 2;
            } else {
              out.add(vals[j]);
              j++;
            }
          }
          for (var t = 0; t < seg.length; t++) {
            final v = t < out.length ? out[t] : 0;
            if (cells[seg[t]] != v) moved = true;
            cells[seg[t]] = v;
          }
          segStart = k + 1;
        }
      }
    }
    return moved ? gained : -1;
  }

  bool canMove(Dir d) {
    final c = clone();
    return c._slide(d, <int>{}) >= 0;
  }

  bool get hasMove => Dir.values.any(canMove);

  /// Returns false when the swipe changes nothing.
  bool move(Dir d) {
    final before = recordUndo ? _snap() : '';
    final merged = <int>{};
    final g = _slide(d, merged);
    if (g < 0) return false;
    if (recordUndo) {
      _undo.add(before);
      if (_undo.length > 30) _undo.removeAt(0);
    }
    score += g;
    moves++;
    lastMerged = merged;
    _spawn();
    if (level.zen && !hasMove) _relief();
    return true;
  }

  /// Zen: clear the two smallest tiles so the game never ends.
  void _relief() {
    final tiles = [for (var i = 0; i < cells.length; i++) if (cells[i] > 0) i]
      ..sort((a, b) => cells[a].compareTo(cells[b]));
    for (final i in tiles.take(2)) {
      cells[i] = 0;
    }
  }

  bool get won {
    if (level.endless) return false;
    if (level.targetExp > 0 && maxExp < level.targetExp) return false;
    if (level.targetScore > 0 && score < level.targetScore) return false;
    return true;
  }

  int get movesLeft => level.moveLimit == 0 ? -1 : level.moveLimit + bonusMoves - moves;

  bool get lost => !won && (!hasMove || (level.moveLimit > 0 && movesLeft <= 0));

  bool get canUndo => _undo.isNotEmpty;

  void undo() {
    if (_undo.isNotEmpty) _restore(_undo.removeLast());
  }

  bool hammer(int i) {
    if (cells[i] <= 0) return false;
    _undo.add(_snap());
    cells[i] = 0;
    return true;
  }

  /// Continue after a fail: remove the 3 smallest tiles, +10 moves.
  void rescue() {
    bonusMoves += 10;
    final tiles = [for (var i = 0; i < cells.length; i++) if (cells[i] > 0) i]
      ..sort((a, b) => cells[a].compareTo(cells[b]));
    for (final i in tiles.take(3)) {
      cells[i] = 0;
    }
  }

  // ---- AI ----------------------------------------------------------------------
  double heuristic() {
    var empty = 0;
    var mono = 0.0;
    var smooth = 0.0;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final v = cells[idx(x, y)];
        if (v == 0) empty++;
        if (v <= 0) continue;
        if (x + 1 < n) {
          final r = cells[idx(x + 1, y)];
          if (r > 0) {
            smooth -= (v - r).abs();
            mono += v >= r ? 1 : -1;
          }
        }
        if (y + 1 < n) {
          final b = cells[idx(x, y + 1)];
          if (b > 0) {
            smooth -= (v - b).abs();
            mono += v >= b ? 1 : -1;
          }
        }
      }
    }
    final corner = cells[0] == maxExp ? maxExp * 3.0 : 0.0;
    return empty * 12.0 + mono.abs() * 1.5 + smooth * 1.2 + corner + maxExp * 4;
  }

  MergeGame clone() {
    final g = MergeGame._blank(level);
    g.cells = List.of(cells);
    g.rng = rng.copy();
    g.score = score;
    g.moves = moves;
    g.merges = merges;
    g.bonusMoves = bonusMoves;
    g.recordUndo = false;
    return g;
  }

  MergeGame._blank(this.level) : n = level.size {
    cells = List.of(level.start);
    rng = SeededRandom(level.seed);
  }

  /// Two-ply lookahead with the real (deterministic) spawn sequence.
  Dir? bestMove() {
    Dir? best;
    var bestScore = double.negativeInfinity;
    for (final d in Dir.values) {
      final g = clone();
      if (!g.move(d)) continue;
      var s = g.heuristic() + (g.score - score) * 0.1;
      if (g.won) s += 1e6;
      var next = double.negativeInfinity;
      for (final d2 in Dir.values) {
        final g2 = g.clone();
        if (!g2.move(d2)) continue;
        final v = g2.heuristic() + (g2.score - g.score) * 0.1 + (g2.won ? 1e5 : 0);
        if (v > next) next = v;
      }
      if (next == double.negativeInfinity) next = -1e4;
      s += next * 0.9;
      if (s > bestScore) {
        bestScore = s;
        best = d;
      }
    }
    return best;
  }

  // ---- Persistence -----------------------------------------------------------------
  String _snap() => '${cells.join(',')}#${rng.state}#$score#$moves#$merges#$bonusMoves';

  void _restore(String s) {
    final p = s.split('#');
    cells = p[0].split(',').map(int.parse).toList();
    rng = SeededRandom.fromState(int.parse(p[1]));
    score = int.parse(p[2]);
    moves = int.parse(p[3]);
    merges = int.parse(p[4]);
    bonusMoves = int.parse(p[5]);
    lastMerged = {};
    lastSpawn = -1;
  }

  String serialize() => _snap();

  static MergeGame restore(MergeLevel l, String s) => MergeGame._blank(l).._restore(s);
}

MergeLevel generateMergeLevel(LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  final d = spec.difficulty;
  final endless = const [GameModeId.endless, GameModeId.timeAttack, GameModeId.zen].contains(spec.mode);
  final size = spec.has('big_board') ? 5 : 4;
  final start = List<int>.filled(size * size, 0);
  if (spec.has('stone')) {
    final stones = 1 + d ~/ 4;
    for (var k = 0; k < stones; k++) {
      // stones never in corners so the board stays playable
      final x = 1 + r.nextInt(size - 2), y = 1 + r.nextInt(size - 2);
      start[y * size + x] = -1;
    }
  }
  var targetExp = 0, targetScore = 0;
  if (!endless) {
    final tiers = [6, 7, 7, 8, 8, 9, 9, 10, 10, 11];
    targetExp = tiers[(d - 1).clamp(0, 9)];
    if (spec.has('stone') && size == 4) targetExp = (targetExp - 1).clamp(6, 10);
    if (r.chance(0.3)) {
      targetScore = (1 << targetExp) * 3;
      targetExp = 0;
    }
    if (spec.levelId > 0 && spec.levelId <= 3 && spec.mode == GameModeId.campaign) {
      targetExp = 5 + spec.levelId; // 64, 128, 256 tutorial targets
      targetScore = 0;
    }
  }
  return MergeLevel(
    size: size,
    start: start,
    targetExp: targetExp,
    targetScore: targetScore,
    moveLimit: 0,
    timeLimit: spec.mode == GameModeId.timeAttack ? 120 : (spec.has('timer') ? 120 + d * 30 : 0),
    seed: spec.seed,
    difficulty: d,
    zen: spec.mode == GameModeId.zen,
  );
}

/// AI play-through used for validation. Returns moves or -1.
int simulateMerge(MergeLevel l, {int cap = 4000}) {
  final g = MergeGame(l)..recordUndo = false;
  while (g.moves < cap) {
    if (g.won) return g.moves;
    final d = g.bestMove();
    if (d == null) return -1;
    g.move(d);
  }
  return g.won ? g.moves : -1;
}
