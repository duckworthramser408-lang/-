import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_constants.dart';
import '../game_theme.dart';
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
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..forward();
  @override
  void didUpdateWidget(ActionCardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.closing != oldWidget.closing) {
      if (widget.closing) {
        _fade.reverse();
      } else {
        _fade.forward();
      }
    }
  }

  @override
  void dispose() {
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
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: GestureDetector(
                  key: widget.frameKey,
                  onTap: () {}, // Artwork itself is not blank dismiss space.
                  child: Container(
                    key: const ValueKey('card-preview-content'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.night
                          ? GamePalette.nightPaper
                          : GamePalette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: GamePalette.honey),
                      boxShadow: const [
                        BoxShadow(color: Colors.black38, blurRadius: 18),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '行动牌 · ${widget.card.label}',
                          key: const ValueKey('preview-card-name'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.night
                                ? GamePalette.highlight
                                : GamePalette.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: ActionCardImage(
                            key: const ValueKey(
                              'preview-high-resolution-image',
                            ),
                            card: widget.card,
                            highResolution: true,
                            // Native instructions remain bright on either paper.
                            night: widget.night,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.card.displayInstructions.map((method) => method == InfectionMethod.ring ? '环：周围八格' : '十：同一行或列').join('；')}。\n每个指示由不同贪吃虫啃食一个作物。',
                          key: const ValueKey('preview-card-effect'),
                          textScaler: TextScaler.linear(
                            math.min(
                              MediaQuery.textScalerOf(context).scale(1),
                              1.3,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.25,
                            color: widget.night
                                ? GamePalette.nightInk
                                : GamePalette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
