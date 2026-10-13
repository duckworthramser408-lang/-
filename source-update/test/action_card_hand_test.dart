import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/game/game_engine.dart';
import 'package:happiness_threads/game/infection_route_resolver.dart';
import 'package:happiness_threads/game_constants.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/models/infection_selection.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/action_card_artwork.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/action_card_hand.dart';
import 'package:happiness_threads/ui/widgets/action_card_preview.dart';
import 'package:happiness_threads/ui/widgets/worm_walkway.dart';

import 'helpers/game_fixtures.dart';

class _Storage implements GameStorage {
  GameState? saved;
  @override
  Future<GameState?> load() async => saved;
  @override
  Future<void> save(GameState state) async => saved = state;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<GameController> _mount(
  WidgetTester tester, {
  Size size = const Size(360, 640),
  GameEngine? engine,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
  final night = engine ?? startGame();
  if (night.state.phase == GamePhase.nightPrivacy) night.acknowledgePrivacy();
  final controller = GameController(
    storage: _Storage(),
    restoredState: night.state,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGameTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: GamePage(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  await _tap(tester, find.text('已回避，继续'));
  return controller;
}

Future<void> _dispose(WidgetTester tester, GameController controller) async {
  await controller.flushSave();
  await tester.pumpWidget(const SizedBox.shrink());
  controller.dispose();
  expect(tester.takeException(), isNull);
}

void main() {
  test('五张图对应原类型，环十两张用同一原图但保持独立ID', () {
    expect(ActionCardArtwork.paths.keys.toList(), [1, 2, 3, 4, 5]);
    final first = File(ActionCardArtwork.paths[1]!).readAsBytesSync();
    expect(File(ActionCardArtwork.paths[2]!).readAsBytesSync(), first);
    for (final path in ActionCardArtwork.paths.values) {
      expect(File(path).lengthSync(), greaterThan(1000000));
    }
    final engine = startGame()..acknowledgePrivacy();
    engine.selectOmen(1);
    engine.playOmen();
    expect(engine.state.playedOmenIds, [1]);
    // 当前阶段不可再选择，第二张在下一夜仍是独立可用手牌。
    engine.toggleOmenSelection(2);
    expect(engine.state.playedOmenId, 1);
    expect(engine.state.availableOmenCards.map((c) => c.id), [2, 3, 4, 5]);
  });

  test('重叠默认按新图十环；内部编号、强制仅环/十与旧显式存档保持', () {
    for (final id in [1, 2]) {
      final card = GameConstants.omenById(id);
      expect(card.instructions, [InfectionMethod.ring, InfectionMethod.cross]);
      expect(card.displayInstructions, [
        InfectionMethod.cross,
        InfectionMethod.ring,
      ]);
      final result = InfectionRouteResolver.resolve(card, [
        const InfectionSelection(centerId: 1, targetId: 2),
        const InfectionSelection(centerId: 25, targetId: 24),
      ])!;
      expect(result.map((a) => a.method), [
        InfectionMethod.cross,
        InfectionMethod.ring,
      ]);
      expect(result.map((a) => a.instructionIndex), [1, 0]);
      final forced = InfectionRouteResolver.resolve(card, [
        const InfectionSelection(centerId: 1, targetId: 7),
        const InfectionSelection(centerId: 25, targetId: 24),
      ])!;
      expect(forced.map((a) => a.method), [
        InfectionMethod.ring,
        InfectionMethod.cross,
      ]);
    }
    final explicit = startGame()..acknowledgePrivacy();
    explicit.selectOmen(1);
    explicit.playOmen();
    explicit.selectInstruction(0);
    explicit.selectCenter(1);
    explicit.tapCard(7);
    final recovered = GameState.fromJson(explicit.state.toJson());
    expect(recovered.infectionActions.single.instructionIndex, 0);
    expect(recovered.infectionActions.single.method, InfectionMethod.ring);
  });

  test('选择/取消可存档恢复，禁用阶段和不存在手牌不改变状态', () {
    final engine = startGame()..acknowledgePrivacy();
    engine.toggleOmenSelection(1);
    expect(engine.canPlayOmen, isTrue);
    engine.toggleOmenSelection(1);
    expect(engine.canPlayOmen, isFalse);
    expect(GameState.fromJson(engine.state.toJson()).selectedOmenId, isNull);
    final before = engine.state;
    engine.toggleOmenSelection(8);
    expect(engine.state, same(before));
    engine.toggleOmenSelection(2);
    engine.playOmen();
    final played = engine.state;
    engine.toggleOmenSelection(2);
    expect(engine.state, same(played));
  });

  testWidgets('直接显示手牌：预览不出牌，再点原牌或空白取消待选', (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _mount(tester);
    expect(find.byType(ActionCardHand), findsOneWidget);
    expect(find.byKey(const ValueKey('select-action-card')), findsNothing);
    expect(find.byType(Draggable<int>), findsNothing);
    expect(find.byType(ActionCardImage), findsNWidgets(5));
    final before = controller.state.toJson()..remove('selectedOmenId');
    await _tap(tester, find.byKey(const ValueKey('omen-card-1')));
    expect(controller.state.toJson()..remove('selectedOmenId'), before);
    expect(controller.state.playedOmenIds, isEmpty);
    expect(find.byType(ActionCardPreview), findsOneWidget);
    expect(find.text('行动牌 · 十＋环'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedScale>(find.byKey(const ValueKey('card-scale-1')))
          .scale,
      1.04,
    );
    final image = tester.widget<ActionCardImage>(
      find.byKey(const ValueKey('preview-high-resolution-image')),
    );
    expect(image.highResolution, isTrue);
    await _tap(tester, find.byKey(const ValueKey('omen-card-1')));
    expect(controller.state.selectedOmenId, isNull);
    expect(find.byType(ActionCardPreview), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('omen-card-2')));
    await tester.tapAt(
      Offset(6, tester.getRect(find.byType(ActionCardPreview)).center.dy),
    );
    await tester.pumpAndSettle();
    expect(controller.state.selectedOmenId, isNull);
    expect(controller.state.phase, GamePhase.chooseOmen);
    expect(find.byType(ActionCardPreview), findsNothing);
    await _dispose(tester, controller);
  });

  testWidgets('横滑与向上拖动不会出牌，点击仍可切换预览', (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _mount(tester);
    await tester.drag(
      find.byKey(const ValueKey('action-hand-scroll')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(controller.state.selectedOmenId, isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('omen-card-5')));
    await tester.drag(
      find.byKey(const ValueKey('omen-card-5')),
      const Offset(0, -90),
    );
    await tester.pumpAndSettle();
    expect(controller.state.phase, GamePhase.chooseOmen);
    expect(controller.state.playedOmenIds, isEmpty);
    await _tap(tester, find.byKey(const ValueKey('omen-card-5')));
    expect(controller.state.selectedOmenId, 5);
    expect(find.text('行动牌 · 环＋十＋十'), findsOneWidget);
    await _dispose(tester, controller);
  });

  testWidgets('出牌后手牌仍并列，只将所选牌变暗；预览消失后才显示有限光点', (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _mount(tester);
    await _tap(tester, find.byKey(const ValueKey('omen-card-2')));
    await tester.tap(find.text('打出行动牌'));
    await tester.pump();
    expect(controller.state.playedOmenIds, [2]);
    expect(controller.state.phase, GamePhase.accompliceTurn);
    expect(controller.state.inferInfectionRoutes, isTrue);
    expect(find.byType(ActionCardPreview), findsOneWidget);
    expect(find.byType(CardPlayParticles), findsNothing);
    await tester.pump(const Duration(milliseconds: 190));
    expect(find.byType(ActionCardPreview), findsNothing);
    expect(find.byType(CardPlayParticles), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(CardPlayParticles), findsOneWidget);
    final burst = tester.widget<CardPlayParticles>(
      find.byType(CardPlayParticles),
    );
    expect(burst.animation.value, closeTo(.3, .01));
    await tester.pump(const Duration(milliseconds: 1380));
    expect(find.byType(CardPlayParticles), findsOneWidget);
    expect(burst.animation.value, closeTo(.99, .01));
    await tester.pump(const Duration(milliseconds: 20));
    expect(burst.animation.value, 1);
    await tester.pump(const Duration(milliseconds: 16)); // 完成后下一帧删除已透明的层。
    expect(find.byType(CardPlayParticles), findsNothing);
    expect(find.byType(ActionCardHand), findsOneWidget);
    expect(find.byType(PlayedActionCard), findsNothing);
    expect(find.byType(ActionCardImage), findsNWidgets(5));
    final dim = tester.widget<AnimatedOpacity>(
      find
          .descendant(
            of: find.byKey(const ValueKey('omen-card-2')),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(dim.opacity, .48);
    final played = controller.state;
    await tester.tap(
      find.byKey(const ValueKey('omen-card-2')),
      warnIfMissed: false,
    );
    controller.playOmenCard(1);
    await tester.pumpAndSettle();
    expect(controller.state, same(played));
    await _dispose(tester, controller);
  });

  testWidgets('未选卡牌时确认按钮禁用，无出牌与光点', (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _mount(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '打出行动牌'),
    );
    expect(button.onPressed, isNull);
    final before = controller.state;
    await tester.tap(find.text('打出行动牌'));
    await tester.pumpAndSettle();
    expect(controller.state, same(before));
    expect(find.byType(CardPlayParticles), findsNothing);
    await _dispose(tester, controller);
  });

  testWidgets('后台隐藏预览与光点，恢复仍要求原隐私确认', (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _mount(tester);
    await _tap(tester, find.byKey(const ValueKey('omen-card-1')));
    final before = controller.state.toJson();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(find.byType(ActionCardPreview), findsNothing);
    expect(find.byType(ActionCardHand), findsNothing);
    expect(find.byType(CardPlayParticles), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('隐私提示'), findsOneWidget);
    await _tap(tester, find.text('已回避，继续'));
    expect(controller.state.toJson(), before);
    await _dispose(tester, controller);
  });

  testWidgets('白天带回合展示已完成牌，下一夜恢复剩余手牌', (tester) async {
    addTearDown(tester.view.reset);
    final day = startHeroTurn();
    final controller = GameController(
      storage: _Storage(),
      restoredState: day.state,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: GamePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ActionCardHand), findsNothing);
    expect(
      tester.widget<PlayedActionCard>(find.byType(PlayedActionCard)).card.id,
      day.state.playedOmenId,
    );
    expect(find.byType(ActionCardImage), findsOneWidget);
    final panel = find.byKey(const ValueKey('action-hand-panel'));
    expect(
      find.descendant(of: panel, matching: find.text('第 1 回合')),
      findsOneWidget,
    );
    await _tap(tester, find.text('确认标记'));
    await _tap(tester, find.text('已回避，继续'));
    expect(controller.state.round, 2);
    expect(find.byType(ActionCardHand), findsOneWidget);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('omen-card-1'))).onTap,
      isNull,
    );
    await _dispose(tester, controller);
  });

  testWidgets('左上设置包含规则、切换模式和重置，关闭/取消不改变进度', (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _mount(tester);
    final before = controller.state.toJson();
    final music = tester.getRect(
      find.byKey(const ValueKey('background-music-button')),
    );
    final settings = tester.getRect(
      find.byKey(const ValueKey('settings-button')),
    );
    expect(settings.top, music.top);
    expect(settings.left, greaterThan(music.right));
    expect(find.text('规则说明'), findsNothing);
    expect(find.text('重置游戏'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('settings-button')));
    expect(find.text('规则说明'), findsOneWidget);
    expect(find.text('切换模式'), findsOneWidget);
    expect(find.text('重置游戏'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('game-rules-button')));
    await _tap(tester, find.text('关闭说明'));
    expect(controller.state.toJson(), before);
    await _tap(tester, find.byKey(const ValueKey('settings-button')));
    await _tap(tester, find.byKey(const ValueKey('reset-game-button')));
    expect(find.text('重新开始本局？'), findsOneWidget);
    await _tap(tester, find.text('取消'));
    expect(controller.state.toJson(), before);
    await _dispose(tester, controller);
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(375, 667),
    const Size(390, 844),
    const Size(412, 915),
    const Size(480, 800),
  ]) {
    testWidgets(
      '${size.width.toInt()}×${size.height.toInt()}手牌始终在下1/3可见区，土地/虫轨道不移动',
      (tester) async {
        addTearDown(tester.view.reset);
        final controller = await _mount(tester, size: size);
        final board = tester.getRect(
          find.byKey(const ValueKey('board-region')),
        );
        final plot = tester.getRect(find.byKey(const ValueKey('farm-plot-13')));
        final worm = tester.getRect(find.byType(WormWalkway));
        final operation = tester.getRect(
          find.byKey(const ValueKey('operation-region')),
        );
        final strip = tester.getRect(
          find.byKey(const ValueKey('action-hand-scroll')),
        );
        expect(strip.top, greaterThanOrEqualTo(operation.top));
        expect(strip.bottom, lessThanOrEqualTo(operation.bottom));
        expect(strip.height, greaterThan(35));
        expect(operation.height * 2, closeTo(board.height, .01));
        expect(
          tester.getRect(find.byKey(const ValueKey('farm-plot-13'))),
          plot,
        );
        expect(tester.getRect(find.byType(WormWalkway)), worm);
        expect(worm.bottom, lessThanOrEqualTo(operation.top));
        await _tap(tester, find.byKey(const ValueKey('omen-card-5')));
        expect(controller.state.selectedOmenId, 5);
        final preview = tester.getRect(
          find.byKey(const ValueKey('card-preview-content')),
        );
        expect(preview.bottom, lessThan(operation.top));
        expect(preview.left, greaterThanOrEqualTo(0));
        expect(preview.right, lessThanOrEqualTo(size.width));
        final controls = tester.getRect(
          find.byKey(const ValueKey('operation-controls')),
        );
        final round = tester.getRect(
          find.byKey(const ValueKey('round-display-area')),
        );
        expect(round.right, closeTo(controls.right - 10, .01));
        expect(round.top, greaterThanOrEqualTo(controls.top));
        await _dispose(tester, controller);
      },
    );
  }

  testWidgets('小屏放大文字仍能横滑选择，不溢出操作栏', (tester) async {
    addTearDown(tester.view.reset);
    final controller = await _mount(
      tester,
      size: const Size(320, 568),
      textScale: 1.5,
    );
    await _tap(tester, find.byKey(const ValueKey('omen-card-4')));
    expect(controller.state.selectedOmenId, 4);
    await _dispose(tester, controller);
  });

  testWidgets('已消费牌保留暗色且不可点击，第六夜仅复用第五张原卡面', (tester) async {
    addTearDown(tester.view.reset);
    final night2 = startHeroTurn()..endHeroTurn();
    final controller = await _mount(tester, engine: night2);
    expect(
      tester.widget<InkWell>(find.byKey(const ValueKey('omen-card-1'))).onTap,
      isNull,
    );
    expect(find.byType(ActionCardImage), findsNWidgets(5));
    expect(find.byKey(const ValueKey('omen-card-2')), findsOneWidget);
    final before = controller.state.toJson();
    await tester.tap(
      find.byKey(const ValueKey('omen-card-1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(controller.state.toJson(), before);
    expect(find.byType(ActionCardPreview), findsNothing);
    await _dispose(tester, controller);
    final night6 = startGame();
    for (var round = 1; round <= 5; round++) {
      infectThisRound(night6);
      night6.acknowledgePrivacy();
      night6.endHeroTurn();
    }
    final last = await _mount(tester, engine: night6);
    expect(find.byType(ActionCardImage), findsOneWidget);
    expect(find.byKey(const ValueKey('omen-card-5')), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('omen-card-5')));
    await _tap(tester, find.text('打出行动牌'));
    expect(last.state.round, 6);
    expect(last.state.playedOmenId, 5);
    final lastDim = tester.widget<AnimatedOpacity>(
      find
          .descendant(
            of: find.byKey(const ValueKey('omen-card-5')),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(lastDim.opacity, .48);
    await _dispose(tester, last);
  });

  testWidgets('图片路径异常显示指示兜底，页面无异常', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 90,
            height: 160,
            child: ActionCardImage(
              card: GameConstants.omenById(3),
              imagePath: 'assets/action_cards/missing.png',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('action-card-fallback-3')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
