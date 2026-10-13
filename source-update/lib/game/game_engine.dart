import '../game_constants.dart';
import '../models/game_state.dart';
import '../models/infection_action.dart';
import '../models/surveillance_mark.dart';
import '../models/deduction_notes.dart';
import '../models/infection_selection.dart';
import 'infection_route_resolver.dart';

/// 所有阶段、范围、类型配额、确认和胜负判定均在这里执行。
class GameEngine {
  GameEngine([GameState? state]) : _state = state ?? GameState.initial() {
    // 旧版本在确认齐三枚监视后尚未结算的存档，也按新时机立即判胜。
    if (_state.phase != GamePhase.gameOver && _state.allAccomplicesMonitored) {
      _finish(Winner.hero, WinReason.allAccomplicesMonitored);
    } else {
      // 旧版暂停在秘密阶段的合法存档，也适用新增的零目标胜利条件。
      _checkAccompliceTurnVictory();
    }
  }
  GameState _state;
  GameState get state => _state;
  void reset() => _state = GameState.initial();

  /// 只保存戴夫的推理笔记，不占正式标记配额，不检查或暴露秘密身份。
  void placeDeductionNote(int id, DeductionSymbol symbol, {int? fromPlotId}) {
    if (_state.phase != GamePhase.heroTurn) return;
    final notes = _state.deductionNotes.place(
      id,
      symbol,
      fromPlotId: fromPlotId,
    );
    if (!identical(notes, _state.deductionNotes)) {
      _state = _state.copyWith(deductionNotes: notes);
    }
  }

  void removeDeductionNote(int id) {
    if (_state.phase != GamePhase.heroTurn) return;
    final notes = _state.deductionNotes.remove(id);
    if (!identical(notes, _state.deductionNotes)) {
      _state = _state.copyWith(deductionNotes: notes);
    }
  }

  void acknowledgePrivacy() {
    switch (_state.phase) {
      case GamePhase.openingPrivacy:
        _state = _state.copyWith(phase: GamePhase.chooseAccomplices);
      case GamePhase.nightPrivacy:
        _beginAccompliceTurn();
      case GamePhase.heroPrivacy:
        _state = _state.copyWith(phase: GamePhase.heroTurn);
      default:
        return;
    }
  }

  void tapCard(int id) {
    if (!_state.girls.any((girl) => girl.id == id)) return;
    final girl = _state.girl(id);
    switch (_state.phase) {
      case GamePhase.chooseAccomplices:
        if (girl.isAlive) _toggleSelection(id, GameConstants.accompliceCount);
      case GamePhase.accompliceTurn:
        if (_state.playedOmenId != _state.omen.id) return;
        if (_state.accompliceIds.contains(id)) {
          selectCenter(id);
        } else {
          _selectInfectionTarget(id);
        }
      case GamePhase.heroTurn:
        if (!girl.isAlive) return;
        if (girl.monitoredInRound(_state.round)) {
          // 戴夫尚未结束行动时，再点可撤销本轮已确认标记并归还配额。
          // 历史标记原样保留；其他阶段和已经结算的游戏不能撤销。
          _state = _state.copyWith(
            girls: _state.girls
                .map(
                  (card) => card.id != id
                      ? card
                      : card.copyWith(
                          surveillanceMarks: card.surveillanceMarks
                              .where(
                                (mark) =>
                                    mark.round != _state.round ||
                                    !mark.isActive,
                              )
                              .toList(),
                        ),
                )
                .toList(),
            monitorsPlacedThisRound: _state.monitorsPlacedThisRound - 1,
          );
        } else {
          _toggleSelection(
            id,
            GameConstants.surveillancePerRound - _state.monitorsPlacedThisRound,
          );
        }
      default:
        return;
    }
  }

  void _toggleSelection(int id, int maximum) {
    final selected = Set<int>.of(_state.selectedIds);
    if (!selected.remove(id)) {
      if (selected.length >= maximum) return;
      selected.add(id);
    }
    _state = _state.copyWith(selectedIds: selected);
  }

  bool get canConfirmAccomplices =>
      _state.phase == GamePhase.chooseAccomplices &&
      _state.selectedIds.length == GameConstants.accompliceCount &&
      _state.selectedIds.every((id) => _state.girl(id).isAlive);
  // 旧接口保留为不可用；新版固定中心格初始幸福，不再手动选初始目标。
  bool get canConfirmInitialInfection => false;
  void confirmInitialInfection() {}

  void confirmAccomplices() {
    if (!canConfirmAccomplices) return;
    _state = _state.copyWith(
      accompliceIds: _state.selectedIds,
      selectedIds: {},
      phase: GamePhase.nightPrivacy,
    );
  }

  void _beginAccompliceTurn() {
    _state = _state.copyWith(phase: GamePhase.chooseOmen);
    _checkAccompliceTurnVictory();
  }

  /// 未出牌时检查所有剩余手牌；出牌后严格使用本回合牌面的类型。
  /// 临时选中的中心/目标仍可撤销，不因暂时占用而被排除。
  bool get hasReachableInfectionTarget {
    final cards = _state.playedOmenId == null
        ? _state.availableOmenCards
        : [_state.omen];
    final methods = cards.expand((card) => card.instructions).toSet();
    return _state.actionableAccompliceIds.any(
      (center) => _state.girls.any(
        (girl) =>
            _state.isInfectable(girl) &&
            methods.any(
              (method) => isInfectionInRange(center, girl.id, method),
            ),
      ),
    );
  }

  void _checkAccompliceTurnVictory() {
    if (!{
      GamePhase.nightPrivacy,
      GamePhase.chooseOmen,
      GamePhase.accompliceTurn,
    }.contains(_state.phase)) {
      return;
    }
    // 侦探确认时已经即时判胜；交接入口保留防御性检查。
    if (_state.allAccomplicesMonitored) {
      _finish(Winner.hero, WinReason.allAccomplicesMonitored);
    } else if (_state.infectableCount == 0) {
      _finish(Winner.hero, WinReason.noInfectableGirls);
    } else if (_state.accompliceIds.length == GameConstants.accompliceCount &&
        !hasReachableInfectionTarget) {
      _finish(Winner.hero, WinReason.noReachableInfectionTargets);
    }
  }

  bool get canPlayOmen =>
      _state.phase == GamePhase.chooseOmen &&
      _state.playedOmenId == null &&
      _state.selectedOmenId != null &&
      _state.availableOmenCards.any((card) => card.id == _state.selectedOmenId);
  void selectOmen(int id) {
    if (_state.phase != GamePhase.chooseOmen ||
        !_state.availableOmenCards.any((card) => card.id == id)) {
      return;
    }
    _state = _state.copyWith(selectedOmenId: id);
  }

  /// 玩家点击同一张手牌可取消；显式selectOmen接口保留给电脑规划。
  void toggleOmenSelection(int id) {
    if (_state.phase != GamePhase.chooseOmen ||
        !_state.availableOmenCards.any((card) => card.id == id)) {
      return;
    }
    _state = _state.copyWith(
      selectedOmenId: _state.selectedOmenId == id ? null : id,
    );
  }

  void playOmen() {
    if (!canPlayOmen) return;
    _state = _state.copyWith(
      phase: GamePhase.accompliceTurn,
      playedOmenId: _state.selectedOmenId,
      playedOmenIds: [..._state.playedOmenIds, _state.selectedOmenId!],
      selectedOmenId: null,
      activeInstructionIndex: 0,
      selectedCenterId: null,
      infectionActions: [],
      infectionSelections: [],
      inferInfectionRoutes: false,
      selectedIds: {},
    );
    _checkAccompliceTurnVictory();
  }

  void selectInstruction(int index) {
    if (_state.phase != GamePhase.accompliceTurn ||
        _state.playedOmenId == null ||
        index < 0 ||
        index >= _state.omenInstructionCount) {
      return;
    }
    // 旧公开接口仍可供电脑/兼容调用使用；实际双人界面不提前指定路线。
    if (_state.inferInfectionRoutes) {
      final actions = InfectionRouteResolver.resolve(
        _state.omen,
        _state.infectionSelections,
      );
      if (actions == null) return;
      _state = _state.copyWith(
        inferInfectionRoutes: false,
        infectionSelections: [],
        infectionActions: actions,
        activeInstructionIndex: 0,
        selectedCenterId: null,
      );
    }
    if (_state.infectionActions.length >= _state.requiredInfections &&
        !_state.infectionActions.any(
          (action) => action.instructionIndex == index,
        )) {
      return;
    }
    InfectionAction? existing;
    for (final action in _state.infectionActions) {
      if (action.instructionIndex == index) existing = action;
    }
    _state = _state.copyWith(
      activeInstructionIndex: index,
      selectedCenterId: existing?.centerId,
    );
  }

  void selectCenter(int id) {
    if (_state.phase == GamePhase.accompliceTurn &&
        _state.inferInfectionRoutes) {
      if (!_state.actionableAccompliceIds.contains(id)) return;
      final editing = _state.infectionSelections.any((s) => s.centerId == id);
      if (!editing &&
          _state.pendingInfectionCount >= _state.requiredInfections) {
        return;
      }
      _state = _state.copyWith(selectedCenterId: id);
      return;
    }
    if (_state.phase != GamePhase.accompliceTurn ||
        _state.playedOmenId == null ||
        !_state.canUseCenter(
          id,
          instructionIndex: _state.activeInstructionIndex,
        ) ||
        _state.activeInstructionIndex == null) {
      return;
    }
    _state = _state.copyWith(selectedCenterId: id);
  }

  bool isLegalAction(InfectionAction action) =>
      action.instructionIndex >= 0 &&
      action.instructionIndex < _state.omenInstructionCount &&
      action.method == _state.omen.instructions[action.instructionIndex] &&
      _state.canUseCenter(
        action.centerId,
        instructionIndex: action.instructionIndex,
      ) &&
      _state.girls.any(
        (girl) => girl.id == action.targetId && _state.isInfectable(girl),
      ) &&
      isInfectionInRange(action.centerId, action.targetId, action.method);

  Set<int> get legalTargetIds {
    if (_state.inferInfectionRoutes) {
      return _automaticTargetIds(onlyAssignable: true);
    }
    final index = _state.activeInstructionIndex;
    final center = _state.selectedCenterId;
    if (_state.phase != GamePhase.accompliceTurn ||
        index == null ||
        center == null ||
        !_state.canUseCenter(center, instructionIndex: index)) {
      return {};
    }
    final taken = _state.infectionActions
        .where((action) => action.instructionIndex != index)
        .map((action) => action.targetId)
        .toSet();
    return _state.girls
        .where(
          (girl) =>
              !taken.contains(girl.id) &&
              _state.isInfectable(girl) &&
              isInfectionInRange(
                center,
                girl.id,
                _state.omen.instructions[index],
              ),
        )
        .map((girl) => girl.id)
        .toSet();
  }

  /// 自动判断模式只提示当前可合法分配的目标；确定的旧选择消耗相应指示。
  /// 重叠选择继续尝试所有合法分配，不提前锁定类型；查询不改变状态。
  Set<int> get infectionRangePreviewTargetIds {
    if (_state.inferInfectionRoutes) {
      return legalTargetIds;
    }
    final index = _state.activeInstructionIndex;
    final center = _state.selectedCenterId;
    if (_state.phase != GamePhase.accompliceTurn ||
        _state.playedOmenId == null ||
        index == null ||
        center == null ||
        !_state.canUseCenter(center, instructionIndex: index)) {
      return {};
    }
    final taken = _state.infectionActions
        .where((action) => action.instructionIndex != index)
        .map((action) => action.targetId)
        .toSet();
    final methods = _state.omen.instructions.toSet();
    return _state.girls
        .where(
          (girl) =>
              !taken.contains(girl.id) &&
              _state.isInfectable(girl) &&
              methods.any(
                (method) => isInfectionInRange(center, girl.id, method),
              ),
        )
        .map((girl) => girl.id)
        .toSet();
  }

  void _selectInfectionTarget(int id) {
    if (_state.inferInfectionRoutes) {
      _selectAutomaticTarget(id);
      return;
    }
    final index = _state.activeInstructionIndex;
    if (index == null) return;
    final old = _state.infectionActions.where(
      (action) => action.instructionIndex == index,
    );
    // 再点当前指示已有目标即可取消，不必再次选择中心。
    if (old.isNotEmpty && old.first.targetId == id) {
      removeInfection(index);
      return;
    }
    if (old.isEmpty &&
        _state.infectionActions.length >= _state.requiredInfections) {
      return;
    }
    if (!legalTargetIds.contains(id)) return;
    final action = InfectionAction(
      instructionIndex: index,
      centerId: _state.selectedCenterId!,
      targetId: id,
      method: _state.omen.instructions[index],
    );
    final actions =
        _state.infectionActions
            .where((value) => value.instructionIndex != index)
            .toList()
          ..add(action);
    final occupied = actions.map((value) => value.instructionIndex).toSet();
    final available = List.generate(
      _state.omenInstructionCount,
      (i) => i,
    ).where((i) => !occupied.contains(i));
    _state = _state.copyWith(
      infectionActions: actions,
      selectedIds: actions.map((value) => value.targetId).toSet(),
      activeInstructionIndex:
          actions.length >= _state.requiredInfections || available.isEmpty
          ? index
          : available.first,
      selectedCenterId:
          actions.length >= _state.requiredInfections || available.isEmpty
          ? _state.selectedCenterId
          : null,
    );
  }

  void removeInfection(int index) {
    if (_state.phase != GamePhase.accompliceTurn) return;
    final actions = _state.infectionActions
        .where((action) => action.instructionIndex != index)
        .toList();
    if (actions.length == _state.infectionActions.length) return;
    _state = _state.copyWith(
      infectionActions: actions,
      selectedIds: actions.map((action) => action.targetId).toSet(),
      activeInstructionIndex: index,
      selectedCenterId: null,
    );
  }

  /// 升级旧双人秘密存档时，保留中心/目标及选择顺序，移除提前决定的路线。
  void enableAutomaticInfectionRoutes() {
    if (_state.phase != GamePhase.accompliceTurn ||
        _state.inferInfectionRoutes) {
      return;
    }
    _state = _state.copyWith(
      inferInfectionRoutes: true,
      infectionSelections: _state.pendingInfectionSelections,
      infectionActions: [],
      activeInstructionIndex: null,
    );
  }

  Set<int> _automaticTargetIds({required bool onlyAssignable}) {
    final center = _state.selectedCenterId;
    if (_state.phase != GamePhase.accompliceTurn ||
        _state.playedOmenId == null ||
        center == null ||
        !_state.actionableAccompliceIds.contains(center)) {
      return {};
    }
    final others = _state.infectionSelections
        .where((s) => s.centerId != center)
        .toList();
    if (others.length >= _state.requiredInfections) return {};
    final taken = others.map((s) => s.targetId).toSet();
    final methods = _state.omen.instructions.toSet();
    return _state.girls
        .where(
          (girl) =>
              _state.isInfectable(girl) &&
              !taken.contains(girl.id) &&
              methods.any(
                (method) => isInfectionInRange(center, girl.id, method),
              ) &&
              (!onlyAssignable ||
                  InfectionRouteResolver.resolve(
                        _state.omen,
                        _replaceSelection(
                          InfectionSelection(
                            centerId: center,
                            targetId: girl.id,
                          ),
                        ),
                      ) !=
                      null),
        )
        .map((girl) => girl.id)
        .toSet();
  }

  List<InfectionSelection> _replaceSelection(InfectionSelection selection) {
    final picks = List<InfectionSelection>.of(_state.infectionSelections);
    final position = picks.indexWhere((s) => s.centerId == selection.centerId);
    if (position < 0) {
      picks.add(selection);
    } else {
      picks[position] = selection;
    }
    return picks;
  }

  void _selectAutomaticTarget(int id) {
    final center = _state.selectedCenterId;
    if (center == null) return;
    if (_state.infectionSelections.any(
      (s) => s.centerId == center && s.targetId == id,
    )) {
      removeInfectionSelection(center);
      return;
    }
    if (!legalTargetIds.contains(id)) return;
    final picks = _replaceSelection(
      InfectionSelection(centerId: center, targetId: id),
    );
    _state = _state.copyWith(
      infectionSelections: picks,
      selectedIds: picks.map((s) => s.targetId).toSet(),
      selectedCenterId: null,
    );
  }

  void removeInfectionSelection(int centerId) {
    if (_state.phase != GamePhase.accompliceTurn ||
        !_state.inferInfectionRoutes) {
      return;
    }
    final picks = _state.infectionSelections
        .where((s) => s.centerId != centerId)
        .toList();
    if (picks.length == _state.infectionSelections.length) return;
    _state = _state.copyWith(
      infectionSelections: picks,
      selectedIds: picks.map((s) => s.targetId).toSet(),
      selectedCenterId: null,
    );
  }

  /// 匹配本轮最大合法配额：标记/无目标造成的多余指示不阻塞提交。
  bool get canCompleteInfectionPlan {
    if (_state.phase != GamePhase.accompliceTurn ||
        _state.playedOmenId == null) {
      return false;
    }
    if (_state.inferInfectionRoutes) {
      return InfectionRouteResolver.canComplete(
        card: _state.omen,
        selections: _state.infectionSelections,
        requiredCount: _state.requiredInfections,
        centers: _state.actionableAccompliceIds,
        targets: _state.girls
            .where(_state.isInfectable)
            .map((g) => g.id)
            .toSet(),
      );
    }
    final remaining = List.generate(_state.omenInstructionCount, (i) => i)
        .where(
          (i) => !_state.infectionActions.any(
            (action) => action.instructionIndex == i,
          ),
        )
        .toList();
    final used = _state.infectionActions
        .map((action) => action.targetId)
        .toSet();
    final usedCenters = _state.infectionActions
        .map((action) => action.centerId)
        .toSet();
    final needed = _state.requiredInfections - _state.infectionActions.length;
    if (needed < 0 ||
        used.length != _state.infectionActions.length ||
        _state.infectionActions
                .map((action) => action.instructionIndex)
                .toSet()
                .length !=
            _state.infectionActions.length ||
        !_state.infectionActions.every(isLegalAction)) {
      return false;
    }
    bool match(int at, int stillNeeded) {
      if (stillNeeded == 0) return true;
      if (remaining.length - at < stillNeeded) return false;
      final method = _state.omen.instructions[remaining[at]];
      for (final center in _state.accompliceIds) {
        if (usedCenters.contains(center) ||
            _state
                .girl(center)
                .monitoredInRound(_state.effectiveSurveillanceRound)) {
          continue;
        }
        for (final girl in _state.girls) {
          if (!_state.isInfectable(girl) ||
              used.contains(girl.id) ||
              !isInfectionInRange(center, girl.id, method)) {
            continue;
          }
          used.add(girl.id);
          usedCenters.add(center);
          if (match(at + 1, stillNeeded - 1)) return true;
          used.remove(girl.id);
          usedCenters.remove(center);
        }
      }
      // 原执行顺序自由，减少配额后仍可自由选择保留哪枚环/十指示。
      return match(at + 1, stillNeeded);
    }

    return match(0, needed);
  }

  bool get canSubmitInfection {
    if (_state.inferInfectionRoutes) {
      return _state.phase == GamePhase.accompliceTurn &&
          _state.playedOmenId == _state.omen.id &&
          _state.infectionSelections.length == _state.requiredInfections &&
          _state.infectionSelections.every(
            (s) =>
                _state.actionableAccompliceIds.contains(s.centerId) &&
                _state.girls.any(
                  (g) => g.id == s.targetId && _state.isInfectable(g),
                ),
          ) &&
          InfectionRouteResolver.resolve(
                _state.omen,
                _state.infectionSelections,
              ) !=
              null;
    }
    return _state.phase == GamePhase.accompliceTurn &&
        _state.playedOmenId == _state.omen.id &&
        _state.infectionActions.length == _state.requiredInfections &&
        _state.infectionActions
                .map((action) => action.instructionIndex)
                .toSet()
                .length ==
            _state.requiredInfections &&
        _state.infectionActions
                .map((action) => action.targetId)
                .toSet()
                .length ==
            _state.requiredInfections &&
        _state.infectionActions
                .map((action) => action.centerId)
                .toSet()
                .length ==
            _state.requiredInfections &&
        _state.infectionActions.every(isLegalAction);
  }

  void submitInfection({bool inferRoutes = false}) {
    if (!canSubmitInfection) return;
    final actions = _state.inferInfectionRoutes || inferRoutes
        ? InfectionRouteResolver.resolve(
            _state.omen,
            _state.pendingInfectionSelections,
          )!
        : _state.infectionActions;
    final byTarget = {for (final action in actions) action.targetId: action};
    _state = _state.copyWith(
      girls: _state.girls.map((girl) {
        final action = byTarget[girl.id];
        return action == null
            ? girl
            : girl.copyWith(
                isInfected: true,
                infectionRound: _state.round,
                infectionMethod: action.method,
                infectionCenterId: action.centerId,
              );
      }).toList(),
      selectedIds: {},
      infectionActions: [],
      infectionSelections: [],
      inferInfectionRoutes: false,
      activeInstructionIndex: null,
      selectedCenterId: null,
    );
    if (_state.allAccomplicesMonitored) {
      _finish(Winner.hero, WinReason.allAccomplicesMonitored);
    } else if (_state.infectableCount == 0) {
      _finish(Winner.hero, WinReason.noInfectableGirls);
    } else {
      _endRound(); // 随从提交结束完整回合，统一使当前监视失效。
    }
  }

  bool get canSubmitSurveillance =>
      _state.phase == GamePhase.heroTurn &&
      _state.round != GameConstants.skippedHeroRound &&
      _state.selectedIds.isNotEmpty &&
      _state.selectedIds.length + _state.monitorsPlacedThisRound <=
          GameConstants.surveillancePerRound &&
      _state.selectedIds.every(
        (id) =>
            _state.girl(id).isAlive &&
            !_state.girl(id).monitoredInRound(_state.round),
      );

  void submitSurveillance() {
    if (!canSubmitSurveillance) return;
    final count = _state.selectedIds.length;
    _state = _state.copyWith(
      girls: _state.girls
          .map(
            (girl) => !_state.selectedIds.contains(girl.id)
                ? girl
                : girl.copyWith(
                    surveillanceMarks: [
                      ...girl.surveillanceMarks,
                      SurveillanceMark(round: _state.round),
                    ],
                  ),
          )
          .toList(),
      monitorsPlacedThisRound: _state.monitorsPlacedThisRound + count,
      selectedIds: {},
    );
    // 正面监视确认命中全部潜伏者时立即结算，跳过入夜与传染阶段。
    if (_state.allAccomplicesMonitored) {
      _finish(Winner.hero, WinReason.allAccomplicesMonitored);
    }
  }

  bool get canEndHeroTurn =>
      _state.phase == GamePhase.heroTurn && _state.selectedIds.isEmpty;

  /// 确认所选标记并立即交接；空选择沿用原先跳过标记的合法操作。
  /// UI只通知、保存最终状态；保留旧分批API供旧存档和内部调用兼容。
  bool get canConfirmHeroTurn => canSubmitSurveillance || canEndHeroTurn;
  void confirmHeroTurn() {
    if (!canConfirmHeroTurn) return;
    if (canSubmitSurveillance) submitSurveillance();
    // 全部命中已经立即判胜，endHeroTurn不会覆盖该结果。
    endHeroTurn();
  }

  void endHeroTurn() {
    if (canEndHeroTurn) {
      if (_state.allAccomplicesMonitored) {
        _finish(Winner.hero, WinReason.allAccomplicesMonitored);
        return;
      }
      if (_state.round >= GameConstants.maxRounds) {
        _finish(Winner.accomplices, WinReason.survivedSixRounds);
        return;
      }
      _state = _state.copyWith(
        phase: GamePhase.nightPrivacy,
        round: _state.round + 1,
        monitorsPlacedThisRound: 0,
        playedOmenId: null,
        selectedOmenId: null,
      );
      _checkAccompliceTurnVictory();
    }
  }

  void _endRound() {
    // 第N夜结束后，上一白天的标记失效；仍在第N回合交给戴夫。
    _state = _state.copyWith(
      girls: _state.girls
          .map(
            (girl) => girl.copyWith(
              surveillanceMarks: girl.surveillanceMarks
                  .map((mark) => mark.isActive ? mark.expire() : mark)
                  .toList(),
            ),
          )
          .toList(),
    );
    if (_state.infectableCount == 0) {
      _finish(Winner.hero, WinReason.noInfectableGirls);
    } else {
      _state = _state.copyWith(
        phase: GamePhase.heroPrivacy,
        selectedIds: {},
        monitorsPlacedThisRound: 0,
        selectedOmenId: null,
        activeInstructionIndex: null,
        selectedCenterId: null,
        infectionActions: [],
        infectionSelections: [],
        inferInfectionRoutes: false,
      );
    }
  }

  void _finish(Winner winner, WinReason reason) {
    _state = _state.copyWith(
      girls: _state.girls
          .map(
            (girl) => girl.copyWith(
              surveillanceMarks: girl.surveillanceMarks
                  .map((mark) => mark.isActive ? mark.expire() : mark)
                  .toList(),
            ),
          )
          .toList(),
      phase: GamePhase.gameOver,
      selectedOmenId: null,
      winner: winner,
      winReason: reason,
      selectedIds: {},
      infectionActions: [],
      infectionSelections: [],
      inferInfectionRoutes: false,
      activeInstructionIndex: null,
      selectedCenterId: null,
    );
  }
}
