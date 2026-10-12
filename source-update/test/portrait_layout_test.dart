import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/game_constants.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/models/girl_card.dart';
import 'package:happiness_threads/models/surveillance_mark.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/farm_scene_geometry.dart';
import 'package:happiness_threads/ui/game_artwork.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';

import 'helpers/game_fixtures.dart';

class LayoutStorage implements GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState state) async {}
}

Rect paintedRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

void expectInside(Rect outer, Rect inner) {
  // Sliver pixel rounding may introduce a very small floating point error.
  expect(inner.left, greaterThanOrEqualTo(outer.left - 0.01));
  expect(inner.top, greaterThanOrEqualTo(outer.top - 0.01));
  expect(inner.right, lessThanOrEqualTo(outer.right + 0.01));
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + 0.01));
}

void main() {
  final phones = [
    (const Size(320, 568), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(375, 667), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(412, 915), 1.0),
    // 9:16 physical phone screen at 3x density, not 1080 logical pixels.
    (const Size(1080, 1920), 3.0),
  ];
  for (final (physicalSize, density) in phones) {
    testWidgets(
      '${physicalSize.width.toInt()}×${physicalSize.height.toInt()} @$density：安全区2:1、25块方形土地完整可点、缩放不越界',
      (tester) async {
        tester.view.physicalSize = physicalSize;
        tester.view.devicePixelRatio = density;
        tester.view.padding = FakeViewPadding(
          top: 24 * density,
          bottom: 16 * density,
        );
        addTearDown(tester.view.reset);
        final controller = GameController(storage: LayoutStorage());
        var theme = buildGameTheme();
        if (Platform.environment['HAPPINESS_LAYOUT_PREVIEW'] == '1') {
          await tester.runAsync(() async {
            final font = FontLoader('FarmPreview')
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    await File(
                      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
                    ).readAsBytes(),
                  ),
                ),
              );
            await font.load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
          theme = theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'FarmPreview'),
            filledButtonTheme: FilledButtonThemeData(
              style: theme.filledButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(
                    fontFamily: 'FarmPreview',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: theme.outlinedButtonTheme.style!.copyWith(
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontFamily: 'FarmPreview', fontSize: 13),
                ),
              ),
            ),
            chipTheme: theme.chipTheme.copyWith(
              labelStyle: theme.chipTheme.labelStyle!.copyWith(
                fontFamily: 'FarmPreview',
              ),
            ),
            dialogTheme: theme.dialogTheme.copyWith(
              titleTextStyle: theme.dialogTheme.titleTextStyle!.copyWith(
                fontFamily: 'FarmPreview',
              ),
            ),
          );
        }
        const previewKey = ValueKey('portrait-preview');
        await tester.pumpWidget(
          RepaintBoundary(
            key: previewKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: GamePage(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('已回避，继续'));
        await tester.pumpAndSettle();
        if (Platform.environment['HAPPINESS_LAYOUT_PREVIEW'] == '1') {
          final providers = tester
              .widgetList<Image>(find.byType(Image))
              .map((w) => w.image)
              .toList();
          await tester.runAsync(
            () => Future.wait(
              providers.map(
                (provider) => precacheImage(
                  provider,
                  tester.element(find.byType(GamePage)),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        final board = tester.getRect(
          find.byKey(const ValueKey('board-region')),
        );
        final panel = tester.getRect(
          find.byKey(const ValueKey('operation-region')),
        );
        final logicalSize = physicalSize / density;
        expect(board.height / panel.height, closeTo(2, 0.0001));
        expect(board.top, 24);
        expect(panel.bottom, closeTo(logicalSize.height - 16, 0.01));
        expect(board.bottom, panel.top);
        expect(board.width, logicalSize.width);
        expect(panel.width, logicalSize.width);
        final grid = tester.getRect(find.byKey(const ValueKey('board-grid')));
        expectInside(board, grid);
        expect(grid, board);
        final sceneSize = Size(board.width, board.height + panel.height);
        final expectedImage = Offset.zero & logicalSize;
        expect(
          tester.getRect(find.byKey(const ValueKey('game-background-image'))),
          expectedImage,
        );
        expect(find.byType(GirlCardView), findsNWidgets(25));
        final watermark = tester.getRect(
          find.byKey(const ValueKey('feedback-watermark')),
        );
        expectInside(board, watermark);
        expect(watermark.top, board.top);
        expect(find.text('反馈q2855863989陈'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('game-background-image')),
          findsOneWidget,
        );
        for (var id = 1; id <= 25; id++) {
          final tile = tester.getRect(find.byKey(ValueKey('farm-tile-$id')));
          final firstTile = tester.getRect(
            find.byKey(const ValueKey('farm-tile-1')),
          );
          expect(tile.width, closeTo(firstTile.width, 0.0000001));
          expect(tile.height, closeTo(firstTile.height, 0.0000001));
          expectInside(board, tile);
          expect(
            tile.overlaps(
              tester.getRect(find.byKey(const ValueKey('worm-walkway'))),
            ),
            isFalse,
          );
          final card = find.byKey(ValueKey(id));
          expect(
            tester.widget<GirlCardView>(card).girl.cardImagePath,
            GameArtwork.cardPath(id),
          );
          final rect = tester.getRect(card);
          expect(rect.width / rect.height, closeTo(1, 0.0001));
          expectInside(board, rect);
          final expected = FarmSceneGeometry.plotRect(
            id,
            sceneSize,
          ).shift(board.topLeft);
          expect(rect.left, closeTo(expected.left, 0.0001));
          expect(rect.top, closeTo(expected.top, 0.0001));
          expect(rect.width, closeTo(expected.width, 0.0001));
          expect(rect.height, closeTo(expected.height, 0.0001));
          expect(tester.widget<GirlCardView>(card).terrain, isTrue);
          expect(rect.overlaps(watermark), isFalse);
          expect(card.hitTestable(), findsOneWidget);
          final background = find.byKey(ValueKey('card-placeholder-$id'));
          expectInside(rect, paintedRect(tester, background));
          final viewport = paintedRect(
            tester,
            find.byKey(ValueKey('crop-viewport-$id')),
          );
          expectInside(rect, viewport);
          final art = GameArtwork.cropForPath(GameArtwork.cardPath(id))!;
          expect(
            viewport.width / viewport.height,
            closeTo(art.contentBounds.width / art.contentBounds.height, 0.001),
          );
          final coverage =
              viewport.width * viewport.height / (rect.width * rect.height);
          expect(coverage, inInclusiveRange(0.49, 0.701));
          // 宽叶作物可能先达到92%最长边，仍保持比例和选择放大的边界。
          if (id == 1) {
            expect(viewport.width / rect.width, closeTo(0.92, 0.001));
          }
        }
        // Test all four edge cards with the original 1.08x selection feedback.
        for (final id in [1, 5, 21, 25]) {
          final originalPlot = tester.getRect(find.byKey(ValueKey(id)));
          await tester.tap(find.byKey(ValueKey(id)));
          await tester.pumpAndSettle();
          expectInside(
            board,
            paintedRect(tester, find.byKey(ValueKey('card-placeholder-$id'))),
          );
          final card = tester.widget<GirlCardView>(find.byKey(ValueKey(id)));
          expect(card.identitySelection, isTrue);
          expectInside(
            originalPlot,
            paintedRect(tester, find.byKey(ValueKey('crop-viewport-$id'))),
          );
          await tester.tap(find.byKey(ValueKey(id)));
          await tester.pumpAndSettle();
        }
        expect(controller.state.selectedIds, isEmpty);
        // 草地间隙不是点击目标；25块土地中只有中心初始被啃食不可选。
        final first = tester.getRect(find.byKey(const ValueKey(1)));
        final second = tester.getRect(find.byKey(const ValueKey(2)));
        await tester.tapAt(
          Offset((first.right + second.left) / 2, first.center.dy),
        );
        await tester.pumpAndSettle();
        expect(controller.state.selectedIds, isEmpty);
        for (var id = 1; id <= 25; id++) {
          await tester.tap(find.byKey(ValueKey(id)));
          // 开局已是夜间，装饰虫正在移动；只等待本次卡片动画，不等背景停下。
          await tester.pump(const Duration(milliseconds: 220));
          expect(controller.state.selectedIds, id == 13 ? isEmpty : {id});
          if (id != 13) {
            await tester.tap(find.byKey(ValueKey(id)));
            await tester.pump(const Duration(milliseconds: 220));
          }
        }
        expect(controller.state.selectedIds, isEmpty);
        expectInside(
          panel,
          tester.getRect(find.widgetWithText(FilledButton, '确认寄生作物')),
        );
        expect(tester.takeException(), isNull);
        // Optional local preview, kept outside the source tree and app assets.
        if (Platform.environment['HAPPINESS_LAYOUT_PREVIEW'] == '1' &&
            physicalSize == const Size(360, 640)) {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(previewKey),
          );
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File(
              '/tmp/happiness-portrait-360x640.png',
            ).writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(412, 915)]) {
    testWidgets('${size.width.toInt()}：六轮标记与秘密蓝光均对齐卡片，不加载图片', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final girl = GirlCard(
        id: 2,
        infectionType: InfectionType.cross,
        isInfected: true,
        infectionRound: 6,
        infectionMethod: InfectionMethod.cross,
        surveillanceMarks: List.generate(
          6,
          (i) => SurveillanceMark(round: i + 1, isActive: i == 5),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width / 6,
                height: size.width / 6 * 4 / 3,
                child: GirlCardView(
                  girl: girl,
                  onTap: null,
                  accompliceHighlight: true,
                  selectedCenter: true,
                  pendingSurveillance: true,
                  currentRound: 6,
                  infectionPlanLabel: '待十3',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(GirlCardView));
      for (final mark in find.byType(Text).evaluate()) {
        expectInside(card, paintedRect(tester, find.byWidget(mark.widget)));
      }
      final container = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(GirlCardView),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final foreground = container.foregroundDecoration! as BoxDecoration;
      expect((foreground.border! as Border).top.color, GamePalette.markerBlue);
      expect((container.decoration! as BoxDecoration).boxShadow, isNotEmpty);
      expect(find.text('啃食6·十'), findsOneWidget);
      for (var round = 1; round <= 6; round++) {
        expect(find.text('标记$round'), findsOneWidget);
      }
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('320×568大字和安全区：确认按钮固定，下方面板滚动可取消与重置', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.reset);
    final controller = GameController(
      storage: LayoutStorage(),
      restoredState: startHeroTurn().state,
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: GamePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey(1)));
    await tester.pumpAndSettle();
    expect(find.text('待标记1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey(1)));
    await tester.pumpAndSettle();
    expect(controller.state.selectedIds, isEmpty);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.text('重置游戏').hitTestable(), findsOneWidget);
    final panel = tester.getRect(
      find.byKey(const ValueKey('operation-region')),
    );
    expectInside(
      panel,
      tester.getRect(find.widgetWithText(FilledButton, '确认标记')),
    );
    expect(tester.getRect(find.text('重置游戏')).top, lessThan(panel.top));
    await tester.tap(find.text('重置游戏'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.state.phase, GamePhase.heroTurn);
    expect(find.byType(GirlCardView), findsNWidgets(25));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
