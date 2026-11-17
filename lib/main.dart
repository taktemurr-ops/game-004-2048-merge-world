import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game/merge_2048.dart';
import 'game/merge_mode.dart';
import 'services/merge_progress.dart';
import 'services/merge_text.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MergeWorldApp());
}

class MergeWorldApp extends StatelessWidget {
  const MergeWorldApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: '2048 Merge World',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFC56B),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF10192C),
        ),
        home: const MergeScreen(),
      );
}

enum _Page { home, play, settings, stats }

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> with WidgetsBindingObserver {
  final MergeProgress _progress = MergeProgress();
  _Page _page = _Page.home;
  MergeMode mode = MergeMode.classic;
  Merge2048 game = Merge2048(random: Random(42));
  String locale = 'tr';
  bool highContrast = false;
  bool sound = true;
  bool haptics = true;
  bool hasSave = false;
  bool paused = false;
  bool expired = false;
  bool showWinBanner = false;
  int remainingSeconds = 180;
  int bestScore = 0;
  MergeStatistics stats = const MergeStatistics();
  SlideDirection? hint;
  Offset? gestureStart;
  Timer? _timer;

  String tr(String key) => MergeText.get(locale, key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadPreferences());
  }

  Future<void> _loadPreferences() async {
    try {
      final session = await _progress.readSession();
      final language = await _progress.locale();
      final contrast = await _progress.contrast();
      final soundSetting = await _progress.sound();
      final vibration = await _progress.haptics();
      final statistics = await _progress.statistics();
      if (!mounted) { return; }
      setState(() {
        hasSave = session != null;
        locale = const ['tr', 'en', 'ar'].contains(language) ? language : 'tr';
        highContrast = contrast;
        sound = soundSetting;
        haptics = vibration;
        stats = statistics;
      });
    } catch (_) {
      // A broken preferences provider cannot prevent offline play.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _page == _Page.play) {
      if (mounted) { setState(() => paused = true); }
      _timer?.cancel();
      unawaited(_save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    if (!mode.hasTimer || remainingSeconds <= 0) { return; }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_page != _Page.play || paused || expired || game.gameOver) { return; }
      setState(() {
        remainingSeconds--;
        if (remainingSeconds <= 0) {
          remainingSeconds = 0;
          expired = true;
          paused = true;
          timer.cancel();
        }
      });
      if (remainingSeconds % 10 == 0) { unawaited(_save()); }
    });
  }

  Future<void> _save() async {
    try {
      await _progress.saveSession(MergeSave(
        mode: mode,
        remainingSeconds: remainingSeconds,
        paused: paused,
        gameData: game.toSnapshot(),
      ));
      if (mounted) { setState(() => hasSave = true); }
    } catch (_) { /* Keep the game playable if local storage fails. */ }
  }

  void _start(MergeMode selected) {
    _timer?.cancel();
    setState(() {
      mode = selected;
      final random = selected == MergeMode.daily
          ? Random(dailySeed(DateTime.now())) : Random();
      game = Merge2048(size: selected.boardSize, random: random);
      remainingSeconds = selected.timeLimitSeconds ?? 180;
      paused = false;
      expired = false;
      showWinBanner = false;
      hint = null;
      _page = _Page.play;
    });
    unawaited(_progress.recordRound());
    unawaited(_progress.bestScore(selected).then((value) {
      if (mounted && mode == selected) { setState(() => bestScore = value); }
    }));
    _startTimer();
    unawaited(_save());
  }

  Future<void> _resume() async {
    try {
      final saved = await _progress.readSession();
      if (!mounted) { return; }
      if (saved == null) { _start(MergeMode.classic); return; }
      final restored = Merge2048.fromSnapshot(saved.gameData);
      setState(() {
        game = restored;
        mode = saved.mode;
        remainingSeconds = saved.remainingSeconds;
        paused = false;
        expired = mode.hasTimer && remainingSeconds == 0;
        showWinBanner = false;
        hint = null;
        _page = _Page.play;
      });
      _startTimer();
    } catch (_) {
      if (mounted) { _start(MergeMode.classic); }
    }
  }

  void _home() {
    _timer?.cancel();
    if (_page == _Page.play) { unawaited(_save()); }
    setState(() {
      _page = _Page.home;
      paused = true;
      hint = null;
    });
  }

  void _move(SlideDirection direction) {
    if (_page != _Page.play || paused || expired || game.gameOver) { return; }
    final before = game.board.expand((row) => row).reduce(max);
    final changed = game.slide(direction);
    if (!changed) { return; }
    final after = game.board.expand((row) => row).reduce(max);
    setState(() {
      hint = null;
      if (before < mode.target && after >= mode.target) {
        showWinBanner = true;
      }
    });
    if (haptics) { unawaited(HapticFeedback.selectionClick()); }
    if (sound && after > before) {
      unawaited(SystemSound.play(SystemSoundType.click));
    }
    if (game.score > bestScore) { setState(() => bestScore = game.score); }
    unawaited(_progress.recordMove(mode, game));
    unawaited(_save());
    if (game.gameOver) { _timer?.cancel(); }
  }

  Future<void> _restart() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('new')),
        content: Text(tr('confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr('no'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(tr('yes'))),
        ],
      ),
    );
    if (accepted == true && mounted) { _start(mode); }
  }

  void _undo() {
    if (paused || expired || !game.canUndo) { return; }
    if (game.undo()) {
      setState(() { hint = null; showWinBanner = false; });
      if (mode.hasTimer) { _startTimer(); }
      unawaited(_save());
    }
  }

  void _showHint() {
    if (paused || expired || game.gameOver) { return; }
    setState(() => hint = game.suggestedMove);
  }

  Color _tileColor(int value) {
    if (value == 0) { return const Color(0xFF25384F); }
    if (highContrast) { return value <= 8 ? Colors.yellow : Colors.deepOrange; }
    const palette = [
      Color(0xFFF4E4BE), Color(0xFFFFDA8C), Color(0xFFFFB774),
      Color(0xFFFF9865), Color(0xFFF47B87), Color(0xFFCB75AE),
      Color(0xFF9D85DB), Color(0xFF7BA9EA), Color(0xFF5BCAB7),
      Color(0xFFF5C657), Color(0xFFEDA34D),
    ];
    var position = 0;
    var n = value;
    while (n > 2) { n ~/= 2; position++; }
    return palette[position % palette.length];
  }

  Widget _tile(int row, int column) {
    final value = game.board[row][column];
    return Expanded(child: Padding(
      padding: const EdgeInsets.all(3),
      child: Semantics(
        label: '${row + 1}, ${column + 1}: ${value == 0 ? '-' : value}',
        child: AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            key: ValueKey('tile-$row-$column'),
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: _tileColor(value),
              borderRadius: BorderRadius.circular(9),
              boxShadow: value == 0 ? null : const [
                BoxShadow(blurRadius: 4, offset: Offset(0, 2), color: Colors.black26),
              ],
            ),
            child: Center(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 170),
              child: Text(value == 0 ? '' : '$value', key: ValueKey(value),
                style: TextStyle(
                  color: value <= 8 ? Colors.black87 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: game.size == 5 ? 18 : 24,
                )),
            )),
          ),
        ),
      ),
    ));
  }

  Widget _board() => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) { return KeyEventResult.ignored; }
          final key = event.logicalKey;
          final direction = key == LogicalKeyboardKey.arrowLeft ? SlideDirection.left
              : key == LogicalKeyboardKey.arrowRight ? SlideDirection.right
              : key == LogicalKeyboardKey.arrowUp ? SlideDirection.up
              : key == LogicalKeyboardKey.arrowDown ? SlideDirection.down : null;
          if (direction == null) { return KeyEventResult.ignored; }
          _move(direction);
          return KeyEventResult.handled;
        },
        child: GestureDetector(
          key: const ValueKey('board'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => gestureStart = details.localPosition,
          onPanCancel: () => gestureStart = null,
          onPanEnd: (_) => gestureStart = null,
          onPanUpdate: (details) {
            if (gestureStart == null) { return; }
            final delta = details.localPosition - gestureStart!;
            if (delta.distance < 35) { return; }
            gestureStart = null;
            if (delta.dx.abs() > delta.dy.abs()) {
              _move(delta.dx > 0 ? SlideDirection.right : SlideDirection.left);
            } else {
              _move(delta.dy > 0 ? SlideDirection.down : SlideDirection.up);
            }
          },
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF17263D),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: Column(children: List.generate(game.size, (r) => Expanded(
                  child: Row(children: List.generate(game.size, (c) => _tile(r, c))),
                ))),
              ),
            ),
          ),
        ),
      );

  Widget _action(String label, IconData icon, VoidCallback? onTap,
      {bool primary = false, Key? key}) => primary
      ? FilledButton.icon(key: key, onPressed: onTap,
          icon: Icon(icon), label: Text(label))
      : OutlinedButton.icon(key: key, onPressed: onTap,
          icon: Icon(icon), label: Text(label));

  Widget _menu() => ListView(
        key: const ValueKey('menu'),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        children: [
          const SizedBox(height: 24),
          const Icon(Icons.grid_view_rounded, size: 84, color: Color(0xFFFFD078)),
          const SizedBox(height: 10),
          Text(tr('title'), textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Text(tr('tip'), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          if (hasSave) _action(tr('continue'), Icons.play_arrow, _resume,
              primary: true, key: const ValueKey('continue')),
          for (final m in MergeMode.values)
            Padding(padding: const EdgeInsets.only(top: 8), child: _action(
              tr(m.name), m == MergeMode.timed ? Icons.timer_outlined
                  : m == MergeMode.daily ? Icons.today_outlined
                  : m == MergeMode.zen ? Icons.spa_outlined
                  : m == MergeMode.bigBoard ? Icons.dashboard_outlined
                  : Icons.grid_on_outlined,
              () => _start(m), primary: m == MergeMode.classic && !hasSave,
              key: ValueKey('mode-${m.name}'),
            )),
          const SizedBox(height: 16),
          _action(tr('stats'), Icons.emoji_events_outlined, () async {
            final snapshot = await _progress.statistics();
            if (mounted) { setState(() { stats = snapshot; _page = _Page.stats; }); }
          }),
          _action(tr('settings'), Icons.settings_outlined,
              () => setState(() => _page = _Page.settings)),
        ],
      );

  Widget _play() {
    final disabled = paused || expired || game.gameOver;
    return LayoutBuilder(builder: (context, limits) => ListView(
      key: const ValueKey('play'),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(onPressed: _home, icon: const Icon(Icons.arrow_back),
              tooltip: tr('back')),
          Text(tr(mode.name), style: Theme.of(context).textTheme.titleLarge),
          IconButton(
            onPressed: game.gameOver || expired ? null : () {
              setState(() => paused = !paused);
              unawaited(_save());
            },
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            tooltip: paused ? tr('resume') : tr('pause'),
          ),
        ]),
        Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
          Chip(label: Text('${tr('score')}: ${game.score}')),
          Chip(label: Text('${tr('best')}: $bestScore')),
          Chip(label: Text('${tr('moves')}: ${game.moves}')),
          if (mode.hasTimer) Chip(label: Text(
              '${remainingSeconds ~/ 60}:${(remainingSeconds % 60).toString().padLeft(2, '0')}')),
        ]),
        Text('${tr('target')}: ${mode.target}', textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Center(child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: min(490.0, limits.maxWidth)),
          child: _board(),
        )),
        const SizedBox(height: 15),
        Text(game.gameOver ? tr('lost') : expired ? tr('timeup') :
            showWinBanner ? tr('won') : paused ? tr('pause') : tr('tip'),
            textAlign: TextAlign.center,
            key: const ValueKey('status')),
        if (hint != null) Text('${tr('hintMove')}: ${tr(hint!.name)}',
            textAlign: TextAlign.center, key: const ValueKey('hint-result')),
        const SizedBox(height: 14),
        if (showWinBanner) _action(tr('keepPlaying'), Icons.play_arrow,
            () => setState(() => showWinBanner = false), primary: true),
        if (paused && !expired)
          _action(tr('resume'), Icons.play_arrow, () => setState(() => paused = false),
              primary: true),
        Wrap(alignment: WrapAlignment.center, runSpacing: 8, spacing: 8, children: [
          _action(tr('undo'), Icons.undo, game.canUndo && !expired && !paused ? _undo : null,
              key: const ValueKey('undo')),
          _action(tr('hint'), Icons.lightbulb_outline, disabled ? null : _showHint,
              key: const ValueKey('hint')),
          _action(tr('restart'), Icons.restart_alt, _restart,
              key: const ValueKey('restart')),
        ]),
        const SizedBox(height: 14),
        Wrap(alignment: WrapAlignment.center, runSpacing: 6, spacing: 8, children: [
          IconButton.filledTonal(
            tooltip: tr('left'), onPressed: disabled ? null : () => _move(SlideDirection.left),
            icon: const Icon(Icons.arrow_back), key: const ValueKey('left')),
          IconButton.filledTonal(
            tooltip: tr('up'), onPressed: disabled ? null : () => _move(SlideDirection.up),
            icon: const Icon(Icons.arrow_upward), key: const ValueKey('up')),
          IconButton.filledTonal(
            tooltip: tr('down'), onPressed: disabled ? null : () => _move(SlideDirection.down),
            icon: const Icon(Icons.arrow_downward), key: const ValueKey('down')),
          IconButton.filledTonal(
            tooltip: tr('right'), onPressed: disabled ? null : () => _move(SlideDirection.right),
            icon: const Icon(Icons.arrow_forward), key: const ValueKey('right')),
        ]),
      ],
    ));
  }

  Future<void> _erase() async {
    final yes = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(tr('erase')), content: Text(tr('eraseConfirm')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('no'))),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('yes'))),
      ],
    ));
    if (yes != true) { return; }
    await _progress.erase();
    if (!mounted) { return; }
    _timer?.cancel();
    setState(() {
      hasSave = false;
      bestScore = 0;
      stats = const MergeStatistics();
      _page = _Page.home;
      paused = true;
      locale = 'tr';
      highContrast = false;
      sound = true;
      haptics = true;
    });
  }

  Widget _settings() => ListView(key: const ValueKey('settings'),
    padding: const EdgeInsets.all(18), children: [
      ListTile(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _home),
          title: Text(tr('settings'))),
      Card(child: Column(children: [
        ListTile(title: Text(tr('language')), trailing: DropdownButton<String>(
          value: locale,
          items: const [
            DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'ar', child: Text('العربية')),
          ],
          onChanged: (selected) {
            if (selected != null) {
              setState(() => locale = selected);
              unawaited(_progress.setLocale(selected));
            }
          },
        )),
        SwitchListTile(title: Text(tr('contrast')), value: highContrast,
            onChanged: (value) {
              setState(() => highContrast = value);
              unawaited(_progress.setContrast(value));
            }),
        SwitchListTile(title: Text(tr('sound')), value: sound,
            onChanged: (value) {
              setState(() => sound = value);
              unawaited(_progress.setSound(value));
            }),
        SwitchListTile(title: Text(tr('haptics')), value: haptics,
            onChanged: (value) {
              setState(() => haptics = value);
              unawaited(_progress.setHaptics(value));
            }),
      ])),
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(tr('privacy')), subtitle: Text(tr('privacyBody'))),
        ListTile(leading: const Icon(Icons.delete_forever_outlined),
            title: Text(tr('erase')), onTap: _erase),
      ])),
    ],
  );

  Widget _stats() => ListView(key: const ValueKey('stats'),
    padding: const EdgeInsets.all(18), children: [
      ListTile(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _home),
          title: Text(tr('stats'))),
      Card(child: Column(children: [
        ListTile(title: Text(tr('rounds')), trailing: Text('${stats.rounds}')),
        ListTile(title: Text(tr('totalMoves')), trailing: Text('${stats.totalMoves}')),
        ListTile(title: Text(tr('highestTile')), trailing: Text('${stats.highestTile}')),
      ])),
      for (final m in MergeMode.values)
        FutureBuilder<int>(
          future: _progress.bestScore(m),
          builder: (context, snapshot) => ListTile(
            title: Text(tr(m.name)),
            subtitle: Text(tr('best')),
            trailing: Text('${snapshot.data ?? 0}'),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    child: Scaffold(
      appBar: AppBar(title: Text(_page == _Page.home ? 'Game Studio 100' : tr('title'))),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 670),
        child: switch (_page) {
          _Page.home => _menu(),
          _Page.play => _play(),
          _Page.settings => _settings(),
          _Page.stats => _stats(),
        },
      ))),
    ),
  );
}
