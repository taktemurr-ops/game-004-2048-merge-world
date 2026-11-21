import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'merge_engine.dart';
import 'rules.dart';

/// 2048 board: swipe or arrow keys/WASD (web & desktop), undo, hint,
/// hammer, continue after a fail, resume after app kill.
class MergeView extends StatefulWidget {
  final PlayContext ctx;
  const MergeView({super.key, required this.ctx});

  @override
  State<MergeView> createState() => _MergeViewState();
}

class _MergeViewState extends State<MergeView> with RoundClock {
  late MergeGame game;
  final FocusNode _focus = FocusNode();
  Dir? _hint;
  bool _hammer = false;
  int _hints = 0;
  int _undos = 0;
  bool _ended = false;
  int _bestExpReached = 0;

  PlayContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    final level = MergeRules().finalize(ctx.generated as GeneratedLevel<MergeLevel>);
    final snap = ctx.resume['snap'];
    game = snap is String ? MergeGame.restore(level, snap) : MergeGame(level);
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _bestExpReached = game.maxExp;
    startClock(initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0, limit: level.timeLimit);
  }

  @override
  void dispose() {
    stopClock();
    _focus.dispose();
    super.dispose();
  }

  @override
  void onTimeUp() => _end(game.level.endless ? game.score > 0 : game.won);

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints});

  void _swipe(Dir d) {
    if (_ended || _hammer) return;
    if (!game.move(d)) {
      ctx.sfx(Sfx.error);
      return;
    }
    _hint = null;
    if (game.lastMerged.isNotEmpty) {
      ctx.sfx(game.lastMerged.length > 1 ? Sfx.combo : Sfx.clear);
    } else {
      ctx.sfx(Sfx.place);
    }
    if (game.maxExp > _bestExpReached) _bestExpReached = game.maxExp;
    setState(() {});
    _persist();
    _check();
  }

  Future<void> _check() async {
    if (game.won) {
      _end(true);
      return;
    }
    if (game.lost) {
      if (game.level.endless) {
        _end(game.score > 0);
        return;
      }
      clockPaused = true;
      final again = await ctx.requestContinue();
      clockPaused = false;
      if (!mounted) return;
      if (again) {
        setState(game.rescue);
        _persist();
      } else {
        _end(false);
      }
    }
  }

  void _end(bool won) {
    if (_ended) return;
    _ended = true;
    stopClock();
    final stars = game.level.endless ? MergeRules.endlessStars(game.score) : MergeRules.stars(game);
    ctx.finish(RoundResult(
      won: won,
      score: game.score,
      stars: won ? stars.clamp(1, 3) : 0,
      seconds: seconds,
      moves: game.moves,
      hintsUsed: _hints,
      undosUsed: _undos,
      gameStats: {
        'merges': game.merges,
        'swipes': game.moves,
        'best_tile_2048': _bestExpReached >= 11 ? 1 : 0,
      },
    ));
  }

  Future<void> _useHint() async {
    final d = game.bestMove();
    if (d == null) return;
    if (!await ctx.requestHint()) return;
    _hints++;
    setState(() => _hint = d);
  }

  Future<void> _toggleHammer() async {
    if (_hammer) {
      setState(() => _hammer = false);
      return;
    }
    if (!await ctx.requestBooster()) return;
    setState(() => _hammer = true);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    Dir? d;
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.keyW) d = Dir.up;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.keyS) d = Dir.down;
    if (k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.keyA) d = Dir.left;
    if (k == LogicalKeyboardKey.arrowRight || k == LogicalKeyboardKey.keyD) d = Dir.right;
    if (d == null) return KeyEventResult.ignored;
    _swipe(d);
    return KeyEventResult.handled;
  }

  static const _tileColors = [
    Color(0xFFEEE4DA), Color(0xFFEDE0C8), Color(0xFFF2B179), Color(0xFFF59563),
    Color(0xFFF67C5F), Color(0xFFF65E3B), Color(0xFFEDCF72), Color(0xFFEDCC61),
    Color(0xFFEDC850), Color(0xFFEDC53F), Color(0xFFEDC22E), Color(0xFF3C3A32),
    Color(0xFF6A4C93), Color(0xFF1982C4), Color(0xFF8AC926), Color(0xFFFF595E),
  ];

  @override
  Widget build(BuildContext context) {
    final t = ctx.t;
    final l = game.level;
    final goal = l.targetExp > 0
        ? '${t('goal')}: ${1 << l.targetExp}'
        : (l.targetScore > 0 ? '${t('goal')}: ${l.targetScore}' : '${t('best')}: ${1 << (_bestExpReached.clamp(1, 30))}');
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(children: [
        PlayHud(items: [
          (Icons.flag, goal),
          (Icons.star, '${t('score')}: ${game.score}'),
          if (game.movesLeft >= 0) (Icons.swipe, '${t('moves_left')}: ${game.movesLeft}'),
          (Icons.timer, timeText),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            final side = (c.maxWidth < c.maxHeight ? c.maxWidth : c.maxHeight) - 24;
            final cell = side / game.n;
            return Center(
              child: GestureDetector(
                onPanEnd: (d) {
                  final v = d.velocity.pixelsPerSecond;
                  if (v.distance < 120) return;
                  if (v.dx.abs() > v.dy.abs()) {
                    _swipe(v.dx > 0 ? Dir.right : Dir.left);
                  } else {
                    _swipe(v.dy > 0 ? Dir.down : Dir.up);
                  }
                },
                child: Container(
                  width: side,
                  height: side,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBADA0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(children: [
                    for (var i = 0; i < game.cells.length; i++) _tile(i, cell - 8 / game.n),
                    if (_hint != null)
                      Center(
                        child: Icon(
                          switch (_hint!) {
                            Dir.up => Icons.arrow_upward,
                            Dir.down => Icons.arrow_downward,
                            Dir.left => Icons.arrow_back,
                            Dir.right => Icons.arrow_forward,
                          },
                          size: side * 0.4,
                          color: Colors.yellowAccent.withValues(alpha: 0.85),
                        ),
                      ),
                  ]),
                ),
              ),
            );
          }),
        ),
        BoosterBar(buttons: [
          BoosterButton(Icons.lightbulb, t('hint'), _useHint),
          BoosterButton(Icons.undo, t('undo'), game.canUndo
              ? () {
                  setState(() {
                    game.undo();
                    _undos++;
                  });
                  _persist();
                }
              : null),
          BoosterButton(Icons.gavel, 'Hammer', _toggleHammer, active: _hammer),
        ]),
      ]),
    );
  }

  Widget _tile(int i, double cell) {
    final x = i % game.n, y = i ~/ game.n;
    final v = game.cells[i];
    Widget child;
    if (v == -1) {
      child = Container(
        decoration: BoxDecoration(color: const Color(0xFF5D5D5D), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.block, color: Colors.white54),
      );
    } else if (v == 0) {
      child = Container(
        decoration: BoxDecoration(color: const Color(0xFFCDC1B4), borderRadius: BorderRadius.circular(8)),
      );
    } else {
      final value = 1 << v;
      final color = _tileColors[(v - 1).clamp(0, _tileColors.length - 1)];
      final fg = v <= 2 ? const Color(0xFF776E65) : Colors.white;
      final text = value >= 1000000 ? '${value ~/ 1000000}M' : value >= 100000 ? '${value ~/ 1000}K' : '$value';
      child = AnimatedScale(
        scale: game.lastMerged.contains(i) || game.lastSpawn == i ? 1.0 : 1.0,
        duration: Duration(milliseconds: ctx.reducedMotion ? 0 : 120),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: game.lastMerged.contains(i) && !ctx.reducedMotion
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 32)),
            ),
          ),
        ),
      );
    }
    return Positioned(
      left: x * cell + 4,
      top: y * cell + 4,
      width: cell - 6,
      height: cell - 6,
      child: Semantics(
        label: v > 0 ? '${1 << v}' : (v == -1 ? 'stone' : 'empty'),
        child: GestureDetector(
          onTap: _hammer && v > 0
              ? () {
                  if (game.hammer(i)) {
                    ctx.sfx(Sfx.clear);
                    setState(() => _hammer = false);
                    _persist();
                  }
                }
              : null,
          child: child,
        ),
      ),
    );
  }
}
