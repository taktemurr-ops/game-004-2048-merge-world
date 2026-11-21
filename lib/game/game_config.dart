import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'merge_view.dart';
import 'rules.dart';

final gameConfig = GameConfig(
  gameId: 'game-004-2048-merge-world',
  title: const ['2048 Birleştirme Dünyası', '2048 Merge World', '2048 Merge-Welt', 'Mundo 2048', 'Monde 2048'],
  tagline: const [
    'Kaydır, birleştir, 2048 ve ötesine ulaş!',
    'Swipe, merge, reach 2048 and beyond!',
    'Wischen, verbinden, 2048 erreichen!',
    '¡Desliza, combina y llega a 2048!',
    'Glissez, fusionnez, atteignez 2048 !',
  ],
  seedColor: const Color(0xFFEDC22E),
  icon: Icons.filter_9_plus,
  rules: MergeRules(),
  buildPlay: (ctx) => MergeView(ctx: ctx),
  tutorial: const [
    TutorialStep(Icons.swipe, [
      'Kaydırınca bütün karolar o yöne kayar. Bilgisayar ve web\'de ok tuşları / WASD da çalışır.',
      'Swipe to slide every tile. Arrow keys / WASD also work on web and desktop.',
      'Wische, um alle Kacheln zu schieben. Pfeiltasten/WASD gehen auch.',
      'Desliza para mover todas las fichas. También flechas/WASD.',
      'Glissez pour déplacer les tuiles. Flèches/WASD aussi.',
    ]),
    TutorialStep(Icons.add, [
      'Aynı sayılar çarpışınca birleşir: 2+2=4, 4+4=8 ...',
      'Equal numbers merge when they collide: 2+2=4, 4+4=8 ...',
      'Gleiche Zahlen verschmelzen: 2+2=4 ...',
      'Los números iguales se combinan: 2+2=4 ...',
      'Les nombres égaux fusionnent : 2+2=4 ...',
    ]),
    TutorialStep(Icons.flag, [
      'Bölüm hedefine (karo ya da skor) ulaş. Taş bloklar hareket etmez.',
      'Reach the level goal (tile or score). Stone blocks never move.',
      'Erreiche das Ziel. Steine bewegen sich nie.',
      'Alcanza el objetivo. Las piedras no se mueven.',
      'Atteignez l\'objectif. Les pierres ne bougent pas.',
    ]),
  ],
);
