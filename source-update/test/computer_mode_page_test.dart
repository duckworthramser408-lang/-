import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/game_constants.dart';
import 'package:happiness_threads/main.dart';
import 'package:happiness_threads/models/game_mode.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/widgets/action_card_hand.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';

import 'helpers/computer_fixtures.dart';
import 'helpers/game_fixtures.dart';

class UnreadableComputerStorage extends ComputerStorage {
  @override
  Future<GameState?> load() async =>
      throw const FormatException('Invalid save');
}

Future<void> openModeMenu(
  WidgetTester tester, {
  required ComputerStorage computer,
  ComputerStorage? twoPlayer,
}) async {
  await tester.pumpWidget(
    HappinessThreadsApp(
      storage: twoPlayer ?? ComputerStorage(),
      computerStorage: computer,
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('game-rules-dialog')), findsOneWidget);
  expect(find.byType(GamePage), findsNothing);
  await tester.tap(find.byKey(const ValueKey('game-rules-dismiss')));
  await tester.pumpAndSettle();
  expect(find.text('选择游戏模式'), findsNothing);
  expect(find.byKey(const ValueKey('mode-twoPlayer')), findsOneWidget);
  expect(find.byKey(const ValueKey('mode-twoPlayer')), findsOneWidget);
  expect(find.byKey(const ValueKey('mode-computer')), findsOneWidget);
  expect(find.byType(GamePage), findsNothing);
}

Future<GameController> enterComputer(
  WidgetTester tester,
  ComputerStorage storage,
) async {
  await openModeMenu(tester, computer: storage);
  await tester.ensureVisible(find.byKey(const ValueKey('mode-computer')));
  await tester.tap(find.byKey(const ValueKey('mode-computer')));
  await tester.pump();
  await tester.pump();
  return tester.widget<GamePage>(find.byType(GamePage)).controller;
}

Future<void> finishComputerTurn(WidgetTester tester) async {
  await tester.pump(GameConstants.computerTurnDelay);
  await tester.pumpAndSettle();
}

Future<void> startDetective(WidgetTester tester) async {
  expect(find.text('轮到戴夫行动'), findsOneWidget);
  expect(find.text('隐私提示'), findsNothing);
  await tester.tap(find.text('开始行动'));
  await tester.pumpAndSettle();
}

Finder card(int id) => find.byWidgetPredicate(
  (widget) => widget is GirlCardView && widget.girl.id == id,
);

void expectPublicCards(WidgetTester tester) {
  expect(find.byType(GirlCardView), findsNWidgets(25));
  for (final view in tester.widgetList<GirlCardView>(
    find.byType(GirlCardView),
  )) {
    expect(view.accompliceHighlight, isFalse);
    expect(view.selectedCenter, isFalse);
    expect(view.identitySelection, isFalse);
    expect(view.temporarySelection, isFalse);
    expect(view.infectionPlanLabel, isNull);
    expect(view.revealedAccomplice, isFalse);
  }
  expect(find.text('提交啃食'), findsNothing);
  expect(find.text('确认寄生作物'), findsNothing);
  expect(find.text('打出行动牌'), findsNothing);
  expect(find.byType(ChoiceChip), findsNothing);
  expect(find.byType(ActionCardHand), findsNothing);
  expect(find.byType(PlayedActionHistory), findsOneWidget);
  final completed = tester
      .widget<GamePage>(find.byType(GamePage))
      .controller
      .state
      .lastCompletedInfectionRound!;
  expect(find.byType(PlayedActionCard), findsNWidgets(completed));
  expect(find.byKey(const ValueKey('select-action-card')), findsNothing);
}

Future<void> returnToMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('settings-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('return-mode-selection')));
  await tester.pumpAndSettle();
  expect(find.text('返回模式选择？'), findsOneWidget);
  await tester.tap(find.text('返回'));
  await tester.pumpAndSettle();
  expect(find.text('选择游戏模式'), findsNothing);
  expect(find.byKey(const ValueKey('mode-twoPlayer')), findsOneWidget);
}

void main() {
  for (final (size, scale) in [
    (const Size(320, 568), 1.3),
    (const Size(412, 915), 1.0),
  ]) {
    testWidgets('${size.width.toInt()}：规则→模式→电脑秘密首轮→戴夫，保持地块布局且无身份泄露', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final storage = ComputerStorage();
      final controller = await enterComputer(tester, storage);
      expect(controller.mode, GameMode.computer);
      expect(controller.state.phase, GamePhase.openingPrivacy);
      expect(find.byKey(const ValueKey('computer-curtain')), findsOneWidget);
      expect(find.byType(GirlCardView), findsNothing);
      expect(find.text('隐私提示'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(storage.snapshots, isEmpty);
      controller.tapCard(2);
      controller.acknowledgePrivacy();
      expect(controller.state.selectedIds, isEmpty);
      await finishComputerTurn(tester);
      expect(controller.state.round, 1);
      expect(controller.state.phase, GamePhase.heroPrivacy);
      expect(find.byType(GirlCardView), findsNothing);
      await startDetective(tester);
      expectPublicCards(tester);
      expect(find.text('确认标记'), findsOneWidget);
      expect(find.text('反馈q2855863989陈'), findsOneWidget);
      final safeHeight = size.height - 40;
      final panel = tester.getRect(
        find.byKey(const ValueKey('operation-region')),
      );
      expect(panel.height, closeTo(safeHeight / 3, 0.1));
      for (final view in find.byType(GirlCardView).evaluate()) {
        final rect = tester.getRect(find.byWidget(view.widget));
        expect(rect.width / rect.height, closeTo(1, 0.001));
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.bottom, lessThanOrEqualTo(panel.top));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('戴夫可取消待标记，2名来源被标记只行动1次，电脑过程隐藏且公开线索准确', (tester) async {
    final storage = ComputerStorage()..saved = startHeroTurn().state;
    final controller = await enterComputer(tester, storage);
    expectPublicCards(tester);
    await tester.tap(card(1));
    await tester.pump();
    await tester.tap(card(1));
    await tester.pump();
    expect(controller.state.selectedIds, isEmpty);
    for (final id in [1, 5]) {
      await tester.tap(card(id));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认标记'));
    await tester.pump();
    expect(controller.state.actionableAccompliceCount, 1);
    await tester.pump();
    expect(controller.isComputerTurn, isTrue);
    expect(find.byType(GirlCardView), findsNothing);
    expect(find.byKey(const ValueKey('computer-curtain')), findsOneWidget);
    expect(find.text('已回避，继续'), findsNothing);
    expect(find.text('提交啃食'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    controller.selectCenter(1);
    controller.tapCard(2);
    expect(controller.state.infectionActions, isEmpty);
    await finishComputerTurn(tester);
    final newInfections = controller.state.girls.where(
      (g) => g.infectionRound == 2,
    );
    expect(newInfections.length, 1);
    expect(newInfections.single.infectionCenterId, 25);
    final omen = GameConstants.omenById(controller.state.playedOmenIds.last);
    expect(
      controller.state.lastRoundSkippedInfections,
      omen.instructions.length - 1,
    );
    expect(controller.state.girl(1).monitoredInRound(1), isFalse);
    expect(controller.state.girl(5).monitoredInRound(1), isFalse);
    await startDetective(tester);
    expectPublicCards(tester);
    expect(
      find.text('第2回合线索：因标记未执行 ${omen.instructions.length - 1} 次啃食'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<PlayedActionCard>(find.byType(PlayedActionCard).first)
          .card
          .id,
      controller.state.playedOmenIds[1],
    );
    expect(
      GameState.fromJson(controller.state.toJson()).toJson(),
      controller.state.toJson(),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('三名当前来源同时被标记立即结束，不再啃食，仅结算后揭晓身份', (tester) async {
    final storage = ComputerStorage()..saved = startHeroTurn().state;
    final controller = await enterComputer(tester, storage);
    expectPublicCards(tester);
    final before = controller.state.playedOmenIds.toList();
    for (final id in controller.state.accompliceIds) {
      await tester.tap(card(id));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认标记'));
    await tester.pumpAndSettle();
    expect(controller.state.winner, Winner.hero);
    expect(controller.isComputerTurn, isFalse);
    expect(find.text('戴夫获胜！'), findsOneWidget);
    expect(find.text('寄生作物揭晓'), findsOneWidget);
    final revealed = tester
        .widgetList<GirlCardView>(find.byType(GirlCardView))
        .where((view) => view.revealedAccomplice)
        .toList();
    expect(revealed.length, 6);
    expect(
      revealed.map((view) => view.girl.id).toSet(),
      controller.state.accompliceIds,
    );
    await tester.pump(GameConstants.computerTurnDelay);
    expect(controller.state.playedOmenIds, before);
    await tester.tap(find.text('查看棋盘'));
    await tester.pumpAndSettle();
    expect(find.byType(GirlCardView), findsNWidgets(25));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('模式切换各自恢复进度，双人模式保留原隐私选人，人机不覆盖双人存档', (tester) async {
    final twoPlayer = ComputerStorage()
      ..saved = GameState.initial().copyWith(
        phase: GamePhase.chooseAccomplices,
        selectedIds: {2},
      );
    final twoPlayerBefore = twoPlayer.saved!.toJson();
    final computer = ComputerStorage()..saved = startHeroTurn().state;
    await openModeMenu(tester, computer: computer, twoPlayer: twoPlayer);
    await tester.tap(find.byKey(const ValueKey('mode-computer')));
    await tester.pumpAndSettle();
    final first = tester.widget<GamePage>(find.byType(GamePage)).controller;
    await tester.tap(card(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认标记'));
    await tester.pumpAndSettle();
    final computerBefore = first.state.toJson();
    await returnToMenu(tester);
    expect(computer.saved!.toJson(), computerBefore);
    expect(twoPlayer.saved!.toJson(), twoPlayerBefore);
    await tester.tap(find.byKey(const ValueKey('mode-twoPlayer')));
    await tester.pumpAndSettle();
    expect(find.text('隐私提示'), findsOneWidget);
    expect(find.byType(GirlCardView), findsNothing);
    await tester.tap(find.text('已回避，继续'));
    await tester.pumpAndSettle();
    final dual = tester.widget<GamePage>(find.byType(GamePage)).controller;
    expect(dual.mode, GameMode.twoPlayer);
    expect(dual.state.selectedIds, {2});
    expect(find.text('确认寄生作物'), findsOneWidget);
    await returnToMenu(tester);
    await tester.tap(find.byKey(const ValueKey('mode-computer')));
    await tester.pumpAndSettle();
    final second = tester.widget<GamePage>(find.byType(GamePage)).controller;
    expect(second.state.toJson(), computerBefore);
    expectPublicCards(tester);
    expect(twoPlayer.saved!.toJson(), twoPlayerBefore);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('人机坏存档不自动重开或覆盖，可返回选择双人模式', (tester) async {
    final computer = UnreadableComputerStorage();
    await openModeMenu(tester, computer: computer);
    await tester.tap(find.byKey(const ValueKey('mode-computer')));
    await tester.pumpAndSettle();
    expect(find.text('本地存档无法读取，原存档尚未覆盖。'), findsOneWidget);
    expect(find.byType(GamePage), findsNothing);
    await finishComputerTurn(tester);
    expect(computer.snapshots, isEmpty);
    await tester.tap(find.text('返回模式选择'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-twoPlayer')));
    await tester.pumpAndSettle();
    expect(find.text('隐私提示'), findsOneWidget);
    expect(computer.snapshots, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('来源范围无目标时电脑完成剩余啃食，公布结果而不泄露来源，可重置', (tester) async {
    final computer = ComputerStorage()..saved = blockedComputerRound();
    final controller = await enterComputer(tester, computer);
    expect(find.byType(GirlCardView), findsNothing);
    await finishComputerTurn(tester);
    expect(controller.computerError, isNull);
    expect(controller.state.winner, isNull);
    expect(controller.state.round, 6);
    expect(controller.state.phase, GamePhase.heroPrivacy);
    expect(
      controller.state.girls.where((g) => g.infectionRound == 6),
      hasLength(2),
    );
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('寄生作物揭晓'), findsNothing);
    expect(find.text('重试电脑行动'), findsNothing);
    await startDetective(tester);
    expectPublicCards(tester);
    expect(find.text('第6回合线索：标记作废 0 次，范围无目标作废 1 次'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置游戏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置'));
    await finishComputerTurn(tester);
    expect(controller.computerError, isNull);
    expect(controller.state.round, 1);
    expect(controller.state.accompliceIds.length, 3);
    await startDetective(tester);
    expectPublicCards(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
