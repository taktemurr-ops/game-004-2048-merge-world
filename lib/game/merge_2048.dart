import 'dart:math';

enum SlideDirection { left, right, up, down }

class Merge2048 {
  final Random random;
  final int size;
  final List<List<int>> board;
  int score = 0;
  int moves = 0;
  final List<({List<List<int>> tiles, int score, int moves})> _history = [];

  /// JSON-compatible snapshot for a local persistence adapter.
  Map<String, Object> toSnapshot() => {
    'version': 1,
    'board': board.map((row) => List<int>.from(row)).toList(),
    'score': score,
    'moves': moves,
  };

  /// Reject corrupted or unsupported saves instead of loading invalid state.
  factory Merge2048.fromSnapshot(Map<String, dynamic> snapshot,
      {Random? random}) {
    if (snapshot['version'] != 1 ||
        snapshot['score'] is! int || snapshot['score'] < 0 ||
        snapshot['moves'] is! int || snapshot['moves'] < 0) {
      throw const FormatException('Invalid 2048 save metadata.');
    }
    final raw = snapshot['board'];
    if (raw is! List || (raw.length != 4 && raw.length != 5) ||
        raw.any((row) => row is! List ||
            row.length != raw.length ||
            row.any((tile) => tile is! int))) {
      throw const FormatException('Invalid 2048 saved board.');
    }
    final tiles = raw.map((row) => List<int>.from(row as List)).toList();
    final game = Merge2048.fromBoard(tiles, random: random);
    game.score = snapshot['score'] as int;
    game.moves = snapshot['moves'] as int;
    return game;
  }

  bool get canUndo => _history.isNotEmpty;

  bool undo() {
    if (_history.isEmpty) return false;
    final previous = _history.removeLast();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        board[r][c] = previous.tiles[r][c];
      }
    }
    score = previous.score;
    moves = previous.moves;
    return true;
  }

  Merge2048({Random? random, this.size = 4})
      : assert(size == 4 || size == 5),
        random = random ?? Random(),
        board = List.generate(size, (_) => List.filled(size, 0)) {
    spawn();
    spawn();
  }

  Merge2048.fromBoard(List<List<int>> initial, {Random? random})
      : size = initial.length,
        random = random ?? Random(),
        board = List.generate(initial.length, (_) => List.filled(initial.length, 0)) {
    if ((size != 4 && size != 5) || initial.any((r) => r.length != size)) {
      throw ArgumentError('The board must be 4x4 or 5x5.');
    }
    for (var i = 0; i < size; i++) {
      for (var j = 0; j < size; j++) {
        final value = initial[i][j];
        if (value < 0 || (value != 0 && (value & (value - 1)) != 0)) {
          throw ArgumentError('Tiles must be 0 or positive powers of two.');
        }
        board[i][j] = value;
      }
    }
  }

  bool spawn() {
    final empty = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) empty.add((r, c));
      }
    }
    if (empty.isEmpty) return false;
    final cell = empty[random.nextInt(empty.length)];
    board[cell.$1][cell.$2] = random.nextInt(10) == 0 ? 4 : 2;
    return true;
  }

  List<int> mergeLine(List<int> original) {
    final nonzero = original.where((x) => x > 0).toList();
    final result = <int>[];
    for (var i = 0; i < nonzero.length; i++) {
      if (i + 1 < nonzero.length && nonzero[i] == nonzero[i + 1]) {
        final merged = nonzero[i] * 2;
        result.add(merged);
        score += merged;
        i++;
      } else {
        result.add(nonzero[i]);
      }
    }
    while (result.length < size) { result.add(0); }
    return result;
  }

  bool slide(SlideDirection direction, {bool addTile = true}) {
    final before = (tiles: board.map((r) => List<int>.from(r)).toList(),
        score: score, moves: moves);
    var changed = false;
    for (var index = 0; index < size; index++) {
      final coords = <(int, int)>[];
      for (var offset = 0; offset < size; offset++) {
        switch (direction) {
          case SlideDirection.left: coords.add((index, offset)); break;
          case SlideDirection.right: coords.add((index, size - 1 - offset)); break;
          case SlideDirection.up: coords.add((offset, index)); break;
          case SlideDirection.down: coords.add((size - 1 - offset, index)); break;
        }
      }
      final old = coords.map((p) => board[p.$1][p.$2]).toList();
      final next = mergeLine(old);
      for (var j = 0; j < size; j++) {
        if (old[j] != next[j]) changed = true;
        board[coords[j].$1][coords[j].$2] = next[j];
      }
    }
    if (changed) {
      _history.add(before);
      if (_history.length > 20) _history.removeAt(0);
      moves++;
      if (addTile) spawn();
    }
    return changed;
  }

  /// Returns legal swipe directions without mutating the board or score.
  /// Useful for accessible hints and automated move validation.
  List<SlideDirection> get availableMoves {
    final legal = <SlideDirection>[];
    for (final direction in SlideDirection.values) {
      var possible = false;
      for (var index = 0; index < size && !possible; index++) {
        final line = <int>[];
        for (var offset = 0; offset < size; offset++) {
          switch (direction) {
            case SlideDirection.left:
              line.add(board[index][offset]);
            case SlideDirection.right:
              line.add(board[index][size - 1 - offset]);
            case SlideDirection.up:
              line.add(board[offset][index]);
            case SlideDirection.down:
              line.add(board[size - 1 - offset][index]);
          }
        }
        final compact = line.where((value) => value != 0).toList();
        final merged = <int>[];
        for (var i = 0; i < compact.length; i++) {
          if (i + 1 < compact.length && compact[i] == compact[i + 1]) {
            merged.add(compact[i] * 2);
            i++;
          } else {
            merged.add(compact[i]);
          }
        }
        while (merged.length < size) {
          merged.add(0);
        }
        for (var i = 0; i < size; i++) {
          if (merged[i] != line[i]) {
            possible = true;
            break;
          }
        }
      }
      if (possible) legal.add(direction);
    }
    return legal;
  }

  /// Free, deterministic hint: favor the legal move with the highest immediate
  /// merge score. Never mutates the live board or consumes a rewarded ad.
  /// Returns null when no legal move exists.
  SlideDirection? get suggestedMove {
    SlideDirection? best;
    var bestGain = -1;
    for (final direction in availableMoves) {
      final copy = Merge2048.fromBoard(
        board.map((row) => List<int>.from(row)).toList(),
      );
      copy.slide(direction, addTile: false);
      if (copy.score > bestGain) {
        bestGain = copy.score;
        best = direction;
      }
    }
    return best;
  }

  bool get won => board.expand((r) => r).any((n) => n >= 2048);

  bool get gameOver {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 0) return false;
        if (r < size - 1 && board[r][c] == board[r + 1][c]) return false;
        if (c < size - 1 && board[r][c] == board[r][c + 1]) return false;
      }
    }
    return true;
  }
}
