import 'package:flutter/material.dart';
import 'game/merge_2048.dart';

void main() => runApp(const MergeWorldApp());

class MergeWorldApp extends StatelessWidget {
  const MergeWorldApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '2048 Merge World',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const MergeScreen(),
  );
}

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  Merge2048 game = Merge2048();
  Offset? gestureStart;

  void move(SlideDirection direction) => setState(() {
    game.slide(direction);
  });

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
    while (value > 2) { value ~/= 2; index++; }
    return shades[index % shades.length];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('2048 Merge World'),
      actions: [IconButton(
        tooltip: 'New game',
        onPressed: () => setState(() => game = Merge2048()),
        icon: const Icon(Icons.refresh),
      )],
    ),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(padding: const EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Score: ${game.score}    Moves: ${game.moves}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          GestureDetector(
            onPanStart: (d) => gestureStart = d.localPosition,
            onPanEnd: (_) => gestureStart = null,
            onPanUpdate: (d) {
              if (gestureStart == null) return;
              final delta = d.localPosition - gestureStart!;
              if (delta.distance < 42) return;
              if (delta.dx.abs() > delta.dy.abs()) {
                move(delta.dx > 0 ? SlideDirection.right : SlideDirection.left);
              } else {
                move(delta.dy > 0 ? SlideDirection.down : SlideDirection.up);
              }
              gestureStart = null;
            },
            child: AspectRatio(aspectRatio: 1, child: Column(
              children: List.generate(4, (r) => Expanded(child: Row(
                children: List.generate(4, (c) {
                  final value = game.board[r][c];
                  return Expanded(child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tileColor(value), borderRadius: BorderRadius.circular(12)),
                      child: Center(child: Text(value == 0 ? '' : '$value',
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold,
                          color: value <= 8 ? Colors.black87 : Colors.white))),
                    )));
                }),
              ))),
            )),
          ),
          const SizedBox(height: 16),
          Text(game.gameOver ? 'Game over. Start a new round.'
            : game.won ? '2048 reached! Keep playing.' : 'Swipe to merge matching numbers.',
            textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            IconButton.filledTonal(onPressed: () => move(SlideDirection.left), icon: const Icon(Icons.arrow_back)),
            IconButton.filledTonal(onPressed: () => move(SlideDirection.up), icon: const Icon(Icons.arrow_upward)),
            IconButton.filledTonal(onPressed: () => move(SlideDirection.down), icon: const Icon(Icons.arrow_downward)),
            IconButton.filledTonal(onPressed: () => move(SlideDirection.right), icon: const Icon(Icons.arrow_forward)),
          ]),
        ])),
      ),
    ))),
  );
}
