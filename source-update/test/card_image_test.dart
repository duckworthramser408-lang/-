import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/game/game_engine.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/models/girl_card.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';

import 'helpers/game_fixtures.dart';

// 仅测试用内存asset，不创建/覆盖任何用户人物卡面。
class CardImageBundle extends CachingAssetBundle {
  CardImageBundle(this.png);
  static const validPath = 'assets/crops/test_card.png';
  static const corruptPath = 'assets/crops/corrupt.png';
  final ByteData png;
  final loads = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loads.add(key);
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage({
        validPath: [
          {'asset': validPath},
        ],
        corruptPath: [
          {'asset': corruptPath},
        ],
      })!;
    }
    if (key == validPath) return png;
    if (key == corruptPath) {
      return ByteData.sublistView(Uint8List.fromList([0]));
    }
    throw FlutterError('Missing test asset: $key');
  }
}

class CardImageStorage implements GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState state) async {}
}

Future<ByteData> samplePng() async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 100, 50), Paint()..color = Colors.green);
  final picture = recorder.endRecording();
  final image = await picture.toImage(100, 50);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!;
}

Future<void> settleAsset(
  WidgetTester tester,
  CardImageBundle bundle,
  String path,
) async {
  await tester.runAsync(
    () => precacheImage(
      AssetImage(path, bundle: bundle),
      tester.element(find.byType(GirlCardView).first),
      onError: (_, _) {},
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('单角色图片实际解码、contain不变形，标记/啃食叠加且布局不变', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    });
    final png = await tester.runAsync(samplePng);
    final bundle = CardImageBundle(png!);
    final base = startHeroTurn().state;
    final engine = GameEngine(
      base.copyWith(
        girls: base.girls
            .map(
              (girl) => girl.id == 9
                  ? girl.copyWith(cardImagePath: CardImageBundle.validPath)
                  : girl,
            )
            .toList(),
      ),
    );
    // 普通作物9先被标记、随后被合法啃食；原规则复制角色时不得丢失图片。
    engine.tapCard(9);
    engine.submitSurveillance();
    engine.endHeroTurn();
    infectThisRound(engine);
    engine.acknowledgePrivacy();
    final recovered = GameState.fromJson(engine.state.toJson());
    expect(recovered.girl(9).cardImagePath, CardImageBundle.validPath);
    expect(recovered.girl(9).isInfected, isTrue);
    expect(recovered.girl(9).surveillanceMarks.single.isActive, isFalse);
    final controller = GameController(
      storage: CardImageStorage(),
      restoredState: recovered,
    );
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(home: GamePage(controller: controller)),
      ),
    );
    await settleAsset(tester, bundle, CardImageBundle.validPath);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == CardImageBundle.validPath,
      ),
      findsOneWidget,
    );
    final imageFinder = find.byKey(const ValueKey('card-image-9'));
    final image = tester.widget<Image>(imageFinder);
    expect(image.fit, BoxFit.contain);
    expect(image.excludeFromSemantics, isTrue);
    final renderedImage = tester.renderObject<RenderImage>(
      find.descendant(of: imageFinder, matching: find.byType(RawImage)),
    );
    expect(renderedImage.image, isNotNull);
    expect(renderedImage.image!.width, 100);
    expect(renderedImage.image!.height, 50);
    final fitted = applyBoxFit(
      renderedImage.fit!,
      const Size(100, 50),
      renderedImage.size,
    );
    expect(
      fitted.destination.width / fitted.destination.height,
      closeTo(2, 0.0001),
    );
    expect(fitted.destination.height, lessThan(renderedImage.size.height));
    final cardFinder = find.byKey(const ValueKey(9));
    final card = tester.getRect(cardFinder);
    final imageRect = tester.getRect(imageFinder);
    expect(card.width / card.height, closeTo(1, 0.0001));
    expect(imageRect.left - card.left, greaterThanOrEqualTo(3));
    expect(card.right - imageRect.right, greaterThanOrEqualTo(3));
    expect(imageRect.top - card.top, greaterThanOrEqualTo(3));
    expect(card.bottom - imageRect.bottom, greaterThanOrEqualTo(3));
    final stack = tester.widget<Stack>(
      find.descendant(of: cardFinder, matching: find.byType(Stack)).first,
    );
    final imageIndex = stack.children.indexWhere(
      (widget) =>
          widget is ColorFiltered,
    );
    expect(stack.children.first, isA<ColoredBox>());
    expect(imageIndex, greaterThan(0));
    expect(stack.children.last, isA<Positioned>());
    expect(imageIndex, lessThan(stack.children.length - 1));
    expect(
      find.descendant(of: cardFinder, matching: find.text('啃食2·环')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cardFinder, matching: find.text('标记1')),
      findsOneWidget,
    );
    final frame = tester.widget<AnimatedContainer>(
      find
          .descendant(of: cardFinder, matching: find.byType(AnimatedContainer))
          .first,
    );
    expect(frame.foregroundDecoration, isA<BoxDecoration>());
    final board = tester.getSize(find.byKey(const ValueKey('board-region')));
    final panel = tester.getSize(
      find.byKey(const ValueKey('operation-region')),
    );
    expect(board.height / panel.height, closeTo(2, 0.0001));
    expect(find.byType(GirlCardView), findsNWidgets(25));
    for (var id = 1; id <= 25; id++) {
      final size = tester.getSize(find.byKey(ValueKey(id)));
      expect(size.width / size.height, closeTo(1, 0.0001));
    }
    expect(find.byKey(const ValueKey('card-image-fallback-9')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('空路径不加载；路径错误/资源缺失/损坏回退原底色，旧存档兼容且无崩溃', (tester) async {
    final png = await tester.runAsync(samplePng);
    final bundle = CardImageBundle(png!);
    final original = GirlCard(
      id: 1,
      infectionType: InfectionType.cross,
      cardImagePath: CardImageBundle.validPath,
    );
    expect(original.copyWith().cardImagePath, CardImageBundle.validPath);
    expect(original.copyWith(cardImagePath: null).cardImagePath, isNull);
    expect(
      GirlCard.fromJson(original.toJson()).cardImagePath,
      CardImageBundle.validPath,
    );
    final oldJson = original.toJson()..remove('cardImagePath');
    final restoredOld = GirlCard.fromJson(oldJson);
    expect(restoredOld.cardImagePath, isNull);
    expect(restoredOld.toJson(), oldJson);
    for (final path in <String?>[
      null,
      '',
      '   ',
      'assets/crops/wrong.webp',
      'assets/crops/missing.png',
      CardImageBundle.corruptPath,
    ]) {
      final girl = original.copyWith(cardImagePath: path);
      final previousLoads = bundle.loads.length;
      await tester.pumpWidget(
        DefaultAssetBundle(
          bundle: bundle,
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 75,
                  height: 100,
                  child: GirlCardView(
                    girl: girl,
                    onTap: () {},
                    accompliceHighlight: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      if (path == null || path.trim().isEmpty) {
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsNothing);
        expect(bundle.loads.length, previousLoads);
      } else {
        await settleAsset(tester, bundle, path);
        expect(
          find.byKey(const ValueKey('card-image-fallback-1')),
          findsOneWidget,
        );
      }
      final placeholder = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('card-placeholder-1')),
      );
      expect(placeholder.color, GamePalette.cardBase(1));
      final frame = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(GirlCardView),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final border =
          (frame.foregroundDecoration! as BoxDecoration).border! as Border;
      expect(border.top.color, GamePalette.markerBlue);
      expect(tester.getSize(find.byType(GirlCardView)), const Size(75, 100));
      expect(find.byType(GirlCardView).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'path=$path');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
}
