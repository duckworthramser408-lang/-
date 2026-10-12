import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_artwork.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/game_scene_background.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';

import 'helpers/game_fixtures.dart';

class ArtworkStorage implements GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState state) async {}
}

/// 仅用于测试加载/布局的内存PNG，不是用户场景图，不保存为应用资源。
class FarmTestBundle extends CachingAssetBundle {
  FarmTestBundle(this.png);
  final ByteData? png;
  final loads = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    if (key == GameArtwork.backgroundPath && png != null) return png!;
    if (key.startsWith('assets/storybook/crops/') ||
        key == GameArtwork.plotPath) {
      return rootBundle.load(key);
    }
    throw FlutterError('Missing test background');
  }
}

void main() {
  test('默认25张作物、中心梨；旧人物路径替换；展示副本不改变存档', () {
    final state = startHeroTurn().state;
    final before = state.toJson();
    for (final girl in state.girls) {
      expect(
        GameArtwork.cardForDisplay(girl).cardImagePath,
        GameArtwork.cardPath(girl.id),
      );
      expect(girl.cardImagePath, isNull);
      final displayJson = GameArtwork.cardForDisplay(girl).toJson()
        ..remove('cardImagePath');
      expect(displayJson, girl.toJson());
    }
    final old = state.girl(1).copyWith(cardImagePath: 'assets/cards/画板 1.jpg');
    expect(
      GameArtwork.cardForDisplay(old).cardImagePath,
      'assets/storybook/crops/crop01.png',
    );
    expect(old.cardImagePath, 'assets/cards/画板 1.jpg');
    for (final path in ['', 'assets/crops/custom.webp']) {
      final custom = state.girl(1).copyWith(cardImagePath: path);
      expect(GameArtwork.cardForDisplay(custom), same(custom));
    }
    expect(state.toJson(), before);
    expect(GameArtwork.cardPath(13), 'assets/storybook/crops/crop13.png');
    expect(GameArtwork.cropImagePaths.values.toSet(), hasLength(25));
    expect(GameState.fromJson(before).toJson(), before);
    for (final entry in GameArtwork.legacyCropImagePaths.entries) {
      final original = state
          .girl(entry.key)
          .copyWith(cardImagePath: entry.value);
      final saved = original.toJson();
      expect(
        GameArtwork.cardForDisplay(original).cardImagePath,
        GameArtwork.cardPath(entry.key),
      );
      expect(original.toJson(), saved);
    }
  });

  testWidgets('草地cover铺满；独立地块无旧框；啃食标记叠加；状态保持', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.reset);
    final png = await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawRect(
        const Rect.fromLTWH(0, 0, 941, 1672),
        Paint()..color = Colors.green,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(941, 1672);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      return bytes!;
    });
    final bundle = FarmTestBundle(png);
    final state = startHeroTurn().state;
    final controller = GameController(
      storage: ArtworkStorage(),
      restoredState: state,
    );
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
          theme: buildGameTheme(),
          home: GamePage(controller: controller),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        AssetImage(GameArtwork.backgroundPath, bundle: bundle),
        tester.element(find.byType(GamePage)),
      ),
    );
    await tester.pumpAndSettle();
    final cropImages = <Image>[
      for (var id = 1; id <= 25; id++)
        tester.widget<Image>(find.byKey(ValueKey('card-image-$id'))),
    ];
    await tester.runAsync(
      () => Future.wait(
        cropImages.map(
          (image) =>
              precacheImage(image.image, tester.element(find.byType(GamePage))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final backgroundFinder = find.byKey(
      const ValueKey('game-background-image'),
    );
    expect(tester.widget<Image>(backgroundFinder).fit, BoxFit.cover);
    final background = tester.renderObject<RenderImage>(
      find.descendant(of: backgroundFinder, matching: find.byType(RawImage)),
    );
    expect(background.image!.width, 941);
    expect(background.image!.height, 1672);
    expect(find.byKey(const ValueKey('game-background-mask')), findsNothing);
    expect(
      find.byKey(const ValueKey('game-background-fallback')),
      findsNothing,
    );
    expect(find.byType(GirlCardView), findsNWidgets(25));
    for (var id = 1; id <= 25; id++) {
      final finder = find.byKey(ValueKey(id));
      expect(tester.widget<GirlCardView>(finder).terrain, isTrue);
      final imageFinder = find.byKey(ValueKey('card-image-$id'));
      expect(imageFinder, findsOneWidget);
      final rendered = tester.renderObject<RenderImage>(
        find.descendant(of: imageFinder, matching: find.byType(RawImage)),
      );
      expect(rendered.image, isNotNull);
      expect(find.byKey(ValueKey('card-image-fallback-$id')), findsNothing);
      final placeholder = tester.widget<ColoredBox>(
        find.byKey(ValueKey('card-placeholder-$id')),
      );
      expect(placeholder.color, Colors.transparent);
      final frame = tester.widget<AnimatedContainer>(
        find
            .descendant(of: finder, matching: find.byType(AnimatedContainer))
            .first,
      );
      final foreground = frame.foregroundDecoration! as BoxDecoration;
      expect((foreground.border! as Border).top.color, Colors.transparent);
      expect((frame.decoration! as BoxDecoration).boxShadow, isEmpty);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey(13)),
        matching: find.text('啃食0·初始'),
      ),
      findsOneWidget,
    );
    expect(
      bundle.loads.any((path) => path.startsWith('assets/cards/')),
      isFalse,
    );
    expect(controller.state.toJson(), state.toJson());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  testWidgets('场景缺失提示待导入，不截获点击且不崩溃', (tester) async {
    final bundle = FarmTestBundle(null);
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: const MaterialApp(home: Scaffold(body: GameSceneBackground())),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        AssetImage(GameArtwork.backgroundPath, bundle: bundle),
        tester.element(find.byType(GameSceneBackground)),
        onError: (_, _) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('game-background-fallback')),
      findsOneWidget,
    );
    final pointer = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byType(GameSceneBackground),
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(pointer.ignoring, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
