import 'dart:math';

enum SlideDirection { left, right, up, down }

class Merge2048 {
  final Random random;
  final List<List<int>> board = List.generate(4, (_) => List.filled(4, 0));
  int score = 0;
  int moves = 0;

  Merge2048({Random? random}) : random = random ?? Random() {
    spawn();
    spawn();
  }

  Merge2048.fromBoard(List<List<int>> initial, {Random? random})
      : random = random ?? Random() {
    if (initial.length != 4 || initial.any((r) => r.length != 4)) {
      throw ArgumentError('The board must be 4x4.');
    }
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
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
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
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
    while (result.length < 4) result.add(0);
    return result;
  }

  bool slide(SlideDirection direction, {bool addTile = true}) {
    var changed = false;
    for (var index = 0; index < 4; index++) {
      final coords = <(int, int)>[];
      for (var offset = 0; offset < 4; offset++) {
        switch (direction) {
          case SlideDirection.left: coords.add((index, offset)); break;
          case SlideDirection.right: coords.add((index, 3 - offset)); break;
          case SlideDirection.up: coords.add((offset, index)); break;
          case SlideDirection.down: coords.add((3 - offset, index)); break;
        }
      }
      final old = coords.map((p) => board[p.$1][p.$2]).toList();
      final next = mergeLine(old);
      for (var j = 0; j < 4; j++) {
        if (old[j] != next[j]) changed = true;
        board[coords[j].$1][coords[j].$2] = next[j];
      }
    }
    if (changed) {
      moves++;
      if (addTile) spawn();
    }
    return changed;
  }

  bool get won => board.expand((r) => r).any((n) => n >= 2048);

  bool get gameOver {
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        if (board[r][c] == 0) return false;
        if (r < 3 && board[r][c] == board[r + 1][c]) return false;
        if (c < 3 && board[r][c] == board[r][c + 1]) return false;
      }
    }
    return true;
  }
}
