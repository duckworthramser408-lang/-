import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/game_constants.dart';
import 'package:happiness_threads/game/game_controller.dart';
import 'package:happiness_threads/models/game_state.dart';
import 'package:happiness_threads/storage/game_storage.dart';
import 'package:happiness_threads/ui/game_mode_page.dart';
import 'package:happiness_threads/ui/game_introduction.dart';
import 'package:happiness_threads/ui/game_page.dart';
import 'package:happiness_threads/ui/game_theme.dart';
import 'package:happiness_threads/ui/widgets/action_card_hand.dart';
import 'package:happiness_threads/ui/widgets/omen_instruction_icons.dart';

import 'helpers/game_fixtures.dart';

class _PreviewStorage implements GameStorage {
  @override
  Future<GameState?> load() async => null;
  @override
  Future<void> save(GameState state) async {}
}

// Opt-in visual QA of the actual Flutter pages with the real Chinese font.
// Ordinary regression runs do not create user-facing artifacts.
void main() {
  testWidgets('绘本美术实际界面导出：入口、白天、夜晚、牌面与规则', (tester) async {
    const export = bool.fromEnvironment('EXPORT_ART_PREVIEWS');
    if (!export) return;
    tester.view.physicalSize = const Size(780, 1560);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 48, bottom: 32);
    addTearDown(tester.view.reset);
    final font = FontLoader('WenKai')
      ..addFont(
        rootBundle.load('assets/storybook/fonts/LXGWWenKaiLite-Regular.ttf'),
      );
    await tester.runAsync(font.load);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    final boundaryKey = GlobalKey();
    final output = Directory('outputs/previews');
    await tester.runAsync(() => output.create(recursive: true));

    Future<void> warmAndCapture(String name) async {
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          final image = element.widget as Image;
          await precacheImage(image.image, element, onError: (_, _) {});
        }
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: name);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        await File('${output.path}/$name.png').writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        image.dispose();
      });
    }

    Future<void> mount(Widget page) => tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildGameTheme(),
          home: page,
        ),
      ),
    );
    await mount(GameIntroduction(onContinue: () {}));
    await warmAndCapture('06-introduction');
    await tester.pumpWidget(const SizedBox.shrink());
    await mount(GameModePage(onSelected: (_) {}));
    await warmAndCapture('01-mode');
    await tester.tap(find.text('规则说明'));
    await warmAndCapture('02-rules');
    await tester.pumpWidget(const SizedBox.shrink());
    final day = GameController(
      storage: _PreviewStorage(),
      restoredState: startHeroTurn().state,
    );
    await mount(GamePage(controller: day));
    await warmAndCapture('03-day');
    await tester.pumpWidget(const SizedBox.shrink());
    day.dispose();
    final engine = startGame()..acknowledgePrivacy();
    final night = GameController(
      storage: _PreviewStorage(),
      restoredState: engine.state,
    );
    await mount(GamePage(controller: night));
    await tester.pumpAndSettle();
    await tester.tap(find.text('已回避，继续'));
    await warmAndCapture('04-night');
    await tester.tap(find.byKey(const ValueKey('omen-card-1')));
    await warmAndCapture('05-card-preview');
    await tester.pumpWidget(const SizedBox.shrink());
    night.dispose();
    tester.view.physicalSize = const Size(1750, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding();
    for (final nightCards in [false, true]) {
      await mount(
        Scaffold(
          backgroundColor: nightCards
              ? GamePalette.nightPaper
              : GamePalette.surface,
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  nightCards ? '夜间行动牌 · 全部指示图形' : '白天行动牌 · 全部指示图形',
                  style: TextStyle(
                    fontSize: 24,
                    color: nightCards ? GamePalette.nightInk : GamePalette.ink,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Row(
                    children: [
                      for (final card in GameConstants.omenCards)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ActionCardImage(
                              card: card,
                              night: nightCards,
                              highResolution: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      // 对实际绘制组件核对图形，不仅核对底层牌面数据或文字。
      for (final card in GameConstants.omenCards) {
        final rendered = tester
            .widgetList<InfectionMethodIcon>(
              find.descendant(
                of: find.byWidgetPredicate(
                  (widget) =>
                      widget is ActionCardImage && widget.card.id == card.id,
                ),
                matching: find.byType(InfectionMethodIcon),
              ),
            )
            .map((icon) => icon.method)
            .toList();
        expect(rendered, card.displayInstructions);
      }
      await warmAndCapture(
        nightCards ? '08-action-cards-night' : '07-action-cards-day',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !const bool.fromEnvironment('EXPORT_ART_PREVIEWS'));
}
