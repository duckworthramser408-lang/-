import 'package:flutter/material.dart';

import 'game_artwork.dart';
import 'game_theme.dart';
import 'widgets/game_feedback_watermark.dart';
import 'widgets/game_rules_dialog.dart';

/// 每次进入应用先阅读规则；确认前不挂载棋盘，避免与隐私弹窗重叠。
class GameIntroduction extends StatefulWidget {
  const GameIntroduction({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<GameIntroduction> createState() => _GameIntroductionState();
}

class _GameIntroductionState extends State<GameIntroduction> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showGameRulesDialog(context, enteringGame: true);
      if (mounted) widget.onContinue();
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Image.asset(
              GameArtwork.modeBackgroundPath,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) =>
                  const ColoredBox(color: GamePalette.canvas),
            ),
          ),
          const GameFeedbackWatermark(),
        ],
      ),
    ),
  );
}
