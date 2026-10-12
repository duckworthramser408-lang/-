import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_mode.dart';
import 'package:happiness_threads/ui/game_artwork.dart';
import 'package:happiness_threads/ui/game_mode_page.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/mode_motion_controller.dart';
import 'package:happiness_threads/ui/widgets/mode_sticker_scene.dart';

import 'helpers/computer_fixtures.dart';
import 'helpers/game_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var available = true;
  var listens = 0;
  var cancels = 0;
  MockStreamHandlerEventSink? sink;

  setUp(() {
    available = true;
    listens = cancels = 0;
    sink = null;
    messenger.setMockMethodCallHandler(
      ModeMotionController.controlChannel,
      (_) async => available,
    );
    messenger.setMockStreamHandler(
      ModeMotionController.eventChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          listens++;
          sink = events;
        },
        onCancel: (_) {
          cancels++;
          sink = null;
        },
      ),
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      ModeMotionController.controlChannel,
      null,
    );
    messenger.setMockStreamHandler(ModeMotionController.eventChannel, null);
  });

  test('真实事件通道接收方向输入，首样校准、反向摇动、异常加速度限制与停止解绑', () async {
    final motion = ModeMotionController();
    await motion.start();
    await Future<void>.delayed(Duration.zero);
    expect(listens, 1);
    sink!.success([0.0, 9.8]);
    await Future<void>.delayed(Duration.zero);
    expect(motion.target, Offset.zero);
    sink!.success([4.0, 12.0]);
    await Future<void>.delayed(Duration.zero);
    expect(motion.target.dx, lessThan(0));
    expect(motion.target.dy, greaterThan(0));
    sink!.success([-30.0, -30.0]);
    await Future<void>.delayed(Duration.zero);
    expect(motion.target.dx, greaterThan(0));
    expect(motion.target.dy, lessThan(0));
    expect(motion.target.distance, lessThanOrEqualTo(30.000001));
    final previous = motion.target;
    motion.acceptAccelerometerSample([double.nan, 1]);
    motion.acceptAccelerometerSample(['bad']);
    expect(motion.target, previous);
    await motion.stop();
    expect(cancels, 1);
    expect(motion.target, Offset.zero);
    await motion.start();
    await Future<void>.delayed(Duration.zero);
    sink!.success([-3.0, 8.0]);
    await Future<void>.delayed(Duration.zero);
    expect(motion.target, Offset.zero); // 恢复后台后按新握持姿势校准。
    motion.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(cancels, 2);
  });

  test('静止、采样噪声和缓慢倾斜不会托住贴纸，新的摇动才给惯性', () {
    final motion = ModeMotionController();
    motion.acceptAccelerometerSample([0.0, 9.8]);
    for (var i = 0; i < 100; i++) {
      motion.acceptAccelerometerSample([
        i * .01,
        9.8 + (i.isEven ? .02 : -.02),
      ]);
      expect(motion.target, Offset.zero);
    }
    motion.acceptAccelerometerSample([-8, 13]);
    expect(motion.target.distance, greaterThan(2));
    motion.acceptAccelerometerSample([-8, 13]);
    expect(motion.target, Offset.zero);
    motion.dispose();
  });

  test('没有传感器、平台插件缺失和平台报错均保持静态，不阻塞进入模式', () async {
    for (final failure in [0, 1, 2]) {
      messenger.setMockMethodCallHandler(ModeMotionController.controlChannel, (
        _,
      ) async {
        if (failure == 1) throw MissingPluginException();
        if (failure == 2) throw PlatformException(code: 'unavailable');
        return false;
      });
      final motion = ModeMotionController();
      await motion.start();
      expect(motion.target, Offset.zero);
      expect(listens, 0);
      motion.dispose();
    }
  });

  test('离页先于异步可用性返回，不残留监听或通知', () async {
    final ready = Completer<bool>();
    messenger.setMockMethodCallHandler(
      ModeMotionController.controlChannel,
      (_) => ready.future,
    );
    final motion = ModeMotionController();
    final pending = motion.start();
    await Future<void>.delayed(Duration.zero);
    motion.dispose();
    ready.complete(true);
    await pending;
    expect(listens, 0);
  });

  testWidgets('25贴纸全屏自由运动、停止摇动继续落堆，后台暂停/恢复、离页取消', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final motion = ModeMotionController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ModeStickerScene(motionController: motion)),
      ),
    );
    await tester.pumpAndSettle();
    expect(listens, 1);
    final sticker = find.byKey(const ValueKey('mode-sticker-8'));
    final original = tester.getRect(sticker);
    // 通道收发已在上面的测试覆盖；此处使用相同公开输入方法驱动逐帧动画。
    motion.acceptAccelerometerSample([0.0, 9.8]);
    motion.acceptAccelerometerSample([-4.0, 12.0]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final early = tester.getRect(sticker);
    await tester.pump(const Duration(milliseconds: 80));
    final later = tester.getRect(sticker);
    expect(early, isNot(original));
    expect(later, isNot(early));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      (tester.getRect(sticker).topLeft - original.topLeft).distance,
      greaterThan(24),
    ); // 已解除原位置附近24像素的偏移限制。
    motion.acceptAccelerometerSample([-4.0, 12.0]); // 停止摇动，重力仍继续。
    final beforePause = tester.getRect(sticker);
    for (var i = 1; i <= 25; i++) {
      final rect = tester.getRect(find.byKey(ValueKey('mode-sticker-$i')));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(360));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(640));
    }
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(cancels, 1);
    expect(tester.getRect(sticker), beforePause);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.getRect(sticker), beforePause);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(listens, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(cancels, 2);
    expect(tester.takeException(), isNull);
    motion.dispose();
  });

  for (final size in [
    const Size(320, 568),
    const Size(360, 640),
    const Size(412, 915),
    const Size(600, 960),
    const Size(800, 1280),
  ]) {
    testWidgets('${size.width.toInt()}模式页新草地铺满、原25贴纸与模式按钮可用，无标题遮挡或布局溢出', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      addTearDown(tester.view.reset);
      GameMode? selected;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGameTheme(),
          home: GameModePage(onSelected: (mode) => selected = mode),
        ),
      );
      await tester.pumpAndSettle();
      final background = find.byKey(const ValueKey('mode-grass-background'));
      expect(tester.getRect(background), Offset.zero & size);
      expect(tester.widget<Image>(background).fit, BoxFit.cover);
      expect(find.text('选择游戏模式'), findsNothing);
      for (var i = 1; i <= 25; i++) {
        expect(find.byKey(ValueKey('mode-sticker-$i')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('mode-twoPlayer')));
      expect(selected, GameMode.twoPlayer);
      await tester.tap(find.byKey(const ValueKey('mode-computer')));
      expect(selected, GameMode.computer);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(cancels, 1);
    });
  }

  test('模式背景与贴纸素材存在，游戏农田和梨的原位置不变', () {
    expect(File(ModeStickerScene.backgroundPath).existsSync(), isTrue);
    expect(GameArtwork.backgroundPath, 'assets/storybook/farm_scene.png');
    expect(GameArtwork.cardPath(13), 'assets/storybook/crops/crop13.png');
    for (var i = 1; i <= 25; i++) {
      expect(File(GameArtwork.cardPath(i)).existsSync(), isTrue);
    }
  });

  for (final size in [const Size(360, 640), const Size(800, 1280)]) {
    testWidgets('${size.width.toInt()}最小贴纸等于游戏内同一作物，最大同作物宽高三倍，游戏无贴纸层', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
      addTearDown(tester.view.reset);
      final controller = GameController(
        storage: ComputerStorage(),
        restoredState: startHeroTurn().state,
      );
      final stateBefore = controller.state.toJson();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGameTheme(),
          home: GamePage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ModeStickerScene), findsNothing);
      expect(listens, 0);
      final smallest = tester.getSize(
        find.byKey(const ValueKey('crop-viewport-1')),
      );
      final strawberry = tester.getSize(
        find.byKey(const ValueKey('crop-viewport-18')),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGameTheme(),
          home: GameModePage(onSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();
      final modeSmallest = tester.getSize(
        find.byKey(const ValueKey('crop-viewport-1')),
      );
      final modeLargest = tester.getSize(
        find.byKey(const ValueKey('crop-viewport-18')),
      );
      expect(modeSmallest.width, closeTo(smallest.width, 0.01));
      expect(modeSmallest.height, closeTo(smallest.height, 0.01));
      expect(modeLargest.width, closeTo(strawberry.width * 3, 0.01));
      expect(modeLargest.height, closeTo(strawberry.height * 3, 0.01));
      expect(ModeStickerScene.stickerScales.toSet().length, 25);
      expect(controller.state.toJson(), stateBefore);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildGameTheme(),
          home: GamePage(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ModeStickerScene), findsNothing);
      expect(cancels, 1);
      expect(controller.state.toJson(), stateBefore);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }
}
