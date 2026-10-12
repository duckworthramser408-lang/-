import 'package:flutter/material.dart';

import '../../models/deduction_notes.dart';
import '../game_theme.dart';

/// 拖拽载荷只含玩家笔记，不包含来源身份、行动中心或目标。
class DeductionDrag {
  const DeductionDrag(this.symbol, {this.fromPlotId});
  final DeductionSymbol symbol;
  final int? fromPlotId;
}

/// 水印下方的44像素触屏工具栏；只在戴夫可行动时挂载。
class DeductionNoteToolbar extends StatelessWidget {
  const DeductionNoteToolbar({super.key, required this.notes});
  final DeductionNotes notes;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Padding(
        padding: EdgeInsets.only(right: 8),
        child: Text(
          '推理笔记',
          style: TextStyle(fontSize: 11, color: GamePalette.ink),
        ),
      ),
      for (final symbol in DeductionSymbol.values)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Draggable<DeductionDrag>(
              key: ValueKey('deduction-source-${symbol.name}'),
              data: DeductionDrag(symbol),
              maxSimultaneousDrags: notes.count(symbol) < symbol.maximumNotes
                  ? 1
                  : 0,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: _feedback(symbol, 48),
              childWhenDragging: Opacity(opacity: 0.35, child: _source(symbol)),
              child: _source(symbol),
            ),
          ),
        ),
    ],
  );

  Widget _source(DeductionSymbol symbol) => Semantics(
    label:
        '拖动${symbol.label}到作物，已放${notes.count(symbol)}个，最多${symbol.maximumNotes}个',
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: GamePalette.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GamePalette.border),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DeductionGlyph(symbol: symbol, size: 32),
              const SizedBox(width: 4),
              Text(
                '${notes.count(symbol)}/${symbol.maximumNotes}',
                style: const TextStyle(fontSize: 12, color: GamePalette.ink),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// 目标区域完全沿用土地坐标。笔记点击/拖拽只操作笔记，不触发底层正式标记。
class DeductionNotePlot extends StatelessWidget {
  const DeductionNotePlot({
    super.key,
    required this.plotId,
    required this.notes,
    required this.enabled,
    required this.onPlace,
    required this.onRemove,
    required this.child,
  });
  final int plotId;
  final DeductionNotes notes;
  final bool enabled;
  final void Function(int, DeductionDrag) onPlace;
  final void Function(int) onRemove;
  final Widget child;

  @override
  Widget build(BuildContext context) => DragTarget<DeductionDrag>(
    key: ValueKey('deduction-target-$plotId'),
    onWillAcceptWithDetails: (details) =>
        enabled &&
        !identical(
          notes,
          notes.place(
            plotId,
            details.data.symbol,
            fromPlotId: details.data.fromPlotId,
          ),
        ),
    onAcceptWithDetails: (details) => onPlace(plotId, details.data),
    builder: (context, candidates, rejected) => Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (candidates.isNotEmpty)
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Colors.white70, width: 2),
                ),
              ),
            ),
          ),
        if (notes.plots[plotId] case final symbol?)
          LayoutBuilder(
            builder: (context, constraints) {
              final size = (constraints.maxWidth * 0.68).clamp(20.0, 48.0);
              final glyph = DeductionGlyph(symbol: symbol, size: size);
              return Align(
                alignment: Alignment.center,
                child: enabled
                    ? Draggable<DeductionDrag>(
                        key: ValueKey('deduction-note-$plotId'),
                        data: DeductionDrag(symbol, fromPlotId: plotId),
                        dragAnchorStrategy: pointerDragAnchorStrategy,
                        feedback: _feedback(symbol, size),
                        childWhenDragging: Opacity(opacity: 0.15, child: glyph),
                        child: Semantics(
                          label: '${symbol.label}推理笔记，点击删除，拖动换位',
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onRemove(plotId),
                            child: glyph,
                          ),
                        ),
                      )
                    : IgnorePointer(child: glyph),
              );
            },
          ),
      ],
    ),
  );
}

Widget _feedback(DeductionSymbol symbol, double size) => Transform.translate(
  offset: Offset(-size / 2, -size / 2),
  child: Material(
    color: Colors.transparent,
    child: DeductionGlyph(symbol: symbol, size: size),
  ),
);

/// 粗线条、圆端、58%不透明度；原作物轮廓和位置保持可见。
class DeductionGlyph extends StatelessWidget {
  const DeductionGlyph({super.key, required this.symbol, required this.size});
  final DeductionSymbol symbol;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _DeductionPainter(symbol)),
  );
}

class _DeductionPainter extends CustomPainter {
  const _DeductionPainter(this.symbol);
  final DeductionSymbol symbol;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          (symbol == DeductionSymbol.check
                  ? GamePalette.markerBlue
                  : GamePalette.crimson)
              .withValues(alpha: 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    if (symbol == DeductionSymbol.check) {
      path.moveTo(size.width * 0.18, size.height * 0.52);
      path.lineTo(size.width * 0.42, size.height * 0.74);
      path.lineTo(size.width * 0.82, size.height * 0.26);
    } else {
      path.moveTo(size.width * 0.24, size.height * 0.24);
      path.lineTo(size.width * 0.76, size.height * 0.76);
      path.moveTo(size.width * 0.76, size.height * 0.24);
      path.lineTo(size.width * 0.24, size.height * 0.76);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DeductionPainter oldDelegate) =>
      oldDelegate.symbol != symbol;
}
