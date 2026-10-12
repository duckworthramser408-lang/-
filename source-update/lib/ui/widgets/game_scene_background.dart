import 'package:flutter/material.dart';

import '../game_artwork.dart';
import '../farm_scene_geometry.dart';
import '../game_theme.dart';
import '../game_night_style.dart';

/// 草地cover铺满屏幕；独立地块与点击层共用安全区几何，不截获触摸。
class GameSceneBackground extends StatelessWidget {
  const GameSceneBackground({
    super.key,
    this.night = false,
    this.eatenPlotIds = const {},
  });
  final bool night;
  final Set<int> eatenPlotIds;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: night ? const Color(0xFF142330) : GamePalette.canvas),
        Positioned.fill(
          child: GameNightStyle.apply(
            night: night,
            filter: GameNightStyle.scene,
            dayFilter: GameNightStyle.dayScene,
            key: const ValueKey('farm-background-tint'),
            child: Image.asset(
              // 共用底图及 cover 裁切，昼夜地平线和植物轮廓完全重合。
              GameArtwork.backgroundPath,
              key: const ValueKey('game-background-image'),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const Center(
                key: ValueKey('game-background-fallback'),
                child: Text('农田图片加载失败'),
              ),
            ),
          ),
        ),
        if (night)
          Positioned.fill(
            child: Image.asset(
              GameArtwork.nightSkyPath,
              key: const ValueKey('night-sky-decoration'),
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        SafeArea(
          child: GameNightStyle.apply(
            night: night,
            filter: GameNightStyle.scene,
            dayFilter: GameNightStyle.dayScene,
            key: const ValueKey('farm-scene-tint'),
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  for (var id = 1; id <= 25; id++)
                    Positioned.fromRect(
                      key: ValueKey('farm-tile-$id'),
                      rect: FarmSceneGeometry.tileRect(id, constraints.biggest),
                      child: ColorFiltered(
                        key: ValueKey('soil-darkening-$id'),
                        colorFilter: ColorFilter.mode(
                          eatenPlotIds.contains(id)
                              ? const Color(0xFF999999)
                              : Colors.white,
                          BlendMode.modulate,
                        ),
                        child: Image.asset(
                          GameArtwork.plotPath,
                          key: ValueKey('soil-image-$id'),
                          fit: BoxFit.contain,
                          cacheWidth:
                              (FarmSceneGeometry.tileRect(
                                        id,
                                        constraints.biggest,
                                      ).width *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .ceil()
                                  .clamp(1, 1254),
                          excludeFromSemantics: true,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: Color(0xFF996132)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
