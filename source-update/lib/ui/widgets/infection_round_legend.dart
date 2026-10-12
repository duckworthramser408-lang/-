import 'package:flutter/material.dart';

import '../game_theme.dart';

/// 仅解释公开的啃食轮次颜色，不读取或展示寄生身份。
class InfectionRoundLegend extends StatelessWidget {
  const InfectionRoundLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      const Text('啃食颜色：', style: TextStyle(fontSize: 11)),
      for (final entry in {
        0: GamePalette.initialInfection,
        ...GamePalette.infectionRoundColors,
      }.entries)
        Semantics(
          label: entry.key == 0 ? '初始啃食颜色' : '第${entry.key}回合啃食颜色',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: ValueKey('infection-legend-${entry.key}'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: entry.value,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 3),
              Text(
                entry.key == 0 ? '初始' : '${entry.key}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
    ],
  );
}
