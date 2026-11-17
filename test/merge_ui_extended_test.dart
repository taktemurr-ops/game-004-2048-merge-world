import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:game_004_2048_merge_world/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('start 4x4 mode, directional controls, undo and hints', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const MergeWorldApp());
    await tester.pumpAndSettle();
    expect(find.text('2048 Merge World'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mode-classic')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('board')), findsOneWidget);
    expect(find.byKey(const ValueKey('tile-3-3')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('hint')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('hint-result')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('left')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('board')), findsOneWidget);
  });

  testWidgets('5x5 mode creates 25 accessible tiles', (tester) async {
    await tester.pumpWidget(const MergeWorldApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-bigBoard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tile-4-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('hint')), findsOneWidget);
  });

  testWidgets('settings show offline privacy and all three languages', (tester) async {
    await tester.pumpWidget(const MergeWorldApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayarlar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings')), findsOneWidget);
    expect(find.text('Gizlilik'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget);
  });
}
