import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/game_mode.dart';
import '../models/deduction_notes.dart';
import '../game_constants.dart';
import '../storage/game_storage.dart';
import 'game_engine.dart';
import 'computer_opponent.dart';

/// UI 状态通知和串行存档层；游戏规则留在 GameEngine 中。
class GameController extends ChangeNotifier {
  GameController({
    required GameStorage storage,
    GameState? restoredState,
    this.mode = GameMode.twoPlayer,
    this.computerDelay = GameConstants.computerTurnDelay,
    ComputerOpponent? computerOpponent,
  }) : _storage = storage,
       _computerOpponent = computerOpponent ?? ComputerOpponent(),
       _engine = GameEngine(restoredState) {
    _resumePrivacyRequired =
        !isComputerMode &&
        restoredState != null &&
        {
          GamePhase.chooseAccomplices,
          GamePhase.chooseInitialInfection,
          GamePhase.chooseOmen,
          GamePhase.accompliceTurn,
        }.contains(_engine.state.phase);
    if (!isComputerMode) _engine.enableAutomaticInfectionRoutes();
    if (restoredState != null && !identical(state, restoredState)) {
      _enqueueSave(state);
    }
    _scheduleComputerTurn();
  }

  final GameStorage _storage;
  GameEngine _engine;
  final GameMode mode;
  final Duration computerDelay;
  final ComputerOpponent _computerOpponent;
  Timer? _computerTimer;
  String? _computerError;
  Future<void> _saveQueue = Future<void>.value();
  bool _disposed = false;
  bool _resumePrivacyRequired = false;
  String? _saveError;

  GameState get state => _engine.state;
  bool get isComputerMode => mode == GameMode.computer;
  bool get isComputerTurn =>
      isComputerMode && ComputerOpponent.controlsPhase(state.phase);
  String? get computerError => _computerError;
  bool get resumePrivacyRequired => _resumePrivacyRequired;
  String? get saveError => _saveError;
  bool get canConfirmAccomplices => _engine.canConfirmAccomplices;
  bool get canConfirmInitialInfection => _engine.canConfirmInitialInfection;
  bool get canSubmitInfection => _engine.canSubmitInfection;
  bool get canPlayOmen => _engine.canPlayOmen;
  bool get canSubmitSurveillance => _engine.canConfirmHeroTurn;
  bool get canEndHeroTurn => _engine.canEndHeroTurn;
  bool get canCompleteInfectionPlan => _engine.canCompleteInfectionPlan;
  Set<int> get legalTargetIds => _engine.legalTargetIds;
  Set<int> get infectionRangePreviewTargetIds =>
      _engine.infectionRangePreviewTargetIds;

  void dismissResumePrivacy() {
    _resumePrivacyRequired = false;
    notifyListeners();
  }

  void acknowledgePrivacy() => _change(_engine.acknowledgePrivacy);
  void tapCard(int id) {
    if (_resumePrivacyRequired) return;
    _change(() => _engine.tapCard(id));
  }

  void confirmAccomplices() => _change(_engine.confirmAccomplices);
  void confirmInitialInfection() => _change(_engine.confirmInitialInfection);
  void submitInfection() => _change(_engine.submitInfection);
  void playOmen() => _change(() {
    _engine.playOmen();
    if (!isComputerMode) _engine.enableAutomaticInfectionRoutes();
  });
  void selectOmen(int id) => _change(() => _engine.selectOmen(id));
  void toggleOmenSelection(int id) =>
      _change(() => _engine.toggleOmenSelection(id));

  /// 拖放是一笔操作：校验现有手牌后，沿用选择、出牌及自动路线流程。
  /// 不公开“先选中再打出”的中间状态，过期/重复拖放不会打出其他牌。
  void playOmenCard(int id) => _change(() {
    if (state.phase != GamePhase.chooseOmen ||
        !state.availableOmenCards.any((card) => card.id == id)) {
      return;
    }
    _engine.selectOmen(id);
    _engine.playOmen();
    if (!isComputerMode) _engine.enableAutomaticInfectionRoutes();
  });
  void selectInstruction(int index) =>
      _change(() => _engine.selectInstruction(index));
  void selectCenter(int id) => _change(() => _engine.selectCenter(id));
  void removeInfection(int index) =>
      _change(() => _engine.removeInfection(index));
  void removeInfectionSelection(int centerId) =>
      _change(() => _engine.removeInfectionSelection(centerId));
  void submitSurveillance() => _change(_engine.confirmHeroTurn);
  void endHeroTurn() => _change(_engine.endHeroTurn);
  void placeDeductionNote(int id, DeductionSymbol symbol, {int? fromPlotId}) =>
      _change(
        () => _engine.placeDeductionNote(id, symbol, fromPlotId: fromPlotId),
      );
  void removeDeductionNote(int id) =>
      _change(() => _engine.removeDeductionNote(id));
  void reset() {
    _computerTimer?.cancel();
    _computerTimer = null;
    _computerError = null;
    _resumePrivacyRequired = false;
    _change(_engine.reset, allowComputerPhase: true);
  }

  void _change(VoidCallback action, {bool allowComputerPhase = false}) {
    if (_disposed ||
        _resumePrivacyRequired ||
        (isComputerTurn && !allowComputerPhase)) {
      return;
    }
    final previous = state;
    action();
    if (identical(previous, state)) return;
    notifyListeners();
    _enqueueSave(state);
    _scheduleComputerTurn();
  }

  void retryComputerTurn() {
    if (!isComputerTurn || _disposed) return;
    _computerError = null;
    notifyListeners();
    _scheduleComputerTurn();
  }

  void _scheduleComputerTurn() {
    if (_disposed ||
        !isComputerTurn ||
        _computerError != null ||
        _computerTimer != null) {
      return;
    }
    _computerTimer = Timer(computerDelay, () {
      _computerTimer = null;
      if (_disposed || !isComputerTurn) return;
      // 整个电脑行动使用隔离引擎，中间身份/中心/目标不会通知UI或落入日志。
      final next = GameEngine(state);
      try {
        final complete = _computerOpponent.playSecretTurn(next);
        _engine = next;
        if (!complete) {
          _computerError = '当前行动牌没有完整合法的啃食方案，已暂停。可重试电脑行动或重置游戏。';
        }
      } catch (_) {
        // 不公开异常细节，避免携带中心点或秘密身份。
        _computerError = '电脑行动未完成，请重试或重置游戏。';
      }
      _enqueueSave(state);
      notifyListeners();
    });
  }

  void _enqueueSave(GameState snapshot) {
    // 每次保存捕获不可变快照，严格按触屏顺序写入。
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _storage.save(snapshot);
        _saveError = null;
      } catch (_) {
        _saveError = '保存失败，本局仍可继续。请重试保存后再关闭应用。';
      }
      if (!_disposed) notifyListeners();
    });
  }

  void retrySave() => _enqueueSave(state);
  Future<void> flushSave() => _saveQueue;

  @override
  void dispose() {
    _computerTimer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
