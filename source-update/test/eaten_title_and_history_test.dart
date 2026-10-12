import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_artwork.dart';
import 'package:happiness_threads/ui/crop_damage_artwork.dart';
import 'package:happiness_threads/ui/game_mode_page.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/action_card_hand.dart';
import 'package:happiness_threads/ui/widgets/action_card_preview.dart';
import 'package:happiness_threads/ui/widgets/eaten_crop_effect.dart';
import 'package:happiness_threads/ui/widgets/game_title_image.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';

import 'helpers/game_fixtures.dart';

class _Storage implements GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState state) async {}
}

Future<void> _mountPage(WidgetTester tester, GameController controller) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildGameTheme(),
      home: GamePage(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('25份原图实际作物都被咬到，保留主体，避开透明留白', (tester) async {
    await tester.runAsync(() async {
      for (final artwork in GameArtwork.cropArtwork.values) {
        final bytes = await rootBundle.load(artwork.path);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final image = (await codec.getNextFrame()).image;
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final bounds = artwork.contentBounds;
        final clip = CropBiteClipper(
          center: CropDamageArtwork.biteCenter(artwork.path),
        ).getClip(bounds.size);
        var opaque = 0;
        var bitten = 0;
        for (var y = bounds.top.toInt(); y < bounds.bottom.toInt(); y += 8) {
          for (var x = bounds.left.toInt(); x < bounds.right.toInt(); x += 8) {
            if (pixels.getUint8((y * image.width + x) * 4 + 3) <= 128) continue;
            opaque++;
            if (!clip.contains(Offset(x - bounds.left, y - bounds.top))) {
              bitten++;
            }
          }
        }
        expect(bitten / opaque, greaterThan(.01), reason: artwork.path);
        expect(bitten / opaque, lessThan(.25), reason: artwork.path);
        image.dispose();
        codec.dispose();
      }
    });
  });
  testWidgets('全部25张作物可叠加咬痕和x_x，昼夜大小与原图比例不变', (tester) async {
    for (final night in [false, true]) {
      for (final girl in GameState.initial().girls) {
        final display = GameArtwork.cardForDisplay(girl);
        Widget crop(bool eaten) => MaterialApp(
          home: Center(
            child: SizedBox(
              width: 80,
              height: 80,
              child: GirlCardView(
                girl: display.copyWith(isInfected: eaten),
                terrain: true,
                night: night,
                onTap: () {},
              ),
            ),
          ),
        );
        await tester.pumpWidget(crop(false));
        await tester.pump();
        final livingBounds = tester.getRect(
          find.byKey(ValueKey('crop-viewport-${girl.id}')),
        );
        expect(find.byType(EatenCropFace), findsNothing);
        await tester.pumpWidget(crop(true));
        await tester.pump();
        expect(
          tester.getRect(find.byKey(ValueKey('crop-viewport-${girl.id}'))),
          livingBounds,
        );
        expect(find.byKey(ValueKey('crop-bite-${girl.id}')), findsOneWidget);
        expect(find.byKey(ValueKey('eaten-face-${girl.id}')), findsOneWidget);
        expect(
          find.byKey(ValueKey('eaten-crop-darkening-${girl.id}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('咬痕是透明缺口，保留作物主体和原矩形点击区域', () {
    final shape = const CropBiteClipper().getClip(const Size(80, 80));
    expect(shape.contains(const Offset(40, 40)), isTrue);
    expect(shape.contains(const Offset(76, 40)), isFalse);
    expect(shape.contains(const Offset(10, 60)), isTrue);
  });

  testWidgets('只在提交后出现损伤：初始梨受损，临时目标仍完好，地块分别变暗', (tester) async {
    final e = startGame()..acknowledgePrivacy();
    playRoundOmen(e);
    final c = GameController(storage: _Storage(), restoredState: e.state);
    await _mountPage(tester, c);
    await tester.tap(find.text('已回避，继续'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('eaten-face-13')), findsOneWidget);
    c.selectCenter(1);
    c.tapCard(7);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('eaten-face-7')), findsNothing);
    final before = c.state.toJson();
    final liveSoil = tester
        .widget<ColorFiltered>(find.byKey(const ValueKey('soil-darkening-7')))
        .colorFilter;
    final eatenSoil = tester
        .widget<ColorFiltered>(find.byKey(const ValueKey('soil-darkening-13')))
        .colorFilter;
    expect(liveSoil, isNot(eatenSoil));
    expect(c.state.toJson(), before);
    c.selectCenter(5);
    c.tapCard(3);
    c.submitInfection();
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始行动'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('eaten-face-7')), findsOneWidget);
    expect(
      tester
          .widget<ColorFiltered>(find.byKey(const ValueKey('soil-darkening-7')))
          .colorFilter,
      eatenSoil,
    );
    expect(find.text('啃食1·环'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('白色光点围绕原预览框，大小不一并单向渐隐，没有中央彩色爆发', (tester) async {
    Future<int> pixelsAt(double t) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 240,
            height: 240,
            child: CardPlayParticles(
              animation: AlwaysStoppedAnimation(t),
              cardRect: const Rect.fromLTWH(60, 30, 120, 180),
            ),
          ),
        ),
      );
      final painter = tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey('card-play-particles')),
          )
          .painter!;
      return (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(240, 240));
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 240);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var alpha = 0;
        var litPixels = 0;
        var spreadPixels = 0;
        for (var y = 0; y < 240; y++) {
          for (var x = 0; x < 240; x++) {
            final i = (y * 240 + x) * 4;
            final a = bytes.getUint8(i + 3);
            if (a > 5) {
              litPixels++;
              if (x < 42 || x > 198 || y < 12 || y > 228) spreadPixels++;
              expect(bytes.getUint8(i), bytes.getUint8(i + 1));
              expect(bytes.getUint8(i), bytes.getUint8(i + 2));
            }
            if (x > 80 && x < 160 && y > 55 && y < 185) expect(a, 0);
            alpha += a;
          }
        }
        if (t == 0) {
          expect(litPixels, greaterThan(1800), reason: '增加光点数量及大小');
        }
        if (t == .5) {
          expect(spreadPixels, greaterThan(150), reason: '光点向卡面框外扩散更远');
        }
        image.dispose();
        picture.dispose();
        return alpha;
      }))!;
    }

    final initial = await pixelsAt(0);
    final middle = await pixelsAt(.5);
    final end = await pixelsAt(1);
    expect(initial, greaterThan(middle));
    expect(middle, greaterThan(0));
    expect(end, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('出牌成功后光点使用实际预览框边界，预览先消失，动画有限', (tester) async {
    final c = GameController(
      storage: _Storage(),
      restoredState: (startGame()..acknowledgePrivacy()).state,
    );
    await _mountPage(tester, c);
    await tester.tap(find.text('已回避，继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('omen-card-1')));
    await tester.pumpAndSettle();
    final frame = tester
        .getRect(find.byKey(const ValueKey('card-preview-content')))
        .shift(-tester.getTopLeft(find.byType(ActionCardPreview)));
    await tester.tap(find.text('打出行动牌'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(ActionCardPreview), findsNothing);
    expect(
      tester.widget<CardPlayParticles>(find.byType(CardPlayParticles)).cardRect,
      frame,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CardPlayParticles), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });

  testWidgets('绘本标题PNG四角透明，入口没有选择游戏模式标题', (tester) async {
    await tester.runAsync(() async {
      final bytes = await rootBundle.load(GameTitleImage.assetPath);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final image = (await codec.getNextFrame()).image;
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      for (final (x, y) in [
        (0, 0),
        (image.width - 1, 0),
        (0, image.height - 1),
        (image.width - 1, image.height - 1),
      ]) {
        expect(
          pixels.getUint8((y * image.width + x) * 4 + 3),
          lessThanOrEqualTo(8),
        );
      }
      image.dispose();
      codec.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: GameModePage(onSelected: (_) {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(GameTitleImage), findsOneWidget);
    expect(find.text('选择游戏模式'), findsNothing);
    expect(find.byKey(const ValueKey('mode-twoPlayer')), findsOneWidget);
    expect(find.byKey(const ValueKey('mode-computer')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('标题缺失回退文字，两个模式仍可进入', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 240,
          child: GameTitleImage(imagePath: 'assets/title/missing.png'),
        ),
      ),
    );
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('game-title-image')),
    );
    await tester.runAsync(
      () => precacheImage(
        image.image,
        tester.element(find.byType(GameTitleImage)),
        onError: (_, _) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-title-fallback')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('六回合历史最新在左且更大，第六回合复用牌独立标号，横滑不出牌', (tester) async {
    final e = startHeroTurn();
    while (e.state.round < 6) {
      e.endHeroTurn();
      infectThisRound(e);
      e.acknowledgePrivacy();
    }
    final c = GameController(storage: _Storage(), restoredState: e.state);
    await _mountPage(tester, c);
    final before = c.state.toJson();
    expect(
      tester
          .widget<PlayedActionHistory>(find.byType(PlayedActionHistory))
          .playedCardIds,
      [1, 2, 3, 4, 5, 5],
    );
    expect(find.byType(PlayedActionCard), findsNWidgets(6));
    final recent = tester.getRect(
      find.byKey(const ValueKey('action-history-round-6')),
    );
    final previous = tester.getRect(
      find.byKey(const ValueKey('action-history-round-5')),
    );
    expect(recent.left, lessThan(previous.left));
    expect(recent.height, greaterThan(previous.height));
    expect(recent.width, greaterThan(previous.width));
    for (var i = 5; i >= 2; i--) {
      expect(
        tester.getTopLeft(find.byKey(ValueKey('action-history-round-$i'))).dx,
        lessThan(
          tester
              .getTopLeft(find.byKey(ValueKey('action-history-round-${i - 1}')))
              .dx,
        ),
      );
    }
    await tester.drag(
      find.byKey(const ValueKey('action-history-scroll')),
      const Offset(-160, 0),
    );
    await tester.pumpAndSettle();
    expect(c.state.toJson(), before);
    expect(find.byType(ActionCardPreview), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
    expect(tester.takeException(), isNull);
  });
}
