import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'helpers/game_fixtures.dart';

class ClueStorage implements GameStorage {
  GameState? latest;
  @override
  Future<GameState?> load() async => latest;
  @override
  Future<void> save(GameState state) async => latest = state;
}

void main() {
  for (final size in [
    const Size(1024, 600),
    const Size(1280, 800),
    const Size(360, 640),
    const Size(412, 915),
  ]) {
    testWidgets(
      '${size.width.toInt()}×${size.height.toInt()}：两名被标记只执行十一次，线索保持，不卡死',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final storage = ClueStorage();
        final controller = GameController(
          storage: storage,
          restoredState: startHeroTurn().state,
        );
        await tester.pumpWidget(
          MaterialApp(home: GamePage(controller: controller)),
        );
        await tester.pumpAndSettle();
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        final cardSize = tester.getSize(find.byKey(const ValueKey(25)));
        await tap(find.byKey(const ValueKey(1)));
        await tap(find.byKey(const ValueKey(5)));
        await tap(find.text('确认标记'));
        await tap(find.text('已回避，继续'));
        await tap(find.byKey(const ValueKey('omen-card-2')));
        await tap(find.text('打出行动牌'));
        expect(controller.state.requiredInfections, 1);
        expect(find.text('牌面 2 次，本轮执行 1 次'), findsOneWidget);
        expect(find.text('标记线索：本回合有 1 次啃食因标记作废'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '提交啃食'))
              .onPressed,
          isNull,
        );
        await tap(find.byKey(const ValueKey(25)));
        await tap(find.byKey(const ValueKey(10))); // 仅十范围，不需提前指定路线。
        expect(controller.state.pendingInfectionCount, 1);
        expect(controller.state.infectionActions, isEmpty);
        expect(controller.state.girl(10).infectionMethod, isNull);
        expect(find.byKey(const ValueKey('instruction-0')), findsNothing);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '提交啃食'))
              .onPressed,
          isNotNull,
        );
        expect(tester.getSize(find.byKey(const ValueKey(25))), cardSize);
        await tap(find.text('提交啃食'));
        expect(controller.state.phase, GamePhase.heroPrivacy);
        expect(controller.state.round, 2);
        await tap(find.text('开始行动'));
        expect(find.text('第2回合线索：因标记未执行 1 次啃食'), findsOneWidget);
        expect(find.text('啃食2·十'), findsOneWidget);
        expect(controller.state.girl(1).isMonitored, isFalse);
        expect(controller.state.girl(5).isMonitored, isFalse);
        await controller.flushSave();
        final recovered = GameState.fromJson(storage.latest!.toJson());
        expect(recovered.lastRoundSkippedInfections, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }
}
