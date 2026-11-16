import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_004_2048_merge_world/main.dart';

void main() {
  testWidgets('2048 Merge World initial screen renders on a phone', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MergeWorldApp());
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('2048 Merge World'), findsOneWidget);
  });
}
