import 'package:flutter/material.dart';

import '../../game_constants.dart';
import '../../models/girl_card.dart';
import '../game_artwork.dart';
import '../game_theme.dart';
import 'crop_image_view.dart';
import '../game_night_style.dart';

/// 身份蓝光只由秘密反派阶段传入，公开阶段和隐私遮挡下不显示。
class GirlCardView extends StatelessWidget {
  const GirlCardView({
    super.key,
    required this.girl,
    required this.onTap,
    this.identitySelection = false,
    this.temporarySelection = false,
    this.revealedAccomplice = false,
    this.accompliceHighlight = false,
    this.selectedCenter = false,
    this.pendingSurveillance = false,
    this.currentRound = 1,
    this.infectionPlanLabel,
    this.terrain = false,
    this.night = false,
    this.rangeHint = false,
    this.hintPulseLit = false,
  });
  final GirlCard girl;
  final VoidCallback? onTap;
  final bool identitySelection;
  final bool temporarySelection;
  final bool revealedAccomplice;
  final bool accompliceHighlight;
  final bool selectedCenter;
  final bool pendingSurveillance;
  final int currentRound;
  final String? infectionPlanLabel;

  /// 农田地块模式：保持图片、标记和点击能力，底层土壤来自场景原图。
  final bool terrain;
  final bool night;
  final bool rangeHint;
  final bool hintPulseLit;

  @override
  Widget build(BuildContext context) {
    final imagePath = girl.cardImagePath?.trim();
    final crop = terrain && imagePath != null
        ? GameArtwork.cropForPath(imagePath)
        : null;
    final placeholder = GamePalette.cardBase(girl.id);
    final infectionColor = GamePalette.infectionRoundColor(girl.infectionRound);
    final borderColor = identitySelection
        ? GamePalette.crimson
        : accompliceHighlight
        ? GamePalette.markerBlue
        : selectedCenter
        ? GamePalette.sky
        : revealedAccomplice
        ? GamePalette.honey
        : pendingSurveillance
        ? GamePalette.markerBlue
        : terrain
        ? Colors.transparent
        : GamePalette.border;
    final glow = identitySelection || accompliceHighlight || selectedCenter;
    final frameBorder = Border.all(
      color: borderColor,
      width: glow || revealedAccomplice || pendingSurveillance ? 2 : 1,
    );
    return Semantics(
      label:
          '${girl.isInfected ? '啃食${girl.infectionRound}·${girl.infectionMethod?.label ?? '初始'}' : '未被啃食作物'}'
          '${girl.isMonitored ? '，有效标记' : ''}${pendingSurveillance ? '，待提交标记' : ''}'
          '${revealedAccomplice ? '，贪吃虫' : ''}',
      button: true,
      child: AnimatedScale(
        scale: identitySelection ? GameConstants.selectionScale : 1,
        duration: GameConstants.selectionDuration,
        child: AnimatedContainer(
          duration: GameConstants.selectionDuration,
          // 保留原边框占用的内边距，只把边框绘制顺序移到前景。
          padding: terrain ? EdgeInsets.zero : frameBorder.dimensions,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.65),
                      blurRadius: 8,
                      // 透明土地格仅在边缘发光，不能把土壤内部填成蓝/红色。
                      blurStyle: terrain ? BlurStyle.outer : BlurStyle.normal,
                    ),
                  ]
                : terrain
                ? const []
                : const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          // 边框最后绘制，人物图和任何指示物均不能盖住身份高亮。
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: frameBorder,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Material(
              color: terrain ? Colors.transparent : placeholder,
              child: InkWell(
                onTap: onTap,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 底色始终保留，图片未配置、加载中或失败时自动兜底。
                    ColoredBox(
                      key: ValueKey('card-placeholder-${girl.id}'),
                      color: terrain ? Colors.transparent : placeholder,
                    ),
                    if (crop != null)
                      GameNightStyle.apply(
                        night: night,
                        filter: GameNightStyle.crop,
                        key: ValueKey('crop-tint-${girl.id}'),
                        child: CropImageView(
                          artwork: crop,
                          plotId: girl.id,
                          eaten: girl.isInfected,
                        ),
                      )
                    else if (imagePath != null && imagePath.isNotEmpty)
                      GameNightStyle.apply(
                        night: night,
                        filter: GameNightStyle.crop,
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Image.asset(
                            imagePath,
                            key: ValueKey('card-image-${girl.id}'),
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            errorBuilder: (_, error, stackTrace) =>
                                SizedBox.expand(
                                  key: ValueKey(
                                    'card-image-fallback-${girl.id}',
                                  ),
                                ),
                          ),
                        ),
                      ),
                    if (girl.isInfected)
                      ColoredBox(
                        key: ValueKey('infection-tint-${girl.id}'),
                        color: infectionColor.withValues(alpha: 0.30),
                      ),
                    if (temporarySelection)
                      const ColoredBox(color: Color(0x55FFF8DE)),
                    if (pendingSurveillance)
                      const ColoredBox(color: Color(0x55AFCFD2)),
                    if (rangeHint)
                      IgnorePointer(
                        child: AnimatedOpacity(
                          key: ValueKey('range-hint-${girl.id}'),
                          opacity: hintPulseLit ? 0.48 : 0.16,
                          duration: const Duration(milliseconds: 650),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: GamePalette.sky,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: GamePalette.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 不显示角色名称或编号，纯色占位卡只保留游戏指示物。
                    Positioned(
                      top: 3,
                      left: 3,
                      right: 3,
                      bottom: 3,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: FittedBox(
                          key: ValueKey('card-mark-overlay-${girl.id}'),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topLeft,
                          // 整组指示物随卡片缩放，保留所有历史标记且不越界。
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (girl.isInfected)
                                _Mark(
                                  key: const ValueKey('infection-mark'),
                                  label:
                                      '啃食${girl.infectionRound}·${girl.infectionMethod?.label ?? '初始'}',
                                  color: infectionColor,
                                  foregroundColor: Colors.white,
                                ),
                              for (final mark in girl.surveillanceMarks)
                                _Mark(
                                  key: ValueKey('surveillance-${mark.round}'),
                                  label: '标记${mark.round}',
                                  color: mark.isActive
                                      ? GamePalette.sky
                                      : GamePalette.historical,
                                ),
                              if (pendingSurveillance)
                                _Mark(
                                  label: '待标记$currentRound',
                                  color: GamePalette.sky,
                                ),
                              if (infectionPlanLabel != null)
                                _Mark(
                                  label: infectionPlanLabel!,
                                  color: GamePalette.highlight,
                                ),
                              if (selectedCenter)
                                const _Mark(
                                  label: '中心',
                                  color: GamePalette.sky,
                                ),
                              if (revealedAccomplice)
                                const _Mark(
                                  label: '贪吃虫',
                                  color: GamePalette.honey,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Mark extends StatefulWidget {
  const _Mark({
    super.key,
    required this.label,
    required this.color,
    this.foregroundColor,
  });
  final String label;
  final Color color;
  final Color? foregroundColor;
  @override
  State<_Mark> createState() => _MarkState();
}

class _MarkState extends State<_Mark> with SingleTickerProviderStateMixin {
  late final AnimationController animation;
  @override
  void initState() {
    super.initState();
    animation = AnimationController(
      vsync: this,
      duration: GameConstants.markDuration,
    )..forward();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: animation,
    child: AnimatedContainer(
      duration: GameConstants.markDuration,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Text(
        widget.label,
        style: TextStyle(
          color:
              widget.foregroundColor ??
              (widget.color == GamePalette.crimson
                  ? Colors.white
                  : GamePalette.ink),
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    ),
  );
}
