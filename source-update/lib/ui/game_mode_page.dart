import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import 'game_theme.dart';
import 'paper_surface.dart';
import 'widgets/game_feedback_watermark.dart';
import 'widgets/game_rules_dialog.dart';
import 'widgets/mode_sticker_scene.dart';
import 'widgets/game_title_image.dart';

class GameModePage extends StatelessWidget {
  const GameModePage({
    super.key,
    required this.onSelected,
    this.loading = false,
  });
  final ValueChanged<GameMode> onSelected;
  final bool loading;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const ModeStickerScene(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const GameTitleImage(),
                    const SizedBox(height: 12),
                    _modeButton(
                      GameMode.twoPlayer,
                      Icons.people_outline,
                      '两位玩家共用设备，按隐私提示轮流操作',
                    ),
                    const SizedBox(height: 16),
                    _modeButton(
                      GameMode.computer,
                      Icons.smart_toy_outlined,
                      '你扮演戴夫，电脑秘密控制啃食',
                    ),
                    const SizedBox(height: 16),
                    PaperSurface(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        loading ? '正在读取本地进度…' : '两种模式分别保存本局进度',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          color: GamePalette.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: GamePalette.surface.withValues(
                          alpha: 0.90,
                        ),
                      ),
                      onPressed: loading
                          ? null
                          : () => showGameRulesDialog(context),
                      icon: const Icon(Icons.menu_book_outlined),
                      label: const Text('规则说明'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const GameFeedbackWatermark(),
      ],
    ),
  );

  Widget _modeButton(GameMode mode, IconData icon, String description) =>
      OutlinedButton(
        key: ValueKey('mode-${mode.name}'),
        onPressed: loading ? null : () => onSelected(mode),
        style: OutlinedButton.styleFrom(
          backgroundColor: GamePalette.surface.withValues(alpha: 0.9),
          padding: const EdgeInsets.all(18),
          shape: const PaperBorder(
            side: BorderSide(color: GamePalette.border, width: 1.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: ShapeDecoration(
                color: mode == GameMode.twoPlayer
                    ? GamePalette.highlight
                    : GamePalette.sky,
                shape: const PaperBorder(radius: 10),
              ),
              child: Icon(icon, size: 26, color: GamePalette.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: GamePalette.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      );
}
