import 'package:flutter/material.dart';
import 'game/merge_2048.dart';

void main() => runApp(const MergeWorldApp());

class MergeWorldApp extends StatelessWidget {
  const MergeWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2048 Merge World',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const MergeScreen(),
    );
  }
}

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});

  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  Merge2048 game = Merge2048();
  Offset? gestureStart;
  SlideDirection? hint;

  void newGame(int size) => setState(() { game = Merge2048(size: size); hint = null; });

  void move(SlideDirection direction) {
    if (game.gameOver) return;
    setState(() { game.slide(direction); hint = null; });
  }

  Color tileColor(int n) {
    if (n == 0) return const Color(0xFF29374B);
    const shades = <Color>[
      Color(0xFFF4E5BE), Color(0xFFEFCB82), Color(0xFFFFAE6B),
      Color(0xFFFF8261), Color(0xFFF06479), Color(0xFFD95CA5),
      Color(0xFFA27BEF), Color(0xFF63B8E7), Color(0xFF4ECBBA),
      Color(0xFFE3B74B), Color(0xFFF28D4A),
    ];
    var index = 0;
    var value = n;
    while (value > 2) {
      value ~/= 2;
      index++;
    }
    return shades[index % shades.length];
  }

  Widget buildBoard() {
    return GestureDetector(
      onPanStart: (details) => gestureStart = details.localPosition,
      onPanEnd: (_) => gestureStart = null,
      onPanUpdate: (details) {
        if (gestureStart == null) return;
        final delta = details.localPosition - gestureStart!;
        if (delta.distance < 42) return;
        gestureStart = null;
        if (delta.dx.abs() > delta.dy.abs()) {
          move(delta.dx > 0 ? SlideDirection.right : SlideDirection.left);
        } else {
          move(delta.dy > 0 ? SlideDirection.down : SlideDirection.up);
        }
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Column(
          children: List.generate(game.size, (r) {
            return Expanded(
              child: Row(
                children: List.generate(game.size, (c) {
                  final value = game.board[r][c];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tileColor(value),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            value == 0 ? '' : '$value',
                            style: TextStyle(
                              fontSize: game.size == 5 ? 19 : 25,
                              fontWeight: FontWeight.bold,
                              color: value <= 8 ? Colors.black87 : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2048 Merge World'),
        actions: [
          IconButton(
            tooltip: 'New game',
            onPressed: () => newGame(game.size),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Score: ${game.score}    Moves: ${game.moves}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 4, label: Text('4×4')),
                      ButtonSegment(value: 5, label: Text('5×5')),
                    ],
                    selected: {game.size},
                    onSelectionChanged: (sizes) => newGame(sizes.first),
                  ),
                  const SizedBox(height: 12),
                  Flexible(child: buildBoard()),
                  const SizedBox(height: 16),
                  Text(
                    game.gameOver ? 'Game over. Start a new round.'
                      : game.won ? '2048 reached! Keep playing.'
                      : 'Swipe to merge matching numbers.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: game.canUndo
                        ? () => setState(() => game.undo())
                        : null,
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: game.gameOver ? null : () => setState(() => hint = game.suggestedMove),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: const Text('Free hint (no ad required)'),
                  ),
                  if (hint != null) Text('Try: ${hint!.name}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => move(SlideDirection.left),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => move(SlideDirection.up),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => move(SlideDirection.down),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton.filledTonal(
                        onPressed: () => move(SlideDirection.right),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
