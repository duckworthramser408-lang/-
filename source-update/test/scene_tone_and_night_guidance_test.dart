import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/ui/game_night_style.dart';
import 'package:happiness_threads/ui/widgets/action_button_hint.dart';

Future<List<int>> pixel(WidgetTester tester, String key, int x, int y) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(ValueKey(key)),
  );
  late ByteData bytes;
  late int width;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    width = image.width;
    bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    image.dispose();
  });
  final offset = (y * width + x) * 4;
  return List.generate(4, (i) => bytes.getUint8(offset + i));
}

void main() {
  testWidgets('实际渲染：白天草地绿色更柔和，RGB跨度下降，透明边缘保持', (tester) async {
    const grass = Color.fromARGB(96, 128, 230, 32);
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RepaintBoundary(
              key: ValueKey('original'),
              child: SizedBox(
                width: 32,
                height: 32,
                child: ColoredBox(color: grass),
              ),
            ),
            RepaintBoundary(
              key: ValueKey('softened'),
              child: ColorFiltered(
                colorFilter: GameNightStyle.dayScene,
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: ColoredBox(color: grass),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final original = await pixel(tester, 'original', 16, 16);
    final softened = await pixel(tester, 'softened', 16, 16);
    int span(List<int> rgba) {
      final rgb = rgba.take(3).toList()..sort();
      return rgb.last - rgb.first;
    }

    expect(span(softened), lessThan(span(original) * .98));
    expect(softened[1] / softened[0], lessThan(original[1] / original[0]));
    expect(softened[3], closeTo(original[3], 1));
  });

  testWidgets('实际渲染：夜间光带在脉冲低谷也明显亮于旧光带，按钮区域不变', (tester) async {
    Widget band(String key, bool night) => RepaintBoundary(
      key: ValueKey(key),
      child: GameNightStyle.apply(
        night: true,
        filter: GameNightStyle.interface,
        child: ActionButtonHint(
          enabled: true,
          lit: false,
          night: night,
          label: key,
          child: const SizedBox(
            width: 120,
            height: 48,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [band('old', false), band('night', true)],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final old = await pixel(tester, 'old', 60, 45);
    final night = await pixel(tester, 'night', 60, 45);
    double brightness(List<int> p) =>
        .2126 * p[0] + .7152 * p[1] + .0722 * p[2];
    expect(brightness(night), greaterThan(brightness(old) + 40));
    expect(
      tester.getSize(find.byKey(const ValueKey('night'))),
      tester.getSize(find.byKey(const ValueKey('old'))),
    );
  });

  testWidgets('禁用操作无引导光带，夜间增强不改变点击回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionButtonHint(
            enabled: false,
            lit: true,
            night: true,
            label: '提交啃食',
            child: TextButton(onPressed: () => taps++, child: const Text('动作')),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('button-glow-提交啃食')), findsNothing);
    await tester.tap(find.text('动作'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });
}
