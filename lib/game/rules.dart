import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'merge_engine.dart';

class MergeRules extends GameRules<MergeLevel> {
  @override
  String get gameId => 'game-004-2048-merge-world';

  @override
  List<String> get optionalMechanics => const ['stone', 'big_board', 'timer'];

  @override
  List<GameModeId> get modes => const [
        GameModeId.campaign,
        GameModeId.endless,
        GameModeId.timeAttack,
        GameModeId.zen,
        GameModeId.daily,
        GameModeId.weekly,
        GameModeId.challenge,
      ];

  @override
  List<GameStat> get gameStats => const [
        GameStat('merges', 'Birleştirme', 'Merges', scale: 50),
        GameStat('best_tile_2048', '2048 karosu', '2048 tiles'),
        GameStat('swipes', 'Kaydırma', 'Swipes', scale: 100),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('merges', 'merges', [50, 120, 250]),
        MissionTemplate('swipes', 'swipes', [100, 250, 500]),
      ];

  @override
  MergeLevel generate(LevelSpec spec) => generateMergeLevel(spec);

  @override
  Validation validate(MergeLevel l, LevelSpec spec) {
    if (l.start.length != l.size * l.size) return const Validation.fail('size');
    final g = MergeGame(l);
    if (!g.hasMove) return const Validation.fail('dead start');
    if (l.endless) return const Validation.ok();
    final ai = simulateMerge(l);
    if (ai < 0) return const Validation.fail('AI could not reach the goal');
    return Validation.ok(ai);
  }

  MergeLevel finalize(GeneratedLevel<MergeLevel> g) {
    final l = g.puzzle;
    if (l.endless) return l;
    final ai = g.validation.metric;
    final limit = l.difficulty >= 3 ? (ai * (2.2 - l.difficulty * 0.08)).ceil() + 10 : 0;
    return l.withAi(ai, limit);
  }

  static int stars(MergeGame g) {
    if (!g.won) return 0;
    final ai = g.level.aiMoves;
    if (ai <= 0) return 3;
    if (g.moves <= (ai * 1.2).ceil()) return 3;
    if (g.moves <= (ai * 1.6).ceil()) return 2;
    return 1;
  }

  static int endlessStars(int score) => score >= 20000 ? 3 : score >= 6000 ? 2 : score >= 1000 ? 1 : 0;
}

GameRules createRules() => MergeRules();
