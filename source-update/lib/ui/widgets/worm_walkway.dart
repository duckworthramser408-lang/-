import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_night_style.dart';

/// 三只虫仅为夜间装饰，不读取身份、监视、中心点或传染目标。
/// 原合图分成三个显示窗口；不改写PNG，也不翻转、拉伸虫的形状。
class WormWalkway extends StatefulWidget {
  const WormWalkway({super.key});

  static const assetPath = 'assets/storybook/greedy_worms.png';
  static const sourceSize = Size(2172, 724);
  static const frames = [
    Rect.fromLTRB(0, 0, 724, 724),
    Rect.fromLTRB(724, 0, 1448, 724),
    Rect.fromLTRB(1448, 0, 2172, 724),
  ];

  @override
  State<WormWalkway> createState() => _WormWalkwayState();
}

class _WormWalkwayState extends State<WormWalkway> with WidgetsBindingObserver {
  Timer? _firstStep;
  Timer? _steps;
  bool _outward = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() {
    _stop();
    _firstStep = Timer(const Duration(milliseconds: 100), _move);
    // 每轮有短暂停留，避免持续占用帧；所有运动与回合计时完全独立。
    _steps = Timer.periodic(const Duration(milliseconds: 2800), (_) => _move());
  }

  void _move() {
    if (mounted) setState(() => _outward = !_outward);
  }

  void _stop() {
    _firstStep?.cancel();
    _steps?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final laneWidth = constraints.maxWidth / 3;
          final height = math.min(40.0, constraints.maxHeight - 4);
          return ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 1,
                  child: Container(
                    key: const ValueKey('worm-track'),
                    height: 1,
                    color: const Color(0xBBAECAD6),
                  ),
                ),
                for (var index = 0; index < 3; index++)
                  AnimatedPositioned(
                    key: ValueKey('worm-position-$index'),
                    duration: const Duration(milliseconds: 1600),
                    curve: Curves.easeInOut,
                    left:
                        index * laneWidth +
                        8 +
                        math.max(
                              0.0,
                              laneWidth -
                                  16 -
                                  height *
                                      WormWalkway.frames[index].width /
                                      WormWalkway.frames[index].height,
                            ) *
                            ((_outward == index.isEven) ? 0.95 : 0.05),
                    bottom: 2,
                    height: height,
                    width:
                        height *
                        WormWalkway.frames[index].width /
                        WormWalkway.frames[index].height,
                    child: _WormSprite(index: index),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _WormSprite extends StatelessWidget {
  const _WormSprite({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final frame = WormWalkway.frames[index];
      final scale = constraints.maxHeight / frame.height;
      return GameNightStyle.apply(
        night: true,
        filter: GameNightStyle.crop,
        child: ClipRect(
          key: ValueKey('worm-sprite-$index'),
          child: Stack(
            children: [
              Positioned(
                left: -frame.left * scale,
                top: -frame.top * scale,
                width: WormWalkway.sourceSize.width * scale,
                height: WormWalkway.sourceSize.height * scale,
                child: Image.asset(
                  WormWalkway.assetPath,
                  fit: BoxFit.contain,
                  cacheHeight:
                      (constraints.maxHeight *
                              MediaQuery.devicePixelRatioOf(context))
                          .ceil(),
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
