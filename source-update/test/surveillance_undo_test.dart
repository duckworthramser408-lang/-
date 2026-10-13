import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_mode.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';

import 'helpers/game_fixtures.dart';

class UndoStorage implements GameStorage {
  GameState? saved;
  @override
  Future<GameState?> load() async => saved;
  @override
  Future<void> save(GameState state) async => saved = state;
}

void main() {
  test('撤销已确认标记归还配额，保留其他待提交选择，不超过三枚', () {
    final engine = startHeroTurn();
    for (final id in [9, 20, 23]) {
      engine.tapCard(id);
    }
    engine.submitSurveillance();
    expect(engine.state.monitorsPlacedThisRound, 3);
    engine.tapCard(24);
    expect(engine.state.selectedIds, isEmpty);
    engine.tapCard(20);
    expect(engine.state.monitorsPlacedThisRound, 2);
    expect(engine.state.girl(20).surveillanceMarks, isEmpty);
    expect(engine.state.selectedIds, isEmpty);
    engine.tapCard(24);
    engine.tapCard(10);
    expect(engine.state.selectedIds, {24});
    engine.tapCard(9);
    expect(engine.state.monitorsPlacedThisRound, 1);
    expect(engine.state.selectedIds, {24});
    expect(engine.canEndHeroTurn, isFalse);
    engine.tapCard(10);
    expect(engine.state.selectedIds, {10, 24});
    engine.submitSurveillance();
    expect(engine.state.monitorsPlacedThisRound, 3);
    expect(engine.state.girls.where((g) => g.isMonitored).map((g) => g.id), [
      10,
      23,
      24,
    ]);
    expect(engine.state.winner, isNull);
    GameState.fromJson(engine.state.toJson());
  });

  test('撤销只移除本轮有效标记，灰色历史保留，同一作物可反复重新确认', () {
    final engine = startHeroTurn();
    engine.tapCard(1);
    engine.submitSurveillance();
    engine.endHeroTurn();
    infectThisRound(engine);
    engine.acknowledgePrivacy();
    expect(engine.state.round, 2);
    final historical = engine.state.girl(1).surveillanceMarks.single;
    expect(historical.isActive, isFalse);
    for (var i = 0; i < 3; i++) {
      engine.tapCard(1);
      engine.submitSurveillance();
      expect(engine.state.girl(1).surveillanceMarks, hasLength(2));
      expect(engine.state.monitorsPlacedThisRound, 1);
      engine.tapCard(1);
      expect(engine.state.girl(1).surveillanceMarks.single, same(historical));
      expect(engine.state.girl(1).isMonitored, isFalse);
      expect(engine.state.monitorsPlacedThisRound, 0);
      expect(engine.state.selectedIds, isEmpty);
      GameState.fromJson(engine.state.toJson());
    }
  });

  test('撤销寄生标记恢复当晚行动能力及配额，剩余被标记虫仍不能行动', () {
    final engine = startHeroTurn();
    engine.tapCard(1);
    engine.tapCard(5);
    engine.submitSurveillance();
    expect(engine.state.actionableAccompliceCount, 1);
    engine.tapCard(5);
    expect(engine.state.actionableAccompliceCount, 2);
    engine.endHeroTurn();
    engine.acknowledgePrivacy();
    engine.selectOmen(5);
    engine.playOmen();
    expect(engine.state.requiredInfections, 2);
    expect(engine.state.skippedInfectionsDueToSurveillance, 1);
    engine.selectCenter(1);
    expect(engine.state.selectedCenterId, isNull);
    engine.selectCenter(5);
    expect(engine.state.selectedCenterId, 5);
    engine.tapCard(9);
    expect(engine.state.infectionActions.single.targetId, 9);
    GameState.fromJson(engine.state.toJson());
  });

  test('结束戴夫行动后标记锁定，入夜、出牌及啃食阶段不能撤销', () {
    final engine = startHeroTurn();
    engine.tapCard(1);
    engine.submitSurveillance();
    engine.endHeroTurn();
    for (var stage = 0; stage < 3; stage++) {
      final before = engine.state;
      engine.tapCard(1);
      expect(engine.state, same(before));
      expect(engine.state.girl(1).monitoredInRound(1), isTrue);
      expect(engine.state.monitorsPlacedThisRound, 0);
      if (stage == 0) engine.acknowledgePrivacy();
      if (stage == 1) {
        engine.selectOmen(2);
        engine.playOmen();
      }
    }
  });

  test('已啃食作物不能放置或撤销，标齐三个寄生作物即时胜利后不能撤销', () {
    final engine = startHeroTurn();
    final before = engine.state;
    engine.tapCard(13);
    engine.tapCard(7);
    expect(engine.state, same(before));
    for (final id in [1, 5, 25]) {
      engine.tapCard(id);
    }
    engine.submitSurveillance();
    expect(engine.state.winner, Winner.hero);
    expect(engine.state.winReason, WinReason.allAccomplicesMonitored);
    expect(engine.state.phase, GamePhase.gameOver);
    final finished = engine.state;
    engine.tapCard(1);
    expect(engine.state, same(finished));
    GameState.fromJson(engine.state.toJson());
  });


  for (final mode in GameMode.values) {
    test('模式恢复旧分批白天可撤销，当前确认直接保存交接并锁定', () async {
      final storage = UndoStorage();
      final engine = startHeroTurn()..tapCard(1)..submitSurveillance();
      final controller = GameController(storage: storage, restoredState: engine.state, mode: mode,
        computerDelay: const Duration(days: 1));
      controller.tapCard(1);
      expect(controller.state.monitorsPlacedThisRound, 0);
      controller.tapCard(9);
      controller.submitSurveillance();
      await controller.flushSave();
      expect(storage.saved!.phase, GamePhase.nightPrivacy);
      expect(storage.saved!.girl(9).monitoredInRound(1), isTrue);
      final snapshot = storage.saved!;
      controller.dispose();
      final restored = GameController(storage: storage,
        restoredState: GameState.fromJson(snapshot.toJson()), mode: mode,
        computerDelay: const Duration(days: 1));
      restored.tapCard(9);
      expect(restored.state.girl(9).monitoredInRound(1), isTrue);
      expect(restored.state.phase, GamePhase.nightPrivacy);
      restored.dispose();
    });
    testWidgets('模式确认前可取消，确认后自动交接，没有单独结束按钮', (tester) async {
      final controller = GameController(storage: UndoStorage(), restoredState: startHeroTurn().state,
        mode: mode, computerDelay: const Duration(days: 1));
      await tester.pumpWidget(MaterialApp(theme: buildGameTheme(), home: GamePage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(1))); await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(1))); await tester.pumpAndSettle();
      expect(controller.state.selectedIds, isEmpty);
      await tester.tap(find.byKey(const ValueKey(1))); await tester.pumpAndSettle();
      await tester.tap(find.text('确认标记')); await tester.pumpAndSettle();
      expect(controller.state.phase, GamePhase.nightPrivacy);
      expect(controller.state.girl(1).monitoredInRound(1), isTrue);
      expect(find.text('结束戴夫行动'), findsNothing);
      expect(find.byType(GirlCardView), findsNothing);
      await controller.flushSave();
      await tester.pumpWidget(const SizedBox.shrink()); controller.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
