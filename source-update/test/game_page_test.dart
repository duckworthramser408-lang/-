import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/widgets/action_card_hand.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';
import 'helpers/game_fixtures.dart';

class WidgetStorage implements GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState state) async {}
}

void main() {
  for (final size in [
    const Size(1024, 600),
    const Size(1280, 800),
    const Size(360, 640),
    const Size(412, 915),
  ]) {
    testWidgets(
      '${size.width.toInt()}×${size.height.toInt()}：行动先行、蓝光隐私、标记取消与完整回合失效',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = GameController(storage: WidgetStorage());
        await tester.pumpWidget(
          MaterialApp(home: GamePage(controller: controller)),
        );
        await tester.pumpAndSettle();
        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await tester.pumpAndSettle();
        }

        GirlCardView card(int id) => tester.widget(find.byKey(ValueKey(id)));
        expect(find.text('戴夫请闭眼，不要观看屏幕！贪吃虫正在选择3个寄生作物'), findsOneWidget);
        expect(find.byType(GirlCardView), findsNothing);
        await tap(find.text('已回避，继续'));
        expect(find.byType(GirlCardView), findsNWidgets(25));
        expect(find.text('啃食0·初始'), findsOneWidget);
        expect(find.text('作物01'), findsNothing);
        FilledButton button(String text) =>
            tester.widget(find.widgetWithText(FilledButton, text));
        expect(button('确认寄生作物').onPressed, isNull);
        await tap(find.byKey(const ValueKey(13)));
        expect(controller.state.selectedIds, isEmpty);
        await tap(find.byKey(const ValueKey(1)));
        expect(card(1).identitySelection, isTrue);
        await tap(find.byKey(const ValueKey(1)));
        expect(card(1).identitySelection, isFalse);
        for (final id in [1, 5, 25]) {
          await tap(find.byKey(ValueKey(id)));
        }
        expect(button('确认寄生作物').onPressed, isNotNull);
        await tap(find.text('确认寄生作物'));
        expect(find.byType(GirlCardView), findsNothing);
        await tap(find.text('已回避，继续'));
        expect(controller.state.phase, GamePhase.chooseOmen);
        expect(card(1).identitySelection, isFalse);
        expect(card(1).accompliceHighlight, isTrue);
        expect(card(1).revealedAccomplice, isFalse);
        final originalCardSize = tester.getSize(find.byKey(const ValueKey(1)));
        expect(button('打出行动牌').onPressed, isNull);
        await tap(find.byKey(const ValueKey(7)));
        expect(controller.state.infectionActions, isEmpty);
        await tap(find.byKey(const ValueKey('omen-card-1')));
        expect(find.byType(ActionCardImage), findsNWidgets(6));
        await tap(find.text('打出行动牌'));
        expect(find.byType(ActionCardHand), findsOneWidget);
        expect(controller.state.omen.label, '十＋环');
        expect(tester.getSize(find.byKey(const ValueKey(1))), originalCardSize);
        Future<void> plan(int index, int center, int target) async {
          await tap(find.byKey(ValueKey(center)));
          await tap(find.byKey(ValueKey(target)));
        }

        // 先执行“十”再执行“环”，验证卡面顺序不是执行顺序。
        await plan(1, 5, 3);
        await plan(0, 1, 7);
        expect(controller.state.girl(7).isAlive, isTrue);
        expect(button('提交啃食').onPressed, isNotNull);
        await tap(find.text('提交啃食'));
        expect(controller.state.round, 1);
        expect(controller.state.phase, GamePhase.heroPrivacy);
        expect(find.text('轮到戴夫行动'), findsOneWidget);
        expect(find.byType(GirlCardView), findsNothing);
        await tap(find.text('开始行动'));
        expect(find.text('啃食1·环'), findsOneWidget);
        expect(find.text('啃食1·十'), findsOneWidget);
        expect(card(1).accompliceHighlight, isFalse);
        await tap(find.byKey(const ValueKey(13)));
        expect(controller.state.selectedIds, isEmpty);
        await tap(find.byKey(const ValueKey(1)));
        expect(find.text('待标记1'), findsOneWidget);
        expect(controller.state.girl(1).isMonitored, isFalse);
        await tap(find.byKey(const ValueKey(1)));
        expect(find.text('待标记1'), findsNothing);
        await tap(find.byKey(const ValueKey(1)));
        await tap(find.text('确认标记'));
        expect(controller.state.phase, GamePhase.nightPrivacy);
        expect(controller.state.girl(1).isMonitored, isTrue);
        expect(controller.state.girl(1).isMonitored, isTrue);
        expect(find.byType(GirlCardView), findsNothing);
        await tap(find.text('已回避，继续'));
        expect(card(1).accompliceHighlight, isTrue);
        expect(card(1).girl.isMonitored, isTrue);
        expect(
          tester
              .widget<InkWell>(find.byKey(const ValueKey('omen-card-1')))
              .onTap,
          isNull,
        );
        await tap(find.byKey(const ValueKey('omen-card-2')));
        await tap(find.text('打出行动牌'));
        await plan(0, 5, 9);
        await plan(1, 25, 20);
        await tap(find.text('提交啃食'));
        expect(controller.state.round, 2);
        expect(controller.state.girl(1).isMonitored, isFalse);
        await tap(find.text('开始行动'));
        expect(find.text('标记1'), findsOneWidget);
        expect(card(1).accompliceHighlight, isFalse);
        expect(card(1).girl.surveillanceMarks.single.isActive, isFalse);
        for (final id in [1, 5, 25]) {
          await tap(find.byKey(ValueKey(id)));
        }
        expect(controller.state.winner, isNull);
        await tap(find.text('确认标记'));
        expect(controller.state.phase, GamePhase.gameOver);
        expect(controller.state.winner, Winner.hero);
        expect(controller.state.playedOmenIds, [1, 2]);
        expect(find.text('戴夫获胜！'), findsOneWidget);
        expect(find.text('入夜！戴夫请回避视线，贪吃虫选择本轮啃食目标'), findsNothing);
        expect(tester.takeException(), isNull);
        await controller.flushSave();
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }
  testWidgets('恢复已打出的秘密行动阶段：确认隐私前不展示蓝光或临时目标', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final engine = startGame();
    engine.acknowledgePrivacy();
    playRoundOmen(engine);
    engine.selectCenter(1);
    engine.tapCard(7);
    final controller = GameController(
      storage: WidgetStorage(),
      restoredState: GameState.fromJson(engine.state.toJson()),
    );
    await tester.pumpWidget(
      MaterialApp(home: GamePage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GirlCardView), findsNothing);
    controller.removeInfection(0);
    expect(controller.state.pendingInfectionCount, 1);
    expect(controller.state.infectionActions, isEmpty);
    await tester.tap(find.text('已回避，继续'));
    await tester.pumpAndSettle();
    expect(controller.state.selectedIds, {7});
    expect(
      tester
          .widget<GirlCardView>(find.byKey(const ValueKey(1)))
          .accompliceHighlight,
      isTrue,
    );
    expect(
      tester
          .widget<GirlCardView>(find.byKey(const ValueKey(7)))
          .temporarySelection,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
