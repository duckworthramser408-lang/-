import 'package:flutter/material.dart';

import '../../game_constants.dart';
import '../game_theme.dart';

/// 行动牌静态示意图标；棋盘不动态绘制啃食范围。
class InfectionMethodIcon extends StatelessWidget {
  const InfectionMethodIcon({
    super.key,
    required this.method,
    this.size = 26,
    this.color = GamePalette.ice,
  });
  final InfectionMethod method;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: method == InfectionMethod.ring ? '周边啃食（环）：周边八格' : '行列啃食（十）：整行或整列',
    child: Semantics(
      label: method == InfectionMethod.ring ? '周边啃食' : '行列啃食',
      image: true,
      child: CustomPaint(
        size: Size.square(size),
        painter: _MethodPainter(method, color),
      ),
    ),
  );
}

class OmenInstructionsView extends StatelessWidget {
  const OmenInstructionsView({
    super.key,
    required this.instructions,
    this.color = GamePalette.ice,
  });
  final List<InfectionMethod> instructions;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < instructions.length; index++) ...[
        if (index > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text('＋', style: TextStyle(color: color)),
          ),
        InfectionMethodIcon(method: instructions[index], color: color),
      ],
    ],
  );
}

class _MethodPainter extends CustomPainter {
  const _MethodPainter(this.method, this.color);
  final InfectionMethod method;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 26, size.height / 26);
    // 固定的水粉边缘与轻微纸纹；重绘不随机抖动，指示方向始终准确。
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 26, 26), Paint());
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (method == InfectionMethod.ring) {
      const cell = 26 / 3;
      for (var row = 0; row < 3; row++) {
        for (var column = 0; column < 3; column++) {
          if (row == 1 && column == 1) continue;
          final left = column * cell + 1.3;
          final top = row * cell + 1.3;
          final extent = cell - 2.6;
          final wobble = ((row * 3 + column) % 3 - 1) * .22;
          final patch = Path()
            ..moveTo(left + 1.3, top + wobble)
            ..quadraticBezierTo(
              left + extent / 2,
              top - .2,
              left + extent - 1,
              top + .2,
            )
            ..quadraticBezierTo(
              left + extent + .25,
              top + .4,
              left + extent,
              top + 1.4,
            )
            ..quadraticBezierTo(
              left + extent - wobble,
              top + extent / 2,
              left + extent - .1,
              top + extent - 1,
            )
            ..quadraticBezierTo(
              left + extent - .4,
              top + extent + .15,
              left + extent - 1.5,
              top + extent,
            )
            ..quadraticBezierTo(
              left + extent / 2,
              top + extent - wobble,
              left + 1.1,
              top + extent - .1,
            )
            ..quadraticBezierTo(
              left - .15,
              top + extent - .2,
              left + .1,
              top + extent - 1.5,
            )
            ..quadraticBezierTo(
              left + wobble,
              top + extent / 2,
              left,
              top + 1.3,
            )
            ..quadraticBezierTo(left - .1, top + .1, left + 1.3, top + wobble)
            ..close();
          canvas.drawPath(patch, paint);
        }
      }
    } else {
      // 四端箭头仍表示整行/整列，圆润笔触只改变美术表现。
      final arrows = Path()
        ..moveTo(2.7, 13.1)
        ..quadraticBezierTo(13, 12.35, 23.3, 13)
        ..moveTo(13, 2.7)
        ..quadraticBezierTo(13.65, 13, 13.05, 23.3)
        ..moveTo(5.6, 9.95)
        ..quadraticBezierTo(3.95, 11.25, 2.7, 13.1)
        ..quadraticBezierTo(3.95, 14.85, 5.6, 16.05)
        ..moveTo(20.35, 9.95)
        ..quadraticBezierTo(22, 11.25, 23.3, 13)
        ..quadraticBezierTo(22, 14.85, 20.4, 16.05)
        ..moveTo(10, 5.65)
        ..quadraticBezierTo(11.25, 3.95, 13, 2.7)
        ..quadraticBezierTo(14.8, 3.95, 16.05, 5.6)
        ..moveTo(10, 20.35)
        ..quadraticBezierTo(11.25, 22, 13.05, 23.3)
        ..quadraticBezierTo(14.8, 22, 16.05, 20.35);
      paint
        ..style = PaintingStyle.stroke
        ..color = color.withValues(alpha: color.a * .18)
        ..strokeWidth = 3.5;
      canvas.drawPath(arrows, paint);
      paint
        ..color = color
        ..strokeWidth = 2.35;
      canvas.drawPath(arrows, paint);
    }
    paint
      ..style = PaintingStyle.fill
      ..color = color;
    canvas.drawOval(const Rect.fromLTWH(10.65, 10.8, 4.65, 4.45), paint);
    final grain = Paint()
      ..color = const Color(0x28000000)
      ..blendMode = BlendMode.dstOut;
    for (var index = 0; index < 35; index++) {
      canvas.drawCircle(
        Offset(1.5 + (index * 7.13) % 23, 1.5 + (index * 11.37) % 23),
        .17 + (index % 3) * .045,
        grain,
      );
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MethodPainter oldDelegate) =>
      oldDelegate.method != method || oldDelegate.color != color;
}
