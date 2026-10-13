import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/game_constants.dart';
import 'package:happiness_threads/main.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/action_card_preview.dart';
import 'package:happiness_threads/ui/widgets/omen_instruction_icons.dart';

import 'helpers/computer_fixtures.dart';
import 'helpers/game_fixtures.dart';

void main() {
  testWidgets('设置右侧直接返回首页，待选牌和游戏进度保存，再进入按隐私流程恢复', (tester) async {
    final storage = ComputerStorage();
    final engine = startGame()..acknowledgePrivacy();
    await tester.pumpWidget(
      HappinessThreadsApp(
        storage: storage,
        restoredState: engine.state,
        computerStorage: ComputerStorage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-rules-dismiss')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-twoPlayer')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已回避，继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('omen-card-1')));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<GamePage>(find.byType(GamePage))
        .controller;
    final before = controller.state.toJson();
    final settings = tester.getRect(
      find.byKey(const ValueKey('settings-button')),
    );
    final home = tester.getRect(
      find.byKey(const ValueKey('return-home-button')),
    );
    expect(home.left, closeTo(settings.right + 8, .01));
    expect(home.top, settings.top);
    await tester.tap(find.byKey(const ValueKey('return-home-button')));
    await tester.pumpAndSettle();
    expect(find.byType(GamePage), findsNothing);
    expect(find.byType(ActionCardPreview), findsNothing);
    expect(find.text('返回模式选择？'), findsNothing);
    expect(find.byKey(const ValueKey('mode-twoPlayer')), findsOneWidget);
    expect(storage.saved!.toJson(), before);
    await tester.tap(find.byKey(const ValueKey('mode-twoPlayer')));
    await tester.pumpAndSettle();
    expect(find.text('已回避，继续'), findsOneWidget);
    final restored = tester.widget<GamePage>(find.byType(GamePage)).controller;
    expect(restored.state.toJson(), before);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('${size.width}五张预览圆角无外框，说明在牌内下半部，不重复啃食次数', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final engine = startGame()..acknowledgePrivacy();
      final controller = GameController(
        storage: ComputerStorage(),
        restoredState: engine.state,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGameTheme(),
          home: GamePage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('已回避，继续'));
      await tester.pumpAndSettle();
      for (final card in GameConstants.omenCards) {
        final hand = find.byKey(ValueKey('omen-card-${card.id}'));
        await tester.ensureVisible(hand);
        await tester.tap(hand);
        await tester.pumpAndSettle();
        final preview = find.byType(ActionCardPreview);
        final bounds = tester.getRect(
          find.byKey(const ValueKey('card-preview-content')),
        );
        final rounded = tester.widget<ClipRRect>(
          find.descendant(
            of: preview,
            matching: find.byKey(ValueKey('action-card-rounded-${card.id}')),
          ),
        );
        expect(
          rounded.borderRadius.resolve(TextDirection.ltr).topLeft.x,
          greaterThan(0),
        );
        expect(
          find.descendant(of: preview, matching: find.byType(Container)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: preview,
            matching: find.text('啃食 ${card.instructions.length} 次'),
          ),
          findsNothing,
        );
        final description = tester.getRect(
          find.byKey(const ValueKey('preview-card-effect')),
        );
        final title = tester.getRect(
          find.byKey(const ValueKey('preview-card-name')),
        );
        expect(description.top, greaterThan(bounds.center.dy));
        expect(title.top, greaterThan(bounds.center.dy));
        expect(description.bottom, lessThanOrEqualTo(bounds.bottom));
        expect(description.left, greaterThanOrEqualTo(bounds.left));
        expect(description.right, lessThanOrEqualTo(bounds.right));
        expect(
          tester
              .widgetList<InfectionMethodIcon>(
                find.descendant(
                  of: preview,
                  matching: find.byType(InfectionMethodIcon),
                ),
              )
              .map((icon) => icon.method),
          card.displayInstructions,
        );
        expect(controller.state.playedOmenIds, isEmpty);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('夜间三个寄生作物下方独立蓝色光晕，交接/后台与白天不泄露身份', (tester) async {
    final engine = startGame()..acknowledgePrivacy();
    final controller = GameController(
      storage: ComputerStorage(),
      restoredState: engine.state,
    );
    await tester.pumpWidget(
      MaterialApp(home: GamePage(controller: controller)),
    );
    await tester.pumpAndSettle();
    Finder glows() => find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key as ValueKey<String>).value.startsWith(
            'accomplice-soil-outline-',
          ),
    );
    expect(glows(), findsNothing);
    await tester.tap(find.text('已回避，继续'));
    await tester.pumpAndSettle();
    expect(glows(), findsNWidgets(3));
    for (final id in [1, 5, 25]) {
      expect(
        find.byKey(ValueKey('accomplice-soil-outline-$id')),
        findsOneWidget,
      );
      final card = find.byKey(ValueKey(id));
      final frame = tester.widget<AnimatedContainer>(find.descendant(of: card, matching: find.byType(AnimatedContainer)).first);
      expect((frame.decoration! as BoxDecoration).boxShadow, isEmpty, reason: '身份蓝光不能填满土地内部');
      final ring = tester.widget<DecoratedBox>(find.byKey(ValueKey('accomplice-soil-outline-'+id.toString())));
      expect((ring.decoration as BoxDecoration).gradient, isNull);
    }
    // 先走真实设备的inactive交接；paused时Flutter已暂停绘制帧。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(glows(), findsNothing, reason: '失焦先遮挡秘密棋盘');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(glows(), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(glows(), findsNothing);
    await tester.tap(find.text('已回避，继续'));
    await tester.pumpAndSettle();
    controller.playOmenCard(1);
    await tester.pumpAndSettle();
    expect(controller.state.phase, GamePhase.accompliceTurn);
    expect(glows(), findsNWidgets(3));
    controller.tapCard(1);
    controller.tapCard(7);
    controller.tapCard(5);
    controller.tapCard(3);
    expect(controller.canSubmitInfection, isTrue);
    controller.submitInfection();
    await tester.pumpAndSettle();
    expect(glows(), findsNothing);
    await tester.tap(find.text('开始行动'));
    await tester.pumpAndSettle();
    expect(glows(), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    expect(tester.takeException(), isNull);
  });
}
