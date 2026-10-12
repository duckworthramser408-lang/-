import 'package:flutter/material.dart';

/// Stable pencil-like outline; geometry and hit testing remain rectangular.
class PaperBorder extends OutlinedBorder {
  const PaperBorder({super.side, this.radius = 12});
  final double radius;

  Path _outline(Rect rect) {
    final r = radius.clamp(0.0, rect.shortestSide / 3);
    return Path()
      ..moveTo(rect.left + r, rect.top + 1)
      ..quadraticBezierTo(
        rect.center.dx,
        rect.top - 1,
        rect.right - r,
        rect.top + 1,
      )
      ..quadraticBezierTo(
        rect.right - 1,
        rect.top,
        rect.right - 1,
        rect.top + r,
      )
      ..quadraticBezierTo(
        rect.right + 1,
        rect.center.dy,
        rect.right - 1,
        rect.bottom - r,
      )
      ..quadraticBezierTo(
        rect.right,
        rect.bottom - 1,
        rect.right - r,
        rect.bottom - 1,
      )
      ..quadraticBezierTo(
        rect.center.dx,
        rect.bottom + 1,
        rect.left + r,
        rect.bottom - 1,
      )
      ..quadraticBezierTo(
        rect.left + 1,
        rect.bottom,
        rect.left + 1,
        rect.bottom - r,
      )
      ..quadraticBezierTo(
        rect.left - 1,
        rect.center.dy,
        rect.left + 1,
        rect.top + r,
      )
      ..quadraticBezierTo(rect.left, rect.top + 1, rect.left + r, rect.top + 1)
      ..close();
  }

  @override
  PaperBorder copyWith({BorderSide? side}) =>
      PaperBorder(side: side ?? this.side, radius: radius);
  @override
  ShapeBorder scale(double t) =>
      PaperBorder(side: side.scale(t), radius: radius * t);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _outline(rect.deflate(side.width));
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_outline(rect.deflate(side.width / 2)), side.toPaint());
  }
}

/// The texture is cropped from the generated card's empty paper, never painted
/// into text. Pointer events and semantics pass through to the original child.
class PaperSurface extends StatelessWidget {
  const PaperSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: const Color(0xFFF5E8C9),
      image: const DecorationImage(
        image: AssetImage('assets/storybook/paper_texture.png'),
        fit: BoxFit.cover,
        opacity: .66,
        onError: _ignoreMissingTexture,
      ),
      shape: const PaperBorder(side: BorderSide(color: Color(0xFFAA9571))),
    ),
    child: Padding(padding: padding, child: child),
  );
}

void _ignoreMissingTexture(Object error, StackTrace? stackTrace) {}
