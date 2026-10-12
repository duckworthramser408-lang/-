import 'package:flutter/material.dart';

/// 水粉纸片标题。缺图时保留可读标题，不影响入口。
class GameTitleImage extends StatelessWidget {
  const GameTitleImage({super.key, this.imagePath = assetPath});
  static const assetPath = 'assets/storybook/game_title.png';
  final String imagePath;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '捉虫子',
    image: true,
    child: AspectRatio(
      aspectRatio: 1672 / 940,
      child: Image.asset(
        imagePath,
        key: const ValueKey('game-title-image'),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => const Center(
          child: Text(
            '捉虫子',
            key: ValueKey('game-title-fallback'),
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    ),
  );
}
