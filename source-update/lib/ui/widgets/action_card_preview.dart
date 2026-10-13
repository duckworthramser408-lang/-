import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_constants.dart';
import 'action_card_hand.dart';

/// Purely visual overlay. The bottom hand remains outside its hit-test bounds,
/// so the same card can be tapped again while previewing. No engine lives here.
class ActionCardPreview extends StatefulWidget {
  const ActionCardPreview({
    super.key,
    required this.card,
    required this.closing,
    required this.night,
    required this.onDismiss,
    this.frameKey,
  });
  final OmenCard card;
  final bool closing;
  final bool night;
  final VoidCallback onDismiss;
  final Key? frameKey;
  @override
  State<ActionCardPreview> createState() => _ActionCardPreviewState();
}

class _ActionCardPreviewState extends State<ActionCardPreview>
    with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 80), reverseDuration: const Duration(milliseconds: 180));
  late final AnimationController _sparkle = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 560));
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();
  @override
  void didUpdateWidget(ActionCardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.closing != oldWidget.closing) {
      if (widget.closing) {
        _press.stop();
        _sparkle.stop();
        _fade.reverse();
      } else {
        _fade.forward();
      }
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _sparkle.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: widget.closing,
    child: FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeInOut),
      child: Stack(
        key: const ValueKey('card-preview-overlay'),
        fit: StackFit.expand,
        children: [
          GestureDetector(
            key: const ValueKey('preview-dismiss-area'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const ColoredBox(color: Color(0x45634936)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(
                math.min(340.0, math.max(1.0, constraints.maxWidth - 76)),
                math.max(1.0, constraints.maxHeight - 12) * 941 / 1672,
              );
              return Center(
                child: GestureDetector(
                  key: widget.frameKey,
                  onTapDown: (_) { _press.forward(); _sparkle.forward(from: 0); },
                  onTapUp: (_) => _press.reverse(),
                  onTapCancel: () => _press.reverse(),
                  onTap: () {}, // 点击只反馈，不出牌、不取消预览。
                  child: SizedBox(
                    key: const ValueKey('card-preview-content'),
                    width: width,
                    height: width * 1672 / 941,
                    child: AnimatedBuilder(animation: _press, builder: (context, child) =>
                      Transform.translate(key: const ValueKey('preview-press'),
                        offset: Offset(0, 4 * _press.value),
                        child: Transform.scale(scale: 1 - .018 * _press.value, child: child)),
                      child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [ActionCardImage(
                      key: const ValueKey('preview-high-resolution-image'),
                      card: widget.card,
                      highResolution: true,
                      previewDetails: true,
                      night: widget.night,
                    ),
                    IgnorePointer(child: CustomPaint(key: const ValueKey('preview-touch-sparkles'),
                      painter: _PreviewTouchSparkles(_sparkle))),
                    ])),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _PreviewTouchSparkles extends CustomPainter {
  _PreviewTouchSparkles(this.animation) : super(repaint: animation);
  final Animation<double> animation;
  @override
  void paint(Canvas canvas, Size size) {
    if (animation.value <= 0 || animation.value >= 1) return;
    final t = Curves.easeOut.transform(animation.value);
    for (var i = 0; i < 14; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final origin = Offset(side < 0 ? 0 : size.width, size.height * (.30 + (i ~/ 2) * .064));
      final point = origin + Offset(side * (3 + t * (9 + (i % 4) * 3)), -t * (4 + i % 5 * 2));
      canvas.drawCircle(point, .8 + (i % 3) * .35,
        Paint()..color = const Color(0xFFFFF8DC).withValues(alpha: (1 - animation.value) * .85));
    }
  }
  @override
  bool shouldRepaint(_PreviewTouchSparkles oldDelegate) => oldDelegate.animation != animation;
}

/// A finite burst after the preview is gone. Deterministic decorative particles
/// never read hidden identities, routes or game state, and ignore all touches.
class CardPlayParticles extends StatelessWidget {
  const CardPlayParticles({super.key, required this.animation, this.cardRect});
  static const fadeDuration = Duration(seconds: 2);
  static const particleCount = 84;
  final Animation<double> animation;

  /// Preview bounds retained only for this finite UI animation, not in saves.
  final Rect? cardRect;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      key: const ValueKey('card-play-particles'),
      painter: _LightParticlePainter(animation, cardRect),
    ),
  );
}

class _LightParticlePainter extends CustomPainter {
  _LightParticlePainter(this.animation, this.cardRect)
    : super(repaint: animation);
  final Animation<double> animation;
  final Rect? cardRect;
  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final fade = math.pow(1 - t.clamp(0, 1), 1.15).toDouble();
    final rect =
        cardRect ??
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: math.min(340, math.max(1, size.width - 76)),
          height: math.max(1, size.height - 12),
        );
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(16)),
      );
    final perimeter = outline.computeMetrics().first;
    for (var i = 0; i < CardPlayParticles.particleCount; i++) {
      final tangent = perimeter.getTangentForOffset(
        perimeter.length *
            (i + .2 + (i % 3) * .17) /
            CardPlayParticles.particleCount,
      )!;
      final outward = tangent.position - rect.center;
      // 三层光点从原卡牌四周向外散开，距离/速度不同；两秒内连续渐隐。
      final spread = 10 + (i % 7) * 8.0;
      final initialSpread = (i % 3) * 5.0;
      final position =
          tangent.position +
          outward /
              outward.distance *
              (initialSpread + (1 - math.pow(1 - t, 2).toDouble()) * spread);
      final radius = 1.1 + (i % 7) * .6;
      canvas.drawCircle(
        position,
        radius * 2.0,
        Paint()
          ..color = Colors.white.withValues(alpha: fade * .48)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        position,
        radius,
        Paint()..color = Colors.white.withValues(alpha: fade * .92),
      );
    }
  }

  @override
  bool shouldRepaint(_LightParticlePainter oldDelegate) =>
      oldDelegate.animation != animation || oldDelegate.cardRect != cardRect;
}
