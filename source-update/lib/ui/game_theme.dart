import 'package:flutter/material.dart';

import 'paper_surface.dart';

/// 只定义视觉样式，不包含阶段、标记或啃食规则。
abstract final class GamePalette {
  // 绘本农场：浅色纸面、棕色铅笔、鼠尾草绿、水蓝与蜜黄。
  static const canvas = Color(0xFFB7C894);
  static const panel = Color(0xF5F5E8C9);
  static const surface = Color(0xFFFFF6DF);
  static const silver = Color(0xFF526C43);
  static const border = Color(0xFFAA9571);
  static const ink = Color(0xFF634936);
  static const muted = Color(0xFF776249);
  static const ice = Color(0xFF4F6940);
  static const crimson = Color(0xFFAC5945);
  static const historical = Color(0xFF9E9B89);
  static const warning = Color(0xFF865815);
  static const highlight = Color(0xFFF0D99B);
  static const initialInfection = Color(0xFF705846);
  static const leaf = Color(0xFF8CAA70);
  static const honey = Color(0xFFE7B65F);
  static const sky = Color(0xFFAFCFD2);
  static const markerBlue = Color(0xFF527F95);
  static const peach = Color(0xFFD99883);
  static const nightPaper = Color(0xFF293E48);
  static const nightInk = Color(0xFFF5E8C9);
  static const infectionRoundColors = <int, Color>{
    1: Color(0xFFAA5340),
    2: Color(0xFF8F6B22),
    3: Color(0xFF457967),
    4: Color(0xFF4D719A),
    5: Color(0xFF81619B),
    6: Color(0xFFA44F72),
  };

  /// 以作物实际被啃食的轮次着色，历史指示物不会随当前回合变色。
  static Color infectionRoundColor(int? round) =>
      infectionRoundColors[round] ?? initialInfection;

  static Color cardBase(int id) => Color.lerp(
    const Color(0xFFBC9266),
    const Color(0xFFE2BE87),
    (id % 5) / 4,
  )!;
}

ThemeData buildGameTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: GamePalette.ice,
        brightness: Brightness.light,
      ).copyWith(
        primary: GamePalette.ice,
        onPrimary: GamePalette.surface,
        surface: GamePalette.surface,
        onSurface: GamePalette.ink,
        onSurfaceVariant: GamePalette.muted,
        outline: GamePalette.border,
      );
  const shape = PaperBorder();
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'WenKai',
    colorScheme: scheme,
    scaffoldBackgroundColor: GamePalette.canvas,
    textTheme: ThemeData(brightness: Brightness.light).textTheme.apply(
      bodyColor: GamePalette.ink,
      displayColor: GamePalette.ink,
      fontFamily: 'WenKai',
    ),
    iconTheme: const IconThemeData(color: GamePalette.silver),
    cardTheme: CardThemeData(
      color: GamePalette.surface.withValues(alpha: 0.88),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: const PaperBorder(side: BorderSide(color: GamePalette.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(
          fontFamily: 'WenKai',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: GamePalette.silver,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        side: const BorderSide(color: GamePalette.border),
        backgroundColor: GamePalette.surface,
        textStyle: const TextStyle(fontFamily: 'WenKai', fontSize: 13),
        shape: shape,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: GamePalette.canvas,
      selectedColor: GamePalette.highlight,
      side: const BorderSide(color: GamePalette.border),
      shape: const PaperBorder(radius: 8),
      labelStyle: const TextStyle(
        fontFamily: 'WenKai',
        color: GamePalette.ink,
        fontSize: 12,
      ),
      padding: const EdgeInsets.all(5),
      showCheckmark: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GamePalette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const PaperBorder(
        radius: 16,
        side: BorderSide(color: GamePalette.border),
      ),
      titleTextStyle: const TextStyle(
        fontFamily: 'WenKai',
        color: GamePalette.ink,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerTheme: const DividerThemeData(color: GamePalette.border),
  );
}
