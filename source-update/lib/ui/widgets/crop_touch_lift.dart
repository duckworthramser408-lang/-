import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../crop_touch_controller.dart';

/// 仅变换作物图，地块、点击区域与标记都保持原坐标。
class CropTouchLift extends StatefulWidget {
  const CropTouchLift({super.key, required this.plotId, required this.motion, required this.child});
  final int plotId;
  final CropTouchController motion;
  final Widget child;
  @override
  State<CropTouchLift> createState() => _CropTouchLiftState();
}

class _CropTouchLiftState extends State<CropTouchLift>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _lift = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 90), reverseDuration: const Duration(milliseconds: 360));
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    widget.motion.addListener(_touch);
    WidgetsBinding.instance.addObserver(this);
    _lift.addStatusListener((status) {
      if (status == AnimationStatus.completed && !widget.motion.held.contains(widget.plotId)) _lift.reverse();
    });
  }
  void _touch() {
    if (!_foreground) return;
    if (widget.motion.held.contains(widget.plotId) || widget.motion.swept.contains(widget.plotId)) {
      _lift.forward();
    } else if (!_lift.isAnimating || _lift.status == AnimationStatus.reverse) {
      _lift.reverse();
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) { _lift.stop(); _lift.value = 0; }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.motion.removeListener(_touch);
    _lift.dispose(); super.dispose();
  }
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) =>
    AnimatedBuilder(animation: _lift, child: widget.child, builder: (context, child) {
      final t = Curves.easeOut.transform(_lift.value);
      return Transform.translate(key: ValueKey('crop-lift-${widget.plotId}'),
        offset: Offset(0, -constraints.maxHeight * .23 * t), transformHitTests: false,
        child: Transform.rotate(angle: .035 * math.sin(math.pi * t), transformHitTests: false,
          child: Transform.scale(scale: 1 + .10 * t, transformHitTests: false, child: child)));
    }));
}
