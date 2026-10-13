import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_constants.dart';
import '../action_card_artwork.dart';
import '../game_night_style.dart';
import '../game_theme.dart';
import 'omen_instruction_icons.dart';

/// Each original card keeps its independent ID. Scrolling and previewing never
/// play a card: only the page's explicit play button calls the original engine.
class ActionCardHand extends StatelessWidget {
  const ActionCardHand({
    super.key,
    required this.cards,
    required this.selectedId,
    required this.enabled,
    required this.onSelect,
    this.playableIds,
  });
  final List<OmenCard> cards;
  final int? selectedId;
  final bool enabled;
  final ValueChanged<int> onSelect;
  final Set<int>? playableIds;
  bool _playable(int id) => enabled && (playableIds?.contains(id) ?? true);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Space for the gentle lift/scale; no card spills into the button row.
      final height = math.max(1.0, constraints.maxHeight - 20);
      final width = math.max(48.0, height * 941 / 1672);
      return SingleChildScrollView(
        key: const ValueKey('action-hand-scroll'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
        child: Row(
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedSlide(
                  key: ValueKey('card-lift-${card.id}'),
                  offset: selectedId == card.id
                      ? const Offset(0, -.035)
                      : Offset.zero,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  child: AnimatedScale(
                    key: ValueKey('card-scale-${card.id}'),
                    scale: selectedId == card.id ? 1.04 : 1,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    child: Semantics(
                      label:
                          '行动牌${card.id}，${card.label}，${_playable(card.id) ? '点击预览，再次点击关闭' : '已打出或暂不可操作'}',
                      button: true,
                      selected: selectedId == card.id,
                      child: InkWell(
                        key: ValueKey('omen-card-${card.id}'),
                        onTap: _playable(card.id)
                            ? () => onSelect(card.id)
                            : null,
                        borderRadius: BorderRadius.circular(9),
                        child: Container(
                          width: width,
                          height: height,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: selectedId == card.id
                                  ? GamePalette.honey
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeInOut,
                            opacity:
                                playableIds == null ||
                                    playableIds!.contains(card.id)
                                ? 1
                                : .48,
                            child: ActionCardImage(card: card),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// The current played card remains visible, fades gently and cannot be tapped.
/// The next night gets its new remaining hand from the unchanged game state.
class PlayedActionCard extends StatelessWidget {
  const PlayedActionCard({
    super.key,
    required this.card,
    required this.night,
    this.padding = const EdgeInsets.fromLTRB(10, 12, 10, 8),
  });
  final OmenCard card;
  final bool night;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: '已打出行动牌${card.id}，${card.label}，不可再次打出',
      child: TweenAnimationBuilder<double>(
        key: const ValueKey('played-card-dimming'),
        tween: Tween(begin: 1, end: .48),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AspectRatio(
              aspectRatio: 941 / 1672,
              child: ActionCardImage(card: card, night: night),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Only completed/public nights enter this row. Latest night is on the left;
/// duplicate artwork and night-six reuse remain separate round-labelled cards.
class PlayedActionHistory extends StatelessWidget {
  const PlayedActionHistory({
    super.key,
    required this.playedCardIds,
    required this.night,
  });
  final List<int> playedCardIds;
  final bool night;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = math.max(1.0, constraints.maxHeight - 12);
      return SingleChildScrollView(
        key: const ValueKey('action-history-scroll'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          textDirection: TextDirection.ltr,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var index = playedCardIds.length - 1; index >= 0; index--)
              Padding(
                key: ValueKey('action-history-round-${index + 1}'),
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: math.max(
                    40.0,
                    (height * (index == playedCardIds.length - 1 ? 1 : .78) -
                            20) *
                        941 /
                        1672,
                  ),
                  height:
                      height * (index == playedCardIds.length - 1 ? 1 : .78),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 20,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '第 ${index + 1} 回合',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: night
                                  ? const Color(0xFFE3EDDC)
                                  : const Color(0xFF534027),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: PlayedActionCard(
                          card: GameConstants.omenById(playedCardIds[index]),
                          night: night,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Painted card paper and native instructions stay separate, so the art can
/// change without altering the number, direction or order of legal actions.
class ActionCardImage extends StatelessWidget {
  const ActionCardImage({
    super.key,
    required this.card,
    this.imagePath,
    this.night = true,
    this.highResolution = false,
    this.previewDetails = false,
  });
  final OmenCard card;
  final String? imagePath;
  final bool night;
  final bool highResolution;
  final bool previewDetails;

  @override
  Widget build(BuildContext context) => GameNightStyle.apply(
    night: night,
    filter: imagePath == null
        ? const ColorFilter.mode(Colors.white, BlendMode.modulate)
        : GameNightStyle.crop,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final foreground = night ? GamePalette.nightInk : GamePalette.ink;
        final image = Image.asset(
          imagePath ??
              (night
                  ? ActionCardArtwork.nightPaperPath
                  : ActionCardArtwork.paperPath),
          key: ValueKey('action-card-image-${card.id}'),
          fit: BoxFit.contain,
          cacheWidth: highResolution
              ? 941
              : math.max(
                  1,
                  (constraints.maxWidth *
                          MediaQuery.devicePixelRatioOf(context))
                      .ceil(),
                ),
          errorBuilder: (context, error, stackTrace) => Center(
            key: ValueKey('action-card-fallback-${card.id}'),
            child: FittedBox(
              child: OmenInstructionsView(
                instructions: card.displayInstructions,
              ),
            ),
          ),
        );
        if (imagePath != null) return image;
        final width = math.min(
          constraints.maxWidth,
          constraints.maxHeight * 941 / 1672,
        );
        final height = width * 1672 / 941;
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRRect(
              key: ValueKey('action-card-rounded-${card.id}'),
              borderRadius: BorderRadius.circular(
                previewDetails ? width * .065 : 0,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image,
                  Positioned(
                    left: width * .12,
                    right: width * .12,
                    top: height * .10,
                    height: height * .09,
                    child: FittedBox(
                      child: Text(
                        '行动牌 ${card.id.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: foreground,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * .12,
                    right: width * .12,
                    top: height * .24,
                    height: height * .13,
                    child: FittedBox(
                      child: OmenInstructionsView(
                        instructions: card.displayInstructions,
                        color: foreground,
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * .15,
                    right: width * .15,
                    top: height * .40,
                    height: height * .06,
                    child: FittedBox(
                      child: Text(
                        card.displayInstructions
                            .map((method) => method.label)
                            .join(' ＋ '),
                        style: TextStyle(color: foreground, fontSize: 14),
                      ),
                    ),
                  ),
                  if (!previewDetails)
                    Positioned(
                      left: width * .16,
                      right: width * .16,
                      top: height * .86,
                      height: height * .055,
                      child: FittedBox(
                        child: Text(
                          '啃食 ${card.instructions.length} 次',
                          style: TextStyle(color: foreground, fontSize: 14),
                        ),
                      ),
                    ),
                  if (previewDetails)
                    Positioned(
                      left: width * .13,
                      right: width * .13,
                      top: height * .795,
                      height: height * .045,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '行动牌 · ${card.label}',
                          key: const ValueKey('preview-card-name'),
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (previewDetails)
                    Positioned(
                      left: width * .12,
                      right: width * .12,
                      top: height * .845,
                      height: height * .10,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${card.displayInstructions.map((method) => method == InfectionMethod.ring ? '环：周围八格' : '十：同一行或列').join('；')}。\n每个指示由不同贪吃虫\n啃食一个作物。',
                          key: const ValueKey('preview-card-effect'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
