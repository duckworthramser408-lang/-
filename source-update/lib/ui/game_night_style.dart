import 'package:flutter/material.dart';

/// 只改变渲染时的RGB，不改原始PNG、透明度、布局或游戏状态。
abstract final class GameNightStyle {
  // 水粉素材已为柔色；只轻微柔化、加暖，保留原绘本的绿色和土色。
  static const dayScene = ColorFilter.matrix([
    0.96063,
    0.03576,
    0.00361,
    0,
    2,
    0.01063,
    0.98576,
    0.00361,
    0,
    1,
    0.01063,
    0.03576,
    0.95361,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);
  static const scene = ColorFilter.matrix([
    0.43,
    0,
    0,
    0,
    0,
    0.04,
    0.50,
    0,
    0,
    0,
    0.12,
    0.16,
    0.55,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  // 作物稍亮于土壤，夜间仍能辨认品种；透明边缘保持原样。
  static const crop = ColorFilter.matrix([
    0.68,
    0,
    0,
    0,
    0,
    0.04,
    0.68,
    0,
    0,
    0,
    0.12,
    0.12,
    0.72,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  // 原浅色面板变为月夜蓝，原深色文字变为浅色，保持文字对比度。
  static const interface = ColorFilter.matrix([
    -0.17008,
    -0.57216,
    -0.05776,
    0,
    223,
    -0.174332,
    -0.586464,
    -0.059204,
    0,
    237,
    -0.14882,
    -0.50064,
    -0.05054,
    0,
    245,
    0,
    0,
    0,
    1,
    0,
  ]);

  static Widget apply({
    required bool night,
    required ColorFilter filter,
    required Widget child,
    ColorFilter? dayFilter,
    Key? key,
  }) => ColorFiltered(
    key: key,
    // 昼夜均保留相同组件树，切换不会重建格子或改变它们的位置。
    colorFilter: night
        ? filter
        : dayFilter ?? const ColorFilter.mode(Colors.white, BlendMode.modulate),
    child: child,
  );
}
