import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game_artwork.dart';
import '../farm_scene_geometry.dart';
import '../mode_motion_controller.dart';
import '../mode_sticker_physics.dart';
import 'crop_image_view.dart';

/// 绘本农场铺满模式页；25张同风格贴纸自由飘动、落下堆叠，始终在按钮和标题下层。
class ModeStickerScene extends StatefulWidget {
  const ModeStickerScene({super.key, this.motionController});
  final ModeMotionController? motionController;
  static const backgroundPath = GameArtwork.modeBackgroundPath;
  // 最小档与当前屏幕对局作物使用同一土地内框、同一CropImageView；
  // 最大档宽高各3倍，各张保留原图比例。仅改变模式页装饰。
  static const stickerScales = <double>[
    1,
    1.25,
    1.5,
    1.05,
    1.35,
    1.8,
    1.1,
    1.55,
    1.15,
    1.85,
    2.2,
    1.45,
    1.2,
    1.9,
    1.7,
    2.0,
    1.6,
    3,
    1.95,
    1.4,
    1.75,
    2.3,
    1.3,
    2.1,
    1.65,
  ];

  @override
  State<ModeStickerScene> createState() => _ModeStickerSceneState();
}

class _ModeStickerSceneState extends State<ModeStickerScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ModeMotionController _motion =
      widget.motionController ?? ModeMotionController();
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  ModeStickerPhysics? _physics;
  double? _edge;
  Duration _previous = Duration.zero;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motion.addListener(_animate);
    unawaited(_motion.start());
  }

  void _animate() {
    if (!_foreground || _motion.target == Offset.zero) return;
    _physics?.shake(_motion.target);
    if (_ticker.isActive || _physics == null) return;
    _previous = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _previous).inMicroseconds / 1000000;
    _previous = elapsed;
    final moving = _physics?.advance(dt) ?? false;
    _frame.value++;
    if (!moving) _ticker.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_motion.start());
      if (_physics != null && !_physics!.isSleeping && !_ticker.isActive) {
        _previous = Duration.zero;
        _ticker.start();
      }
    } else {
      _ticker.stop();
      unawaited(_motion.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.removeListener(_animate);
    _ticker.dispose();
    _frame.dispose();
    if (widget.motionController == null) {
      _motion.dispose();
    } else {
      unawaited(_motion.stop());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            ModeStickerScene.backgroundPath,
            key: const ValueKey('mode-grass-background'),
            fit: BoxFit.cover,
            cacheWidth: 1152,
            errorBuilder: (_, error, stackTrace) =>
                const ColoredBox(color: Color(0xFF91B751)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final padding = MediaQuery.paddingOf(context);
              // 尺寸与对局安全区的同一作物保持一致，运动边界则是完整屏幕。
              final safeSize = Size(
                size.width - padding.horizontal,
                size.height - padding.vertical,
              );
              final edge = FarmSceneGeometry.plotRect(1, safeSize).width;
              if (_physics?.size != size || _edge != edge) {
                _edge = edge;
                _physics = ModeStickerPhysics(
                  size: size,
                  edge: edge,
                  scales: ModeStickerScene.stickerScales,
                );
              }
              return ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, frame, _) => Stack(
                  children: [
                    for (var i = 0; i < 25; i++)
                      _sticker(i, _physics!.bodies[i]),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _sticker(int index, ModeStickerBody body) {
    final path = GameArtwork.cardPath(index + 1);
    return Positioned(
      key: ValueKey('mode-sticker-${index + 1}'),
      left: body.position.dx - body.diameter / 2,
      top: body.position.dy - body.diameter / 2,
      width: body.diameter,
      height: body.diameter,
      child: RepaintBoundary(
        child: Transform.rotate(
          angle: body.angle,
          child: CropImageView(
            artwork: GameArtwork.cropArtwork[path]!,
            plotId: index + 1,
          ),
        ),
      ),
    );
  }
}
