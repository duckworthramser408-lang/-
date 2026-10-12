import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_mode.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_artwork.dart';
import 'package:happiness_threads/ui/game_night_style.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';
import 'package:happiness_threads/ui/widgets/worm_walkway.dart';

import 'helpers/game_fixtures.dart';

class _NightStorage implements GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState state) async {}
}

Future<ThemeData> _theme(WidgetTester tester) async {
  var theme = buildGameTheme();
  if (Platform.environment['HAPPINESS_LAYOUT_PREVIEW'] != '1') return theme;
  await tester.runAsync(() async {
    await (FontLoader('FarmPreview')..addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
              ).readAsBytes(),
            ),
          ),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  theme = theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'FarmPreview'),
    filledButtonTheme: FilledButtonThemeData(
      style: theme.filledButtonTheme.style!.copyWith(
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'FarmPreview', fontSize: 13),
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
  );
  return theme;
}

Future<void> _preview(
  WidgetTester tester, {
  String path = '/tmp/catch-bugs-night-360x640.png',
}) async {
  if (Platform.environment['HAPPINESS_LAYOUT_PREVIEW'] != '1') return;
  final providers = tester
      .widgetList<Image>(find.byType(Image))
      .map((image) => image.image)
      .toList();
  await tester.runAsync(
    () => Future.wait(
      providers.map(
        (provider) =>
            precacheImage(provider, tester.element(find.byType(GamePage))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('night-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final (physicalSize, density) in [
    (const Size(320, 568), 1.0),
    (const Size(360, 640), 1.0),
    (const Size(375, 667), 1.0),
    (const Size(390, 844), 1.0),
    (const Size(412, 915), 1.0),
    (const Size(1080, 1920), 3.0),
  ]) {
    testWidgets(
      '${physicalSize.width.toInt()}×${physicalSize.height.toInt()} @$density：昼夜坐标相同，三虫横移不遮地块或按钮',
      (tester) async {
        tester.view.physicalSize = physicalSize;
        tester.view.devicePixelRatio = density;
        tester.view.padding = FakeViewPadding(
          top: 24 * density,
          bottom: 16 * density,
        );
        addTearDown(tester.view.reset);
        final controller = GameController(
          storage: _NightStorage(),
          restoredState: startHeroTurn().state,
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('night-preview'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: await _theme(tester),
              home: GamePage(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final originalState = controller.state.toJson();
        final dayPlots = [
          for (var id = 1; id <= 25; id++)
            tester.getRect(find.byKey(ValueKey(id))),
        ];
        final dayImage = tester.getRect(
          find.byKey(const ValueKey('game-background-image')),
        );
        final dayBackground = tester.widget<Image>(
          find.byKey(const ValueKey('game-background-image')),
        );
        expect(
          (dayBackground.image as AssetImage).assetName,
          GameArtwork.backgroundPath,
        );
        expect(
          find.byKey(const ValueKey('night-sky-decoration')),
          findsNothing,
        );
        final dayPanel = tester.getRect(
          find.byKey(const ValueKey('operation-region')),
        );
        expect(find.byType(WormWalkway), findsNothing);
        if (physicalSize == const Size(360, 640)) {
          await _preview(tester, path: '/tmp/catch-bugs-day-360x640.png');
        }
        controller.endHeroTurn();
        await tester.pumpAndSettle();
        await tester.tap(find.text('已回避，继续'));
        await tester.pumpAndSettle();
        expect(controller.state.phase, GamePhase.chooseOmen);
        expect(
          tester.getRect(find.byKey(const ValueKey('game-background-image'))),
          dayImage,
        );
        final nightBackground = tester.widget<Image>(
          find.byKey(const ValueKey('game-background-image')),
        );
        // 不同底图即使组件坐标相同，也会造成昼夜地平线跳动。
        expect(nightBackground.image, dayBackground.image);
        expect(nightBackground.fit, dayBackground.fit);
        expect(nightBackground.alignment, dayBackground.alignment);
        expect(
          tester.getRect(find.byKey(const ValueKey('night-sky-decoration'))),
          dayImage,
        );
        expect(
          tester
              .widget<ColorFiltered>(
                find.byKey(const ValueKey('farm-background-tint')),
              )
              .colorFilter,
          GameNightStyle.scene,
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('operation-region'))),
          dayPanel,
        );
        expect(
          tester
              .widget<ColorFiltered>(
                find.byKey(const ValueKey('farm-scene-tint')),
              )
              .colorFilter,
          GameNightStyle.scene,
        );
        expect(
          tester
              .widget<ColorFiltered>(
                find.byKey(const ValueKey('operation-night-tint')),
              )
              .colorFilter,
          GameNightStyle.interface,
        );
        for (var id = 1; id <= 25; id++) {
          expect(tester.getRect(find.byKey(ValueKey(id))), dayPlots[id - 1]);
          expect(
            tester.widget<GirlCardView>(find.byKey(ValueKey(id))).night,
            isTrue,
          );
          expect(
            tester
                .widget<ColorFiltered>(find.byKey(ValueKey('crop-tint-$id')))
                .colorFilter,
            GameNightStyle.crop,
          );
        }
        final strip = tester.getRect(
          find.byKey(const ValueKey('worm-walkway')),
        );
        expect(strip.top, greaterThan(dayPlots.last.bottom));
        expect(strip.bottom, closeTo(dayPanel.top, .01));
        final publicStateBeforeMotion = controller.state.toJson();
        final before = [
          for (var i = 0; i < 3; i++)
            tester.getRect(find.byKey(ValueKey('worm-sprite-$i'))),
        ];
        await tester.pump(const Duration(milliseconds: 2800));
        await tester.pump(const Duration(milliseconds: 800));
        for (var i = 0; i < 3; i++) {
          final rect = tester.getRect(find.byKey(ValueKey('worm-sprite-$i')));
          expect(rect.left, isNot(closeTo(before[i].left, .1)));
          expect(rect.top, before[i].top);
          expect(strip.contains(rect.topLeft), isTrue);
          expect(strip.contains(rect.bottomRight), isTrue);
          for (final plot in dayPlots) {
            expect(rect.overlaps(plot), isFalse);
          }
          expect(rect.overlaps(dayPanel), isFalse);
        }
        expect(controller.state.toJson(), publicStateBeforeMotion);
        expect(
          controller.state.girls.map((g) => g.toJson()).toList(),
          originalState['girls'],
        );
        // 装饰不截获触摸，仍可以选择手牌；对应名词全部使用农场用语。
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('omen-card-2')));
        await tester.tap(find.byKey(const ValueKey('omen-card-2')));
        await tester.pumpAndSettle();
        expect(controller.state.selectedOmenId, 2);
        if (physicalSize == const Size(360, 640)) {
          await _preview(tester);
          if (Platform.environment['HAPPINESS_LAYOUT_PREVIEW'] == '1') {
            controller.playOmen();
            await tester.pumpAndSettle();
            controller.selectCenter(5);
            await tester.pumpAndSettle();
            await _preview(tester, path: '/tmp/catch-bugs-range-360x640.png');
          }
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      },
    );
  }

  testWidgets('人机夜间只显示三只装饰虫，不展示寄生作物或临时行动，离开页面取消动画', (tester) async {
    final controller = GameController(
      storage: _NightStorage(),
      mode: GameMode.computer,
      computerDelay: const Duration(seconds: 30),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: GamePage(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(WormWalkway), findsOneWidget);
    expect(find.byType(GirlCardView), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const ValueKey('computer-curtain')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(ValueKey('worm-sprite-$i')), findsOneWidget);
    }
    final before = controller.state.toJson();
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(controller.state.toJson(), before);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump(const Duration(seconds: 4));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
