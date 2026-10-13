import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/farm_scene_geometry.dart';
import 'package:happiness_threads/ui/game_night_style.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';
import 'package:happiness_threads/ui/widgets/worm_walkway.dart';

class _HintStorage implements GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState state) async {}
}

void main() {
  test('六种手机的25块土地等大，比上一版每块土壤更大，且预留独立虫轨道', () {
    for (final scene in [
      const Size(320, 528),
      const Size(360, 600),
      const Size(375, 627),
      const Size(390, 804),
      const Size(412, 875),
      const Size(360, 600),
    ]) {
      final oldFit = applyBoxFit(BoxFit.contain, const Size(941, 1672), scene);
      final oldPlotSide = 128 * oldFit.destination.width / 941;
      final first = FarmSceneGeometry.tileRect(1, scene);
      for (var id = 1; id <= 25; id++) {
        final tile = FarmSceneGeometry.tileRect(id, scene);
        final plot = FarmSceneGeometry.plotRect(id, scene);
        expect(tile.width, closeTo(first.width, 0.0000001));
        expect(tile.height, closeTo(first.height, 0.0000001));
        expect(plot.width, greaterThan(oldPlotSide));
        expect(tile.overlaps(FarmSceneGeometry.wormTrackRect(scene)), isFalse);
      }
      expect(
        FarmSceneGeometry.fieldRect(scene).bottom,
        lessThanOrEqualTo(
          FarmSceneGeometry.wormTrackRect(scene).top -
              FarmSceneGeometry.trackClearance +
              .001,
        ),
      );
    }
  });

  testWidgets('首个寄生阶段黑夜，五种按钮闪光，整牌并集允许按目标自动匹配路线', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    final controller = GameController(storage: _HintStorage());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: GamePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    Finder glow(String label) => find.byKey(ValueKey('button-glow-$label'));
    ColorFilter tint() => tester
        .widget<ColorFiltered>(find.byKey(const ValueKey('farm-scene-tint')))
        .colorFilter;
    expect(tint(), GameNightStyle.scene);
    expect(find.byType(WormWalkway), findsOneWidget);
    await tap(find.text('已回避，继续'));
    expect(find.byType(GirlCardView), findsNWidgets(25));
    expect(tint(), GameNightStyle.scene);
    expect(glow('确认寄生作物'), findsNothing);
    for (final id in [1, 5, 25]) {
      await tap(find.byKey(ValueKey(id)));
    }
    expect(glow('确认寄生作物'), findsOneWidget);
    final beforePulse = tester.widget<AnimatedOpacity>(glow('确认寄生作物')).opacity;
    final beforeMotion = controller.state;
    await tester.pump(const Duration(milliseconds: 2800));
    expect(
      tester.widget<AnimatedOpacity>(glow('确认寄生作物')).opacity,
      isNot(beforePulse),
    );
    expect(controller.state, same(beforeMotion));
    await tap(find.text('确认寄生作物'));
    await tap(find.text('已回避，继续'));
    expect(glow('打出行动牌'), findsNothing);
    await tap(find.byKey(const ValueKey('omen-card-1')));
    expect(glow('打出行动牌'), findsOneWidget);
    await tap(find.text('打出行动牌'));
    expect(find.byKey(const ValueKey('range-hint-2')), findsNothing);
    await tap(find.byKey(const ValueKey(1)));
    for (final id in [2, 3, 4, 6, 7, 11, 16, 21]) {
      expect(find.byKey(ValueKey('range-hint-$id')), findsOneWidget);
    }
    for (final id in [1, 5, 13, 25]) {
      expect(find.byKey(ValueKey('range-hint-$id')), findsNothing);
    }
    final beforeRangePulse = tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('range-hint-3')))
        .opacity;
    await tester.pump(const Duration(milliseconds: 2800));
    expect(
      tester
          .widget<AnimatedOpacity>(find.byKey(const ValueKey('range-hint-3')))
          .opacity,
      isNot(beforeRangePulse),
    );
    await tap(find.byKey(const ValueKey(3))); // 并集内仅十目标，自动接受且不显示结论。
    expect(controller.state.infectionActions, isEmpty);
    expect(controller.state.pendingInfectionCount, 1);
    expect(controller.state.girl(3).infectionMethod, isNull);
    expect(find.byKey(const ValueKey('instruction-1')), findsNothing);
    expect(find.byKey(const ValueKey('range-hint-3')), findsNothing);
    await tap(find.byKey(const ValueKey(5)));
    await tap(find.byKey(const ValueKey(4)));
    expect(glow('提交啃食'), findsOneWidget);
    await tap(find.text('提交啃食'));
    expect(controller.state.phase, GamePhase.heroPrivacy);
    expect(tint(), isNot(GameNightStyle.scene));
    expect(find.byType(WormWalkway), findsNothing);
    await tap(find.text('开始行动'));
    expect(glow('确认标记'), findsOneWidget);
    expect(glow('结束戴夫行动'), findsNothing);
    await tap(find.byKey(const ValueKey(9)));
    expect(glow('确认标记'), findsOneWidget);
    expect(glow('结束戴夫行动'), findsNothing);
    await tap(find.text('确认标记'));
    expect(glow('确认标记'), findsNothing);
    expect(glow('结束戴夫行动'), findsNothing);
    expect(find.byKey(const ValueKey('range-hint-9')), findsNothing);
    expect(tint(), GameNightStyle.scene);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump(const Duration(seconds: 4));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
