import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happiness_threads/ui/farm_scene_geometry.dart';
import 'package:happiness_threads/ui/game_artwork.dart';
import 'package:happiness_threads/ui/widgets/girl_card_view.dart';
import 'package:happiness_threads/models/game_state.dart';

class _MissingCropBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<String, Object>{})!;
    }
    throw FlutterError('Missing test crop asset');
  }
}

void main() {
  testWidgets('新独立地块PNG：25块点击区域映射的九个采样点均落在棕色土壤', (tester) async {
    await tester.runAsync(() async {
      final bytes = await rootBundle.load(GameArtwork.plotPath);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1254);
      expect(image.height, 1254);
      final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      for (var id = 1; id <= 25; id++) {
        const scene = Size(360, 600);
        final tile = FarmSceneGeometry.tileRect(id, scene);
        final plot = FarmSceneGeometry.plotRect(id, scene);
        for (final dx in [-0.40, 0.0, 0.40]) {
          for (final dy in [-0.40, 0.0, 0.40]) {
            final x =
                ((plot.center.dx + dx * plot.width - tile.left) /
                        tile.width *
                        image.width)
                    .round();
            final y =
                ((plot.center.dy + dy * plot.height - tile.top) /
                        tile.height *
                        image.height)
                    .round();
            final index = (y * image.width + x) * 4;
            final red = pixels!.getUint8(index);
            final green = pixels.getUint8(index + 1);
            expect(
              red,
              greaterThan(green * 1.20),
              reason: 'plot $id soil sample',
            );
            // 绘本PNG保留纸纤维边缘与轻微颜料透明度，土壤仍实心可点。
            expect(pixels.getUint8(index + 3), greaterThanOrEqualTo(240));
          }
        }
      }
      image.dispose();
      codec.dispose();
    });
  });

  testWidgets('登记作物图片缺失仍保留上层标记与点击，不崩溃', (tester) async {
    final bundle = _MissingCropBundle();
    final girl = GameArtwork.cardForDisplay(GameState.initial().girl(13));
    var taps = 0;
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: bundle,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 64,
                height: 64,
                child: GirlCardView(
                  girl: girl,
                  terrain: true,
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(
      find.byKey(const ValueKey('card-image-13')),
    );
    await tester.runAsync(
      () => precacheImage(
        image.image,
        tester.element(find.byType(GirlCardView)),
        onError: (_, _) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('card-image-fallback-13')),
      findsOneWidget,
    );
    expect(find.text('啃食0·初始'), findsOneWidget);
    await tester.tap(find.byType(GirlCardView));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
