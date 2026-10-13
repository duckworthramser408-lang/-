import 'dart:async';

import 'package:flutter/material.dart';

import '../audio/background_music_controller.dart';
import '../game/game_controller.dart';
import '../game_constants.dart';
import '../models/game_state.dart';
import 'game_artwork.dart';
import 'farm_scene_geometry.dart';
import 'crop_touch_controller.dart';
import '../audio/action_sound_controller.dart';
import 'game_theme.dart';
import 'paper_surface.dart';
import 'game_night_style.dart';
import 'widgets/game_scene_background.dart';
import 'widgets/game_feedback_watermark.dart';
import 'widgets/game_rules_dialog.dart';
import 'widgets/girl_card_view.dart';
import 'widgets/worm_walkway.dart';
import 'widgets/action_button_hint.dart';
import 'widgets/deduction_note_widgets.dart';
import 'widgets/action_card_hand.dart';
import 'widgets/action_card_preview.dart';

enum _DialogAction { continueGame, reset, close }

enum _SettingsAction { rules, modes, reset }

class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.controller, this.onReturnToModes});
  final GameController controller;
  final VoidCallback? onReturnToModes;
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _cropTouch = CropTouchController();
  final _cardSound = ActionSoundController();
  bool _dialogOpen = false;
  bool _dialogScheduled = false;
  bool _resultDismissed = false;
  bool _backgrounded = false;
  bool _resumeCurtain = false;
  bool _hintPulseLit = false;
  int? _previewOmenId;
  bool _previewClosing = false;
  bool _playAnimating = false;
  Timer? _previewTimer;
  late final AnimationController _playParticles;
  final _previewFrameKey = GlobalKey();
  final _previewAreaKey = GlobalKey();
  Rect? _playedPreviewRect;
  late final BackgroundMusicController _music;
  Timer? _hintFirstPulse;
  Timer? _hintPulseTimer;
  GameController get controller => widget.controller;
  GameState get state => controller.state;
  bool get _computerMode => controller.isComputerMode;
  bool get _handInteractionEnabled =>
      !_computerMode &&
      state.phase == GamePhase.chooseOmen &&
      !_dialogOpen &&
      !controller.resumePrivacyRequired &&
      !_resumeCurtain &&
      !_backgrounded;

  bool get _nightScene =>
      controller.isComputerTurn ||
      {
        GamePhase.openingPrivacy,
        GamePhase.chooseAccomplices,
        GamePhase.chooseInitialInfection,
        GamePhase.nightPrivacy,
        GamePhase.chooseOmen,
        GamePhase.accompliceTurn,
      }.contains(state.phase);

  Widget _nightInterface(Widget child) => GameNightStyle.apply(
    night: _nightScene,
    filter: GameNightStyle.interface,
    child: child,
  );

  bool get _isPrivacy => {
    GamePhase.openingPrivacy,
    GamePhase.nightPrivacy,
    GamePhase.heroPrivacy,
  }.contains(state.phase);

  bool get _secretTurn => {
    GamePhase.chooseAccomplices,
    GamePhase.chooseInitialInfection,
    GamePhase.chooseOmen,
    GamePhase.accompliceTurn,
  }.contains(state.phase);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _music = BackgroundMusicController()..addListener(_onMusicChanged);
    _music.initialize();
    _playParticles =
        AnimationController(
          vsync: this,
          duration: CardPlayParticles.fadeDuration,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) setState(() {});
        });
    _cardSound.prepare();
    controller.addListener(_onChanged);
    _startHintPulse();
    _scheduleDialog();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _music.removeListener(_onMusicChanged);
    _music.dispose();
    _previewTimer?.cancel();
    _playParticles.dispose();
    _cropTouch.dispose();
    _cardSound.dispose();
    controller.removeListener(_onChanged);
    _stopHintPulse();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.inactive ||
        lifecycle == AppLifecycleState.paused) {
      _backgrounded = true;
      _cropTouch.reset();
      _cardSound.stop();
      _dismissPreviewImmediately();
      _playParticles.stop();
      _music.setSceneActive(false);
      _stopHintPulse();
      controller.flushSave();
      if (_secretTurn && !_computerMode) setState(() => _resumeCurtain = true);
    } else if (lifecycle == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      _music.setSceneActive(true);
      _startHintPulse();
      if (_secretTurn && !_computerMode) _scheduleDialog();
    }
  }

  void _onMusicChanged() {
    if (mounted) setState(() {});
  }

  void _startHintPulse() {
    _stopHintPulse();
    _hintFirstPulse = Timer(const Duration(milliseconds: 100), _pulseHints);
    // 与装饰虫同周期，动画间保留停留，不持续请求帧。
    _hintPulseTimer = Timer.periodic(
      const Duration(milliseconds: 2800),
      (_) => _pulseHints(),
    );
  }

  void _pulseHints() {
    if (mounted) setState(() => _hintPulseLit = !_hintPulseLit);
  }

  void _stopHintPulse() {
    _hintFirstPulse?.cancel();
    _hintPulseTimer?.cancel();
  }

  Widget _hintButton(String label, bool enabled, Widget child) =>
      ActionButtonHint(
        key: ValueKey('action-button-hint-$label'),
        enabled:
            enabled &&
            !_dialogOpen &&
            !controller.resumePrivacyRequired &&
            !_resumeCurtain,
        lit: _hintPulseLit,
        label: label,
        night: _nightScene,
        child: child,
      );

  void _onChanged() {
    if (!mounted) return;
    if (_isPrivacy || controller.isComputerTurn) _cropTouch.reset();
    if (state.phase != GamePhase.gameOver) _resultDismissed = false;
    if (!_playAnimating &&
        (state.phase != GamePhase.chooseOmen || _computerMode)) {
      _dismissPreviewImmediately();
    }
    setState(() {});
    _scheduleDialog();
  }

  void _selectPreview(int id) {
    if (!_handInteractionEnabled || _playAnimating) return;
    if (_previewOmenId == id && !_previewClosing) {
      _closePreview();
      return;
    }
    _previewTimer?.cancel();
    // Reopening a persisted selection must not toggle it off accidentally.
    if (state.selectedOmenId != id) controller.toggleOmenSelection(id);
    setState(() {
      _previewOmenId = id;
      _previewClosing = false;
    });
  }

  void _dismissPreviewImmediately() {
    _previewTimer?.cancel();
    _previewOmenId = null;
    _previewClosing = false;
    _playAnimating = false;
  }

  void _closePreview() {
    if (_previewOmenId == null || _playAnimating) return;
    setState(() => _previewClosing = true);
    if (_handInteractionEnabled && state.selectedOmenId == _previewOmenId) {
      controller.toggleOmenSelection(_previewOmenId!);
    }
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(_dismissPreviewImmediately);
    });
  }

  void _playPreviewCard() {
    if (!_handInteractionEnabled || !controller.canPlayOmen || _playAnimating) {
      return;
    }
    final id = state.selectedOmenId;
    _playedPreviewRect = null;
    final frame = _previewFrameKey.currentContext?.findRenderObject();
    final area = _previewAreaKey.currentContext?.findRenderObject();
    if (frame is RenderBox && area is RenderBox && frame.hasSize) {
      _playedPreviewRect =
          frame.localToGlobal(Offset.zero, ancestor: area) & frame.size;
    }
    _playAnimating = true;
    controller
        .playOmen(); // The existing engine alone decides success/win/phase.
    if (state.playedOmenId != id || state.phase == GamePhase.chooseOmen) {
      _playAnimating = false;
      return;
    }
    setState(() => _previewClosing = true);
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted || _backgrounded) return;
      setState(_dismissPreviewImmediately);
      // Particles begin only AFTER the successful preview exit has completed.
      _playParticles.forward(from: 0);
      if (_music.enabled) _cardSound.play();
    });
  }

  Future<void> _openSettings() async {
    if (_dialogOpen || _dialogScheduled) return;
    _closePreview();
    setState(() => _dialogOpen = true);
    final choice = await showMenu<_SettingsAction>(
      context: context,
      color: _nightScene ? const Color(0xFF19303D) : GamePalette.panel,
      menuPadding: const EdgeInsets.symmetric(vertical: 8),
      position: RelativeRect.fromLTRB(
        60,
        MediaQuery.paddingOf(context).top + 58,
        8,
        0,
      ),
      items: [
        PopupMenuItem(
          key: const ValueKey('game-rules-button'),
          value: _SettingsAction.rules,
          child: Text(
            '规则说明',
            style: TextStyle(
              color: _nightScene ? const Color(0xFFE3EDDC) : GamePalette.ink,
            ),
          ),
        ),
        PopupMenuItem(
          key: const ValueKey('return-mode-selection'),
          value: _SettingsAction.modes,
          enabled: widget.onReturnToModes != null,
          child: Text(
            '切换模式',
            style: TextStyle(
              color: _nightScene ? const Color(0xFFE3EDDC) : GamePalette.ink,
            ),
          ),
        ),
        PopupMenuItem(
          key: const ValueKey('reset-game-button'),
          value: _SettingsAction.reset,
          child: Text(
            '重置游戏',
            style: TextStyle(
              color: _nightScene ? const Color(0xFFE3EDDC) : GamePalette.ink,
            ),
          ),
        ),
      ],
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    switch (choice) {
      case _SettingsAction.rules:
        await _openRules();
      case _SettingsAction.modes:
        await _confirmReturnToModes();
      case _SettingsAction.reset:
        await _confirmReset();
      case null:
        _scheduleDialog();
    }
  }

  void _scheduleDialog() {
    if (_dialogOpen || _dialogScheduled) return;
    final needed =
        (_isPrivacy &&
            (!_computerMode || state.phase == GamePhase.heroPrivacy)) ||
        controller.resumePrivacyRequired ||
        _resumeCurtain ||
        (state.phase == GamePhase.gameOver && !_resultDismissed);
    if (!needed) return;
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogScheduled = false;
      if (mounted && !_dialogOpen) _showPhaseDialog();
    });
  }

  Future<void> _showPhaseDialog() async {
    setState(() => _dialogOpen = true);
    final phase = state.phase;
    final resume = controller.resumePrivacyRequired || _resumeCurtain;
    final gameOver = phase == GamePhase.gameOver;
    final hero = phase == GamePhase.heroPrivacy;
    final opening =
        phase == GamePhase.openingPrivacy ||
        phase == GamePhase.chooseAccomplices ||
        phase == GamePhase.chooseInitialInfection;
    final message = hero
        ? _computerMode
              ? '轮到戴夫行动'
              : '轮到戴夫行动'
        : opening
        ? '戴夫请闭眼，不要观看屏幕！贪吃虫正在选择3个寄生作物'
        : '入夜！戴夫请回避视线，贪吃虫选择本轮啃食目标';
    final action = await showDialog<_DialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _nightInterface(
        PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(
              gameOver
                  ? _winnerText
                  : hero
                  ? _computerMode
                        ? '戴夫阶段'
                        : '戴夫阶段'
                  : '隐私提示',
            ),
            // 明确内容宽度，避免结算作物自适应层参与AlertDialog的固有尺寸计算。
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: gameOver
                    ? _resultContent()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(message, style: const TextStyle(fontSize: 21)),
                          if (resume)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text('恢复本局前，请先确认另一位玩家已回避视线。'),
                            ),
                          if (phase == GamePhase.chooseInitialInfection)
                            const Text('贪吃虫已选定，现在选择1名初始被啃食的作物。'),
                        ],
                      ),
              ),
            ),
            actions: [
              if (phase != GamePhase.openingPrivacy)
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, _DialogAction.reset),
                  child: const Text('重置游戏'),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  gameOver ? _DialogAction.close : _DialogAction.continueGame,
                ),
                child: Text(
                  gameOver
                      ? '查看棋盘'
                      : hero
                      ? '开始行动'
                      : '已回避，继续',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == _DialogAction.reset) {
      _resumeCurtain = false;
      controller.reset();
    } else if (gameOver) {
      _resultDismissed = true;
    } else if (resume) {
      _resumeCurtain = false;
      if (controller.resumePrivacyRequired) controller.dismissResumePrivacy();
    } else if (state.phase == phase) {
      controller.acknowledgePrivacy();
    }
    setState(() => _dialogOpen = false);
    setState(() {});
    _scheduleDialog();
  }

  String get _winnerText => _computerMode
      ? state.winner == Winner.hero
            ? '戴夫获胜！'
            : '贪吃虫获胜！'
      : state.winner == Winner.hero
      ? '戴夫获胜！'
      : '贪吃虫获胜！';

  String get _resultReason => switch (state.winReason) {
    WinReason.allAccomplicesMonitored => '3个寄生作物全部被标记。',
    WinReason.noInfectableGirls => '场上已没有未被啃食且可以被啃食的作物。',
    WinReason.noReachableInfectionTargets => '本回合所有可行动的贪吃虫，在行动牌允许的范围内均无可啃食目标。',
    WinReason.survivedSixRounds => '第6回合结束，仍有贪吃虫未被标记。',
    null => '',
  };

  String _unreachableCropSummary() {
    final ids =
        state.accompliceIds
            .where(
              (id) => !state
                  .girl(id)
                  .surveillanceMarks
                  .any((mark) => mark.round == state.round - 1),
            )
            .toList()
          ..sort();
    return ids
        .map((id) {
          final row = (id - 1) ~/ GameConstants.columns + 1;
          final column = (id - 1) % GameConstants.columns + 1;
          return '第$row排第$column个寄生作物范围没有可啃食作物。';
        })
        .join('\n');
  }

  Widget _resultContent() {
    final ids = state.accompliceIds.toList()..sort();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_resultReason),
        if (state.winReason == WinReason.noReachableInfectionTargets) ...[
          const SizedBox(height: 8),
          Text(_unreachableCropSummary()),
        ],
        const SizedBox(height: 16),
        Text(_computerMode ? '寄生作物揭晓' : '寄生作物揭晓'),
        const SizedBox(height: 8),
        Row(
          children: ids
              .map(
                (id) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Column(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: GirlCardView(
                            girl: GameArtwork.cardForDisplay(state.girl(id)),
                            terrain: true,
      cropTouch: _cropTouch,
                            onTap: null,
                            revealedAccomplice: true,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('第${(id - 1) ~/ 5 + 1}行·第${(id - 1) % 5 + 1}列'),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Future<void> _confirmReset() async {
    if (_dialogOpen || _dialogScheduled) return;
    setState(() => _dialogOpen = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _nightInterface(
        AlertDialog(
          title: const Text('重新开始本局？'),
          content: Text(
            _computerMode ? '当前进度将被清空，电脑将重新秘密选择寄生作物。' : '当前进度将被清空，回到开局选人。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('重置'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (confirmed == true) {
      _resumeCurtain = false;
      controller.reset();
    }
    _scheduleDialog();
  }

  Future<void> _confirmReturnToModes() async {
    if (_dialogOpen || _dialogScheduled) return;
    setState(() => _dialogOpen = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _nightInterface(
        AlertDialog(
          title: const Text('返回模式选择？'),
          content: const Text('本局进度会保留，可在对应模式中继续。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    if (confirmed == true) {
      widget.onReturnToModes?.call();
    } else {
      _scheduleDialog();
    }
  }

  void _returnHome() {
    if (_dialogOpen || _dialogScheduled || widget.onReturnToModes == null) {
      return;
    }
    _dismissPreviewImmediately();
    _playParticles.stop();
    _stopHintPulse();
    _music.setSceneActive(false);
    // 宿主沿用原保存队列与电脑任务清理，直接回到模式首页。
    widget.onReturnToModes!();
  }

  Future<void> _openRules() async {
    if (_dialogOpen || _dialogScheduled) return;
    setState(() => _dialogOpen = true);
    await showGameRulesDialog(context, night: _nightScene);
    if (!mounted) return;
    setState(() => _dialogOpen = false);
    // 说明弹窗期间若切到后台，关闭说明后仍按原流程确认秘密阶段隐私。
    _scheduleDialog();
  }

  String get _phaseText => switch (state.phase) {
    GamePhase.openingPrivacy => '开局 · 隐私提示',
    GamePhase.chooseAccomplices => '秘密选择3个寄生作物',
    GamePhase.chooseInitialInfection => '秘密选择1名初始被啃食的作物',
    GamePhase.nightPrivacy => '入夜 · 请戴夫回避视线',
    GamePhase.chooseOmen => '贪吃虫阶段 · 先打出行动牌',
    GamePhase.accompliceTurn => '贪吃虫阶段',
    GamePhase.heroPrivacy => '戴夫准备行动',
    GamePhase.heroTurn => '戴夫阶段',
    GamePhase.gameOver => '本局结束',
  };

  @override
  Widget build(BuildContext context) {
    final curtain =
        _isPrivacy ||
        controller.resumePrivacyRequired ||
        _resumeCurtain ||
        controller.isComputerTurn;
    // 安全区内固定2:1分区；隐私遮挡/阶段控制仍沿用原逻辑。
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _previewOmenId != null && !_previewClosing
              ? _closePreview
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GameSceneBackground(
                night: _nightScene,
                eatenPlotIds: state.girls
                    .where((girl) => girl.isInfected)
                    .map((girl) => girl.id)
                    .toSet(),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox.expand(
                              key: const ValueKey('board-region'),
                              child: controller.isComputerTurn
                                  ? _nightInterface(
                                      Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.smart_toy_outlined,
                                              size: 48,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              controller.computerError == null
                                                  ? '电脑正在秘密行动…'
                                                  : '电脑行动已暂停',
                                              key: const ValueKey(
                                                'computer-curtain',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : curtain
                                  ? _nightInterface(
                                      const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.visibility_off,
                                              size: 48,
                                            ),
                                            SizedBox(height: 12),
                                            Text('请按提示交接设备'),
                                          ],
                                        ),
                                      ),
                                    )
                                  : _board(constraints.biggest),
                            ),
                          ),
                          Expanded(flex: 1, child: _operationPanel()),
                        ],
                      ),
                      if (_nightScene)
                        Positioned.fromRect(
                          rect: FarmSceneGeometry.wormTrackRect(
                            constraints.biggest,
                          ),
                          child: const WormWalkway(
                            key: ValueKey('worm-walkway'),
                          ),
                        ),
                      if (state.phase == GamePhase.heroTurn &&
                          !curtain &&
                          !_dialogOpen)
                        Positioned(
                          top: 12,
                          left: 164,
                          right: 8,
                          height: 44,
                          child: DeductionNoteToolbar(
                            notes: state.deductionNotes,
                          ),
                        ),
                      if (_previewOmenId != null && !curtain && !_backgrounded)
                        Positioned(
                          top: 62,
                          left: 0,
                          right: 0,
                          bottom: constraints.maxHeight / 3 + 4,
                          child: SizedBox.expand(
                            key: _previewAreaKey,
                            child: ActionCardPreview(
                              key: ValueKey('preview-$_previewOmenId'),
                              card: GameConstants.omenById(_previewOmenId!),
                              closing: _previewClosing,
                              night: _nightScene,
                              onDismiss: _closePreview,
                              frameKey: _previewFrameKey,
                            ),
                          ),
                        ),
                      if (_playParticles.isAnimating && !_backgrounded)
                        Positioned(
                          top: 62,
                          left: 0,
                          right: 0,
                          bottom: constraints.maxHeight / 3 + 4,
                          child: CardPlayParticles(
                            animation: _playParticles,
                            cardRect: _playedPreviewRect,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _nightInterface(const GameFeedbackWatermark()),
              _nightInterface(
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton.filledTonal(
                              key: const ValueKey('background-music-button'),
                              tooltip: _music.enabled ? '关闭背景音乐' : '打开背景音乐',
                              onPressed: _music.toggle,
                              icon: Icon(
                                _music.enabled
                                    ? Icons.music_note
                                    : Icons.music_off,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton.filledTonal(
                              key: const ValueKey('settings-button'),
                              tooltip: '设置',
                              onPressed: _dialogOpen ? null : _openSettings,
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton.filledTonal(
                              key: const ValueKey('return-home-button'),
                              tooltip: '返回首页',
                              onPressed:
                                  _dialogOpen || widget.onReturnToModes == null
                                  ? null
                                  : _returnHome,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The lower frame contains card artwork only; text/buttons stay above it.
  Widget _operationPanel() => ClipRRect(
    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
    child: Stack(
      key: const ValueKey('operation-region'),
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GameNightStyle.apply(
            night: _nightScene,
            filter: GameNightStyle.interface,
            key: const ValueKey('operation-night-tint'),
            child: const PaperSurface(child: SizedBox.expand()),
          ),
        ),
        Column(
          children: [
            _nightInterface(
              _playerBar(
                villain:
                    state.phase != GamePhase.heroTurn &&
                    state.phase != GamePhase.heroPrivacy,
              ),
            ),
            Expanded(child: _actionHandPanel()),
          ],
        ),
      ],
    ),
  );

  Widget _actionHandPanel() {
    // The computer's current secret choice is NEVER read into a card widget.
    if (controller.isComputerTurn ||
        _isPrivacy ||
        controller.resumePrivacyRequired ||
        _resumeCurtain ||
        _backgrounded) {
      return const SizedBox.expand(key: ValueKey('action-hand-panel'));
    }
    final choosing =
        !_computerMode &&
        (state.phase == GamePhase.chooseOmen ||
            state.phase == GamePhase.accompliceTurn);
    final completed = state.lastCompletedInfectionRound;
    // Never include the current uncompleted night, including AI pause or a
    // zero-target victory right after playing. This is existing public history.
    final completedCardIds = completed == null
        ? <int>[]
        : state.playedOmenIds.take(completed).toList();
    return SizedBox.expand(
      key: const ValueKey('action-hand-panel'),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: choosing
            ? ActionCardHand(
                key: ValueKey('hand-${state.round}'),
                cards: state.round > GameConstants.omenCards.length
                    ? state.availableOmenCards
                    : GameConstants.omenCards,
                playableIds: state.availableOmenCards
                    .where(
                      (card) =>
                          state.phase == GamePhase.chooseOmen ||
                          card.id != state.playedOmenId,
                    )
                    .map((card) => card.id)
                    .toSet(),
                selectedId: _previewClosing ? null : state.selectedOmenId,
                enabled: _handInteractionEnabled,
                onSelect: _selectPreview,
              )
            : completedCardIds.isEmpty
            ? const SizedBox.expand()
            : PlayedActionHistory(
                key: ValueKey('history-${completedCardIds.length}'),
                playedCardIds: completedCardIds,
                night: _nightScene,
              ),
      ),
    );
  }

  /// 土地本身是格子底框。与场景原图使用同一坐标变换，草地间隙不响应。
  Widget _board(Size sceneSize) {
    final range = _computerMode
        ? <int>{}
        : controller.infectionRangePreviewTargetIds;
    final touchEnabled = !_backgrounded && !_dialogOpen && !controller.resumePrivacyRequired && !_resumeCurtain && !controller.isComputerTurn;
    return Listener(
      onPointerDown: (event) { if (touchEnabled) { _cropTouch.touch(event.pointer, event.localPosition, sceneSize); if (_music.enabled && state.girls.any((girl) => FarmSceneGeometry.plotRect(girl.id, sceneSize).contains(event.localPosition))) _cardSound.pop(); } },
      onPointerMove: (event) { if (touchEnabled) { _cropTouch.touch(event.pointer, event.localPosition, sceneSize); } },
      onPointerUp: (event) => _cropTouch.release(event.pointer, sceneSize),
      onPointerCancel: (event) => _cropTouch.release(event.pointer, sceneSize),
      child: SizedBox.expand(
      key: const ValueKey('board-grid'),
      child: Stack(
        children: [
          for (final girl in state.girls)
            Positioned.fromRect(
              key: ValueKey('farm-plot-${girl.id}'),
              rect: FarmSceneGeometry.plotRect(girl.id, sceneSize),
              child:
                  state.phase == GamePhase.heroTurn ||
                      state.phase == GamePhase.gameOver
                  ? DeductionNotePlot(
                      plotId: girl.id,
                      notes: state.deductionNotes,
                      enabled:
                          state.phase == GamePhase.heroTurn && !_dialogOpen,
                      onPlace: (id, drag) => controller.placeDeductionNote(
                        id,
                        drag.symbol,
                        fromPlotId: drag.fromPlotId,
                      ),
                      onRemove: controller.removeDeductionNote,
                      child: _plot(girl.id, rangeHint: range.contains(girl.id)),
                    )
                  : _plot(girl.id, rangeHint: range.contains(girl.id)),
            ),
        ],
      ),
    ));
  }

  Widget _plot(int id, {bool rangeHint = false}) {
    final girl = state.girl(id);
    final selectingIdentity = state.phase == GamePhase.chooseAccomplices;
    final selected = state.selectedIds.contains(id);
    final active =
        selectingIdentity ||
        state.phase == GamePhase.accompliceTurn ||
        state.phase == GamePhase.heroTurn;
    final planned = state.pendingInfectionSelections.where(
      (action) => action.targetId == id,
    );
    return GirlCardView(
      key: ValueKey(id),
      girl: GameArtwork.cardForDisplay(girl),
      terrain: true,
      night: _nightScene,
      rangeHint: rangeHint,
      hintPulseLit: _hintPulseLit,
      onTap: active ? () => controller.tapCard(id) : null,
      identitySelection: !_computerMode && selectingIdentity && selected,
      temporarySelection:
          !_computerMode && state.phase == GamePhase.accompliceTurn && selected,
      pendingSurveillance: state.phase == GamePhase.heroTurn && selected,
      currentRound: state.round,
      infectionPlanLabel: _computerMode || planned.isEmpty ? null : '目标已选',
      accompliceHighlight:
          !_computerMode &&
          _secretTurn &&
          state.phase != GamePhase.chooseAccomplices &&
          state.accompliceIds.contains(id),
      selectedCenter:
          !_computerMode &&
          state.phase == GamePhase.accompliceTurn &&
          state.selectedCenterId == id,
      revealedAccomplice:
          state.phase == GamePhase.gameOver && state.accompliceIds.contains(id),
    );
  }

  /// 下方固定操作栏；公开阶段立即清除身份蓝光。
  Widget _playerBar({required bool villain}) {
    final blocked =
        controller.resumePrivacyRequired ||
        _resumeCurtain ||
        _backgrounded ||
        _dialogOpen;
    final actions = <Widget>[];
    String hint = _phaseText;
    if (controller.isComputerTurn) {
      hint = controller.computerError == null
          ? '人机模式 · 等待电脑行动完成'
          : '人机模式 · 当前行动无法完成';
      if (controller.computerError != null) {
        actions.add(
          TextButton(
            onPressed: controller.retryComputerTurn,
            child: const Text('重试电脑行动'),
          ),
        );
      }
    } else {
      switch (state.phase) {
        case GamePhase.chooseAccomplices:
          hint =
              '已选择 ${state.selectedIds.length} / ${GameConstants.accompliceCount} 个寄生作物';
          actions.add(
            _hintButton(
              '确认寄生作物',
              controller.canConfirmAccomplices,
              FilledButton(
                onPressed: controller.canConfirmAccomplices
                    ? controller.confirmAccomplices
                    : null,
                child: const Text('确认寄生作物'),
              ),
            ),
          );
        case GamePhase.chooseOmen:
          hint = '选择一张行动牌打出，并啃食行动范围内的作物';
          actions.add(
            _hintButton(
              '打出行动牌',
              controller.canPlayOmen,
              FilledButton(
                onPressed: controller.canPlayOmen ? _playPreviewCard : null,
                child: const Text('打出行动牌'),
              ),
            ),
          );
        case GamePhase.accompliceTurn:
          hint =
              '牌面 ${state.omenInstructionCount} 次，本轮执行 ${state.requiredInfections} 次';
          actions.add(
            _hintButton(
              '提交啃食',
              controller.canSubmitInfection,
              FilledButton(
                onPressed: controller.canSubmitInfection
                    ? controller.submitInfection
                    : null,
                child: const Text('提交啃食'),
              ),
            ),
          );
        case GamePhase.heroTurn:
          hint =
              '待标记 ${state.selectedIds.length} / ${GameConstants.surveillancePerRound}，确认后进入下一阶段';
          actions.add(
            _hintButton(
              '确认标记',
              controller.canSubmitSurveillance,
              FilledButton(
                onPressed: controller.canSubmitSurveillance
                    ? controller.submitSurveillance
                    : null,
                child: const Text('确认标记'),
              ),
            ),
          );
        default:
          break;
      }
    }
    final clue = state.phase == GamePhase.accompliceTurn && !_computerMode
        ? '标记线索：本回合有 ${state.skippedInfectionsDueToSurveillance} 次啃食因标记作废'
        : !controller.isComputerTurn &&
              state.lastCompletedInfectionRound != null
        ? state.lastRoundSkippedInfectionsDueToRange! > 0
              ? '第${state.lastCompletedInfectionRound}回合线索：标记作废 ${state.lastRoundSkippedInfectionsDueToSurveillance} 次，范围无目标作废 ${state.lastRoundSkippedInfectionsDueToRange} 次'
              : '第${state.lastCompletedInfectionRound}回合线索：因标记未执行 ${state.lastRoundSkippedInfectionsDueToSurveillance} 次啃食'
        : null;
    return Container(
      key: const ValueKey('operation-controls'),
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GamePalette.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AbsorbPointer(
                      absorbing: blocked,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final action in actions)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: action,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                key: const ValueKey('round-display-area'),
                width: 70,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '第 ${state.round} / ${GameConstants.maxRounds} 回合',
                    key: const ValueKey('round-display'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            blocked ? '请先确认隐私提示' : hint,
            style: const TextStyle(fontSize: 12, color: GamePalette.muted),
          ),
          if (clue != null)
            Text(
              clue,
              key: ValueKey(
                state.phase == GamePhase.accompliceTurn
                    ? 'current-infection-clue'
                    : 'completed-infection-clue',
              ),
              style: const TextStyle(fontSize: 10, color: GamePalette.ice),
            ),
          if (state.phase == GamePhase.accompliceTurn &&
              !controller.canCompleteInfectionPlan)
            const Text(
              '当前选择无法完成，请重新选择寄生作物与目标',
              style: TextStyle(fontSize: 10, color: GamePalette.warning),
            ),
          if (controller.saveError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.saveError!,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                TextButton(
                  onPressed: controller.retrySave,
                  child: const Text('重试保存'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
