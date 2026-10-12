0.6.9美术更新以docs/ART_STYLE.md为准：按用户提供的美术风格.zip统一为水粉绘本、米白纸纹和剪贴轮廓。入口背景、标题、25种作物贴纸、农田、土地、三虫及昼夜行动牌使用assets/storybook新素材；旧素材保留原始字节。昼夜必须共用farm_scene.png及相同cover裁切，仅切换RGB光照，夜间叠加只有月亮星星的透明night_sky.png，保证地平线和地形完全重合。牌号、指示和次数为原生文字；四向箭头、八格图示共用手绘笔触，语义及displayInstructions顺序保持。GameArtwork只映射展示副本，旧存档不重写。用户本次明确授权整体美术替换，覆盖下面历史“美术/PNG保持”的展示约束；规则、模型、常量、存储、棋盘几何、贴纸物理、音乐、原生监听、依赖锁、包名和原有交互保持。

0.6.8仅装饰运动与出牌光效增量，以docs/FREE_STICKER_PHYSICS_AND_LIGHT_UPDATE.md为准：模式页贴纸摇动时以惯性在全屏范围飘动，停止摇动后由重力、碰撞和摩擦自然落下堆叠，落稳停止刷新；最大宽高改为最小的3倍，最小同对局作物尺寸。静止/噪声/缓慢倾斜不持续唤醒，后台暂停、恢复重新校准，离页解绑，不用于游戏农场。出牌成功且预览消失后，84个大小不同的白色光点从实际卡框周围向外扩散并在出现后的2秒内连续渐隐至透明，不是2秒等待时间。游戏引擎/模型/常量/存档/布局/PNG/音频/图标/原生监听/依赖锁保持不变，覆盖下方旧24像素偏移、4倍上限及560毫秒光效描述。

0.6.7增量以docs/PARTIAL_ACTIONS_AND_MODE_STICKERS_UPDATE.md为准：requiredInfections改为当前真实棋盘、当前牌面、未标记中心、不同中心/目标/类型槽位所能完成的最大合法次数；范围无目标导致的多余指示作废，完成实际次数可提交，双人自动路线与电脑共用计算。全部可行动范围无目标继续戴夫胜，结算写明对应寄生地块。公开线索区分标记作废和范围作废。存档schema5/字段/键不变，旧临时选择可恢复，不重写历史路线。叉号推理笔记上限19、对勾仍3、正式标记仍3。模式选择页单独使用开始界面背景图.zip原始草地和贴纸.zip中25张原作物贴纸，ModeStickerScene+ModeMotionController+Android加速度计只在模式页监听、有限平滑飘动，大小各异且最小与游戏内相同、最大宽高各4倍；进入对局/后台停止与解绑，游戏棋盘不受传感器影响，无新依赖/权限。旧原图保持。该段覆盖以下旧“仍有目标但次数不足暂停”和“每种笔记最多3”的描述，其余既有玩法与展示保持。

0.6.6展示更新：CropImageView的可选eaten由girl.isInfected驱动，ClipPath透明咬痕、独立EatenCropFace与乘色变暗；GameSceneBackground的eatenPlotIds仅用于土壤显示滤镜。预览实际框GlobalKey用于有限白色周边光点，不存档。GameTitleImage加载新透明标题。PlayedActionHistory从公开已完成牌按倒序展示，最新高度100%、历史78%，按回合标注；不显示未完成夜晚。详见EATEN_TITLE_AND_HISTORY_UPDATE.md，覆盖下面旧“白天仅上一夜”显示说明，业务层不改。

0.6.5最新界面以docs/SETTINGS_AND_CARD_PREVIEW_UPDATE.md为准：设置/音乐左上并列，笔记left=112且小屏等比缩放；下半只放卡牌、回合数在上半按键右侧。夜间直接并列手牌，点牌在场地上层预览（不消费），只按上方“打出行动牌”调用原逻辑；成功后该牌原位渐暗，预览消失后有限光点。整排手牌保留，后续夜晚已消费牌暗色不可点，第6夜⑤原规则复用；白天只公开上一夜卡面。停用拖拽出牌（覆盖0.6.4旧描述）。PNG/音频/图标、几何、引擎/模型/存档/依赖锁与主要玩法保持，隐私/后台关闭预览。

> 0.6.4另接入本地背景音乐，详见docs/BACKGROUND_MUSIC_UPDATE.md：GamePage左上44像素开关，笔记栏left=60，土地/虫坐标不变。BackgroundMusicController偏好独立于存档，Android系统MediaPlayer+MethodChannel循环包内MP3，后台/失焦暂停、离页释放，无新依赖/网络权限。不得把音乐偏好或播放状态混入秘密GameState。

> 0.6.4手牌与图标以docs/ACTION_HAND_AND_ICON_UPDATE.md为准：上传图标原PNG指向Android user_app_icon；5张原图手牌（混合卡面复制一次）在下方可见面板横滑。点击同牌toggle取消，向上拖出到棋盘松手原子选择并打出；操作栏内部松手、横滑、隐私锁、人机阶段不出牌。UI开关不存档。用户确认混合新卡面左十右环：GameConstants.omenDisplayOrder映射[1,0]，resolver只改变搜索优先级；原instructions/slot编号及已完成啃食不改，其他三张默认从左至右。CardImage避开interface反色滤镜，采用crop夜色保持原图比例与alpha。

> 0.6.4范围增量：自动模式infectionRangePreviewTargetIds复用legalTargetIds，已选目标消耗确定类型后仅提示剩余指示合法地块；重叠通过全部整牌匹配保留合法分支。取消/修改后派生结果立即更新，查询不写状态。旧显式API、AI、schema5和其他0.6.3逻辑保持，详见REMAINING_ACTION_RANGE_UPDATE.md。

> 0.6.3：InfectionSelection仅记录中心/目标/点击顺序；InfectionRouteResolver回溯匹配独立整牌槽位，后选约束先选，多个方案取从左至右最早合法分配。双人Controller打牌/恢复后转自动路线模式，旧显式API保留给电脑规划；电脑提交也统一最终方法。schema5兼容2/3/4，原键与已完成方法保持。UI夜间无单次路线结论，戴夫阶段展示；dayScene仅调背景/地块RGB，ActionButtonHint夜间亮光增强，原图/几何/其余玩法不变。详见AUTOMATIC_ROUTES_AND_SCENE_TONE_UPDATE.md。

> 0.6.2推理笔记：新增DeductionNotes与DeductionSymbol，只记录玩家笔记，schema4可选deductionNotes缺失时为空。引擎仅在heroTurn提供place/remove方法，controller复用原串行保存。拖拽载荷仅符号和原地块ID，不访问身份；每种最多3、每格最多1、已啃食格可记笔记。DeductionNoteToolbar与DeductionNotePlot不触发正式标记，夜间隐藏、结算只读，FarmSceneGeometry预留顶部工具栏。

> 0.6.2最新：每回合nightPrivacy→chooseOmen→accompliceTurn→heroPrivacy→heroTurn，夜与白天round相同；夜完成保留playedOmenId为本夜已出牌，白天结束才加轮次并清空当前牌，第6白天结束才虫子胜。effectiveSurveillanceRound在夜N为N-1、白天N为N；标记N在下一夜结束变灰。schema4保留字段和存档键，schema2/3旧顺序校验后迁移白天/标记轮次，已结束结果保留。颜色由infectionRound派生。以下旧schema3/白天先行章节作历史记录，当前以RULES.md和RULES_TEXT_AND_MARK_UNDO_UPDATE.md为准。

> 0.6.2增量：GameRulesDialog共用正文按RULES_INTRODUCTION.md展示；GameEngine.tapCard仅在heroTurn允许点击本轮有效标记的存活作物来撤销，删除对应标记并扣减monitorsPlacedThisRound，保留历史及selectedIds。controller原通知/保存队列直接复用，无新字段/接口/存档版本。结束戴夫行动后与gameOver锁定，原即时全标记胜利保持。详见RULES_TEXT_AND_MARK_UNDO_UPDATE.md。

> 当前0.6.1展示：最新图片.zip草地背景使用BoxFit.cover铺满全屏；独立地块PNG由FarmSceneGeometry在上2/3重复为25块等大正方形，预留48像素虫子轨道并保持至少8像素间隔，点击/作物/标记共享地块坐标。双人开局选择寄生作物也是夜间。整牌路线并集由GameEngine只读infectionRangePreviewTargetIds提供，原legalTargetIds仍严格校验当前环/十；ActionButtonHint仅提示可用按钮。所有原业务操作、AI、常量、model、存档及依赖锁保持。最新以FARM_INTERACTION_UPDATE.md为准；以下旧布局/素材章节保留历史记录。

> 当前展示：捉虫子，已导入农田25块土壤、25种作物（中心梨）及三虫合图原始PNG。GameNightStyle只改变显示RGB，白天/夜间共用原图与坐标；WormWalkway不读取任何游戏身份或目标。CropImageView按透明内容边界等比展示约70%地块，GirlCardView的terrain模式保留上层标记和高亮。旧人物/走廊素材已移除。下面的旧人物/走廊段落是历史记录，当前以FARM_RETHEME_UPDATE.md为准；内部类名、包名、规则和存档保持兼容。

# 项目结构与稳定接口

```text
lib/
  game_constants.dart              GameConstants、OmenCard、InfectionMethod
  main.dart                        竖屏、读取/恢复存档、应用入口
  models/
    game_rules.dart                GameRules 兼容门面，转发统一常量
    girl_card.dart                 GirlCard / InfectionType / 指示物历史
    surveillance_mark.dart         SurveillanceMark：round、isActive
    infection_action.dart          InfectionAction、环/十范围计算
    game_state.dart                不可变 GameState / 阶段 / 胜负 / 存档校验
    game_mode.dart                 双人/人机模式，仅决定操作者和存档键
  game/
    game_engine.dart               纯 Dart 规则、阶段锁、完整预兆方案匹配
    game_controller.dart           UI通知、隐私恢复锁、串行保存队列
    computer_opponent.dart         本地电脑对手，规划并通过原引擎执行秘密阶段
  storage/game_storage.dart        GameStorage / LocalGameStorage
  ui/game_page.dart                棋盘、预兆指示、确认按钮、下方操作区
  ui/game_mode_page.dart           规则说明之后的模式选择
  ui/widgets/girl_card_view.dart   纯色兜底/可选asset图片、蓝光与轮次标记动画
  ui/widgets/omen_instruction_icons.dart  静态八邻格/整行列图标
android/                           竖屏与系统隐私配置
assets/cards/                      人物图片资源目录
scripts/                           可重复云工具链准备与路径激活
test/                              引擎、存储、控制器、手机尺寸及平板交互测试
docs/                              当前规则、修改核对、测试与打包说明
```

## 保留与新增接口

保留公开类名 `GameRules`、`GirlCard`、`GameState`、`GameEngine`、`GameController`、`GameStorage`、`LocalGameStorage`、`HappinessThreadsApp`、`GamePage`、`GirlCardView`，不重命名仍适用字段。旧 `InfectionType` 枚举仍为占位卡面数据；新的 `InfectionMethod` 专门表示预兆指示环/十。

`GirlCard` 保留 `id`、`infectionType`、`isInfected`，`isMonitored` 改为从有效监视历史计算的getter。新增 `infectionRound`、`infectionMethod`、`infectionCenterId`、不可变 `surveillanceMarks`；`isAlive` 仍等于 `!isInfected`。

`GameState` 保留 `girls`、`phase`、`round`、`accompliceIds`、`selectedIds`、`monitorsPlacedThisRound`、`winner`、`winReason`；新增 `playedOmenId`、`activeInstructionIndex`、`selectedCenterId`、`infectionActions`；手牌增量添加 `selectedOmenId`（待打出选择）、`playedOmenIds`（按回合记录实际出牌），`availableOmenCards`根据记录派生剩余手牌。`actionableAccompliceCount`统计本轮未被有效监视者，`omenInstructionCount`保存牌面指示数，`requiredInfections`为两者较小值；槽位编号仍使用整张牌的编号。`selectedIds` 在侦探阶段表示待放置，在随从阶段与操作目标集合一致。Nullable选择字段支持显式清空；所有列表/集合为不可变快照。

`GamePhase.chooseInitialInfection` 与 `confirmInitialInfection` 名称保留兼容识别，但新版不进入该阶段，方法不执行操作，存档拒绝恢复到该阶段。新增 `chooseOmen`，真实流转如下：

- 开局：`openingPrivacy → chooseAccomplices → nightPrivacy → chooseOmen → accompliceTurn`。
- 首轮提交后：增加到第2回合，进入 `heroPrivacy`。
- 第2～6轮：`heroPrivacy → heroTurn → nightPrivacy → chooseOmen → accompliceTurn`；提交后结束本轮并使监视失效；进入下轮侦探阶段或 `gameOver`。
- 主人公确认监视齐3名潜伏者立即进入gameOver，跳过随从；交接处保留防御性检查，无跨轮延迟胜利字段。恢复旧版已经监视齐三名的状态也立即结算并保存。

引擎保留 `acknowledgePrivacy`、`tapCard`、`confirmAccomplices`、`submitInfection`、`endHeroTurn`、`reset`；新增 `selectOmen`、`playOmen`、`selectInstruction`、`selectCenter`、`removeInfection`、`submitSurveillance` 及对应按钮可用条件。控制器转发，UI不自行推进回合或判胜。

每个 `InfectionAction` 保存 `instructionIndex`（牌上独立槽位）、`centerId`、`targetId`、`method`。引擎严格校验槽位类型、中心、范围与重复；中心不能重复、不能是本轮有效监视潜伏者，修改同指示/撤销释放中心。剩余最多3枚指示用回溯同时匹配不同中心、目标和合法指示子集，只需完成本轮有效次数；监视造成的超额指示作废。仍有目标但无法凑齐有效次数时保留阻塞；所有可行动范围均零目标时，0.5.1按用户新要求侦探胜。

## 本地存储与兼容

继续使用键 `happiness_threads.game.v1`，JSON内版本提升为 `schemaVersion: 3`。公开线索从已保存的出牌和感染轮次派生，无新增字段，原schema3卡住的合法待传染状态可以恢复直接提交。

读取时校验中心、身份、轮次、范围、监视配额/状态、阶段、预兆指示和待选目标一致性；异常不静默删除。

schema2的固定轮次可可靠补齐出牌顺序，已提交历史保持不变；如果旧的待传染操作重复中心或使用本轮被监视中心，拒绝非法恢复并保留原文，需明确重开。schema3校验手牌历史长度、前5张独立消费、第6张为编号⑤，以及当前选择与操作一致。

schema1缺少轮次/类型且回合顺序已改变，无法可靠迁移：入口明确提示，重开前不写入。用户选择重开后 `LocalGameStorage.save` 先原样写入 `happiness_threads.game.legacy_v1_backup`，再写新存档；已有备份不覆盖，备份失败时旧存档也不覆盖。损坏JSON经用户确认重开后可替换。

串行异步保存捕获不可变快照；写入失败展示并允许重试。断电/强杀早于队列落盘仍可能丢失最后一次操作，不声称事务保证。数据只保存在应用私有目录，不输出包含秘密ID的日志，不上传。Android禁用自动备份。此前MainActivity设置FLAG_SECURE以防系统截图泄露身份；0.4.1按用户要求移除该限制，继续保留Flutter隐私交接与前后台遮挡。

## 隐私与安卓配置

蓝色随从边缘仅在秘密 `chooseOmen` / `accompliceTurn` 显示；侦探阶段不传入身份，结算才公开揭晓。恢复秘密阶段、返回前台先遮住棋盘再确认隐私，控制器锁住所有状态变更；下方操作区在遮挡时禁用操作。

Android `portrait` 与 Flutter `portraitUp`同时配置，targetSDK35避免Android16对target36+大屏默认忽略方向锁。容器实际响应需实机验收。release无INTERNET权限，debug/profile为Flutter调试保留该权限。

## 当前页面布局（2026-10-09）

安全区内Column使用Expanded的flex2和flex1固定上下分区；上方网格依据宽、高同时约束最大单元尺寸，childAspectRatio为3/4，4逻辑像素间距、10像素外边距。每格预留原1.08倍选择动画空间，实际卡片同样为3:4。棋盘不滚动、始终完整显示25张卡。下方固定当前阵营操作栏，其余预兆/线索/取消/重置放入面板内部滚动区域。

GirlCardView默认渲染底色、边框和原指示物；可选cardImagePath配置后在中间加入Image.asset，BoxFit.contain、3像素内边距、errorBuilder透明回退到底色。边框使用foregroundDecoration最后绘制，并保留原占用空间、颜色、粗细和动画。所有指示物位于卡片内相对定位的FittedBox，随尺寸收缩而不丢历史；蓝光沿卡片容器对齐。结果弹窗揭晓卡片同样使用3:4。布局与规则保持；图片功能仅扩展GirlCard非业务字段cardImagePath和卡片图片层。没有修改GameEngine、GameController、GameState、常量、存储实现或schema版本。

## 人物卡面字段（2026-10-09）

GirlCard增加String? cardImagePath，构造默认null。copyWith默认保留，显式null可关闭；toJson仅在非null时写入，fromJson缺字段为null，使旧纯色存档原样往返，保持schema3。UI先画底色，再画人物图，再画原覆盖色和全部标记，前景边框在最后绘制。未配置/空白路径不调用加载，错误路径/缺失/坏图由errorBuilder回退，组件首次实现时没有背景图；0.4.0另在场景层接入背景，见下文。

## 背景与主题增量（0.4.0+6）

GameArtwork仅配置素材：棋盘和结算使用cardForDisplay为null图片字段提供25张原图默认路径，返回展示副本，不写回GameState。自定义路径优先，显式空字符串关闭默认映射；GirlCardView组件自身的null/空/错误兜底不变。GameSceneBackground独立绘制cover走廊图和alpha153/255黑色蒙版，忽略触摸；背景错误有底色兜底。game_theme.dart集中视觉颜色和Material主题。

安全区2:1、3:4网格、全部阶段回调与隐私遮挡保持。GameEngine、GameController、GameState、GirlCard、GameConstants、存储及Android配置均与本次更新前逐文件SHA-256一致。新增背景和展示映射/主题不参与胜负、监视或传染。改动与81项测试见ART_UI_UPDATE.md。

## 说明、反馈和截图增量（0.4.1+7）

_GameHost在内存中记录rulesAcknowledged，每次进入应用先挂载GameIntroduction展示GameRulesDialog，确认后才挂载GamePage，避免同时弹出规则与隐私提示。该确认不写入存档，也不会自动确认隐私、重置或推进游戏。重新查看通过GamePage._openRules复用原弹窗锁，说明期间切后台会先遮住秘密棋盘，关闭说明后继续隐私确认。

GameFeedbackWatermark独立覆盖安全区上边框，固定小号文字且忽略触摸；不改变flex2:1或网格可用尺寸。GirlCardView只修改显示与语义的“传染”前缀，存档字段和规则术语内部不改。MainActivity取消自定义onCreate和FLAG_SECURE设置，不再由应用禁用截图。具体改动与验证见RULES_FEEDBACK_UPDATE.md。

## 本地人机模式增量（0.5.0+8）

入口现在为GameIntroduction→GameModePage→GamePage。首次打开必须确认规则，选择模式后才创建对应GameController；选择之前不会自动选身份、推进回合或写入新局。返回选择页取消原控制器的Timer并等待保存队列；再次选择恢复对应进度。两种模式分别存档，GameMode不增加GameState字段、不提高schemaVersion；双人键与旧版备份键不变，人机键为happiness_threads.game.computer.v1。读取失败不创建自动行动控制器，明确重开之前不写入原存档。

GameController默认仍为双人；mode=computer时锁住所有玩家对秘密阶段的操作，350ms延迟后在隔离GameEngine上执行整段ComputerOpponent.playSecretTurn。只有完成传染并交回侦探或发生原胜负判定后才通知公开UI；失败显示通用暂停提示，秘密状态仍遮挡。重置和dispose取消Timer；保存继续捕获不可变快照、串行写入。恢复电脑阶段不请求玩家查看或确认反派隐私；恢复侦探阶段不重新选择来源。

ComputerOpponent随机选3名合法来源并保留足够传播空间，选择未使用预兆，回溯匹配独立类型槽位、不同中心/目标、本轮监视和严格环/十范围。只执行原min配额，实际选人、打牌、指示/中心/目标、提交全部使用原GameEngine公开操作。未来空间规划使用临时匹配数据，假定未来无人监视，不预测侦探选择、不写回棋盘。几何阻塞仍暂停，不能伪造跳过/胜利或更换既定身份。GameEngine与GameState/所有既有模型逐文件SHA-256保持不变。

人机电脑阶段上2/3棋盘改为通用遮挡；不构建25张角色卡或反派手牌、中心、临时目标控件。侦探阶段显式关闭身份选中、蓝光、选中中心和待传染标志；仅展示完成回合的牌、感染轮次/方式、监视线索。结算弹窗和结束棋盘才使用原揭晓标志。2:1分区、3:4卡片、25张原图、背景蒙版、水印与可截图配置不变。测试及修改清单见COMPUTER_MODE_UPDATE.md。

## 所有可行动范围零目标判胜（0.5.1+9）

用户新增此胜利条件，因此本次允许增量修改GameEngine、GameState。hasReachableInfectionTarget复用isInfectionInRange和isInfectable，按当前监视筛选actionableAccompliceIds；出牌前检查全部可用牌方法集合，实际打出后只使用当前牌。该查询不采用canUseCenter/已占用目标，因为临时分配可撤销，不能造成假零目标。

统一_checkAccompliceTurnVictory仅在nightPrivacy/chooseOmen/accompliceTurn生效，优先沿用全部监视和全场无目标理由，再判断零范围目标。恢复旧暂停状态时构造器归一化为gameOver，控制器已有保存队列自动保存新结算，不启动电脑Timer；结束侦探、开始随从和打牌后也检查。成功提交传染后的原回合收尾不增加本条件，避免改变正常第6轮反派胜利。

WinReason末尾追加noReachableInfectionTargets，已有枚举名、字段、schema3和两种存档键不改。lastCompletedInfectionRound针对这个理由排除尚未执行的当前出牌，继续从真正完成的历史回合派生监视线索。结果文案和规则说明补入新条件；其余UI/电脑/控制器/存储/资源保持。当前改动及测试见NO_TARGET_VICTORY_UPDATE.md。
