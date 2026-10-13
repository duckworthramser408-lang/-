import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/ui/crop_touch_controller.dart';
import 'package:happiness_threads/ui/farm_scene_geometry.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/action_card_preview.dart';
import 'package:happiness_threads/audio/action_sound_controller.dart';
import 'helpers/game_fixtures.dart';
import 'helpers/computer_fixtures.dart';

void main() {
  test('快速跨过整行与多指触摸：补齐途经作物且释放一指不影响另一指', () {
    final motion = CropTouchController();
    const size = Size(360, 640);
    Offset center(int id) => FarmSceneGeometry.plotRect(id, size).center;
    motion.touch(1, center(1), size);
    motion.touch(2, center(25), size);
    motion.touch(1, center(5), size);
    expect(motion.swept, {1, 2, 3, 4, 5});
    expect(motion.held, {5, 25});
    motion.release(1, size);
    expect(motion.held, {25});
    motion.reset(); expect(motion.held, isEmpty); motion.dispose();
  });

  for (final count in [0, 1, 2, 3]) {
    test('确认$count枚标记原子结束白天、仅发布保存最终状态，旧schema可恢复', () async {
      final storage = ComputerStorage();
      final controller = GameController(storage: storage, restoredState: startHeroTurn().state);
      for (final id in [8, 9, 10].take(count)) { controller.tapCard(id); }
      final phases = <GamePhase>[];
      controller.addListener(() => phases.add(controller.state.phase));
      controller.submitSurveillance();
      expect(controller.state.phase, GamePhase.nightPrivacy);
      expect(controller.state.round, 2);
      expect(phases, everyElement(GamePhase.nightPrivacy));
      for (final id in [8, 9, 10].take(count)) {
        expect(controller.state.girl(id).monitoredInRound(1), isTrue);
      }
      await controller.flushSave();
      expect(GameState.fromJson(storage.saved!.toJson()).phase, GamePhase.nightPrivacy);
      final after = controller.state;
      controller.submitSurveillance(); expect(controller.state, same(after));
      controller.dispose();
    });
  }
  test('确认全部来源胜利优先，第六白天未全中直接虫胜，不进入第七夜', () {
    final all = startHeroTurn();
    for (final id in [1, 5, 25]) { all.tapCard(id); }
    all.confirmHeroTurn();
    expect(all.state.winner, Winner.hero);
    final last = startGame();
    for (var round = 1; round <= 6; round++) {
      infectThisRound(last); last.acknowledgePrivacy();
      if (round < 6) last.confirmHeroTurn();
    }
    last.tapCard(8); last.confirmHeroTurn();
    expect(last.state.winner, Winner.accomplices);
    expect(last.state.round, 6);
  });

  testWidgets('点击与高速划过抬起作物，固定土地/游戏选择不随滑动改变，松手落回与后台清理', (tester) async {
    tester.view.physicalSize = const Size(360, 640); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = GameController(storage: ComputerStorage(), restoredState: startHeroTurn().state);
    await tester.pumpWidget(MaterialApp(theme: buildGameTheme(), home: GamePage(controller: controller)));
    await tester.pumpAndSettle();
    final plot = find.byKey(const ValueKey('farm-plot-8'));
    final original = tester.getRect(plot);
    final first = tester.getCenter(find.byKey(const ValueKey('farm-plot-6')));
    final last = tester.getCenter(find.byKey(const ValueKey('farm-plot-10')));
    final gesture = await tester.startGesture(first);
    await gesture.moveTo(last); await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<Transform>(find.byKey(const ValueKey('crop-lift-8'))).transform.storage[13], lessThan(0));
    expect(tester.getRect(plot), original);
    await gesture.up(); await tester.pumpAndSettle();
    expect(controller.state.selectedIds, isEmpty);
    expect(tester.widget<Transform>(find.byKey(const ValueKey('crop-lift-8'))).transform.storage[13], 0);
    await tester.tap(plot); await tester.pump(const Duration(milliseconds: 60));
    expect(controller.state.selectedIds, {8});
    expect(tester.widget<Transform>(find.byKey(const ValueKey('crop-lift-8'))).transform.storage[13], lessThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive); await tester.pump();
    expect(tester.widget<Transform>(find.byKey(const ValueKey('crop-lift-8'))).transform.storage[13], 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink()); controller.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('预览点击下压与两侧光点不消费牌；仅成功出牌消失时叮一次', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(ActionSoundController.channel, (call) async { calls.add(call.method); return null; });
    final controller = GameController(storage: ComputerStorage(), restoredState: (startGame()..acknowledgePrivacy()).state);
    controller.dismissResumePrivacy();
    await tester.pumpWidget(MaterialApp(theme: buildGameTheme(), home: GamePage(controller: controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('omen-card-1'))); await tester.pumpAndSettle();
    final touch = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('card-preview-content'))));
    await tester.pump(const Duration(milliseconds: 110));
    expect(tester.widget<Transform>(find.byKey(const ValueKey('preview-press'))).transform.storage[13], greaterThan(0));
    expect(find.byKey(const ValueKey('preview-touch-sparkles')), findsOneWidget);
    expect(controller.state.phase, GamePhase.chooseOmen);
    expect(controller.state.playedOmenIds, isEmpty);
    expect(calls.where((c) => c == 'play'), isEmpty);
    await touch.up(); await tester.pumpAndSettle();
    await tester.tap(find.text('打出行动牌')); await tester.pump();
    await tester.pump(const Duration(milliseconds: 179));
    expect(calls.where((c) => c == 'play'), isEmpty);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.byType(ActionCardPreview), findsNothing);
    expect(calls.where((c) => c == 'play'), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink()); controller.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(ActionSoundController.channel, null);
    expect(tester.takeException(), isNull);
  });
}
