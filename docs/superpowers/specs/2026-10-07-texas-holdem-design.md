# 德州扑克玩法设计文档

- 日期:2026-10-07(同日两次修订:按设计审查的 57 条意见与总评审的补充改定规则细节、计时、兼容、清晰度、布局、拆台与迟到者;2026-10-08 合并上游后改定:协议 v5、发布版本 0.7.0、德州越肩机位)
- 进度:见 [2026-10-07-texas-holdem-progress.md](../plans/2026-10-07-texas-holdem-progress.md)
- 状态:已确认(用户确认:德州 2–8 人且牌桌与桌上的牌放大、清晰;房主随时散局;开打后新玩家下一手入座;盲注等细节由本设计决定)
- 依附于:[《骗子酒馆》设计文档](2026-08-14-liars-tavern-design.md)(网络、3D 酒馆、HUD 等沿用其约定)
- 协作:3D 模型重做在 `feature/model-detail` 分支进行(见 §9);本分支的 3D 新内容只放在新文件里

## 1. 概述与范围

新增「玩法」:**开房时**选择 骗子酒馆 / 德州扑克·长牌 / 德州扑克·短牌,开房后不能改(想换玩法就重开房间)。
德州扑克为**无限注现金局**:

- 2–8 人;入座领 2000 筹码;盲注 10/20,固定不升。
- 输光可再领 2000(不限次数)或观战;观战中随时可以领筹码,下一手上桌。
- 房主随时「散局」:打完当前这一手后结算,按「筹码 − 累计领取」排盈亏,然后全员回等待厅。
- 开打后新玩家仍可加入,下一手开始发牌。
- 在同一个 3D 酒馆里打:牌桌放大(半径 0.95 → 1.45 米);所有公共信息(公共牌、摊牌)另有 2D 大图,保证 1280×720 下看得清。

明确不做:AI 补位、前注与升盲、锦标赛、时间银行、预选动作、主动亮牌/埋牌、聊天、断线重连(断线 = 离桌)、自定义买入额、死按钮规则、等待厅里改玩法(想换玩法就重开房间;README 与说明书写明)。

## 2. 规则

### 2.1 牌堆

- 长牌:标准 52 张(2–A × ♠♥♦♣)。短牌:去掉 2–5,共 36 张(6–A)。
- 每手由房主 RNG 用 Fisher-Yates 重新洗牌;不烧牌。

### 2.2 牌型大小

长牌从大到小:同花顺(A 高的叫皇家同花顺)> 四条 > 葫芦 > 同花 > 顺子 > 三条 > 两对 > 一对 > 高牌。

短牌只改一处:**同花 > 葫芦**(36 张牌里同花更难成)。顺子 > 三条与长牌相同:三条与顺子的先后各家曾不一致,本游戏取 Triton 2019 年起与多数平台的现行版本。

- A 可以当最小牌接顺子:长牌 A-2-3-4-5 是最小顺子(按 5 高算);短牌 A-6-7-8-9 是最小顺子(按 9 高算)。同花顺同理。
- 牌型相同按标准踢脚比较;五张完全一样则平分。花色不分大小。
- 7 选 5:2 张手牌 + 5 张公共牌里取最大的 5 张(可以只用公共牌)。

### 2.3 庄家、座位与盲注

- **筹码单位 10**:所有金额(筹码、下注、底池、份额)都是 10 的倍数。所以短码的盲注只有一种情况:大盲只剩 10。
- **上桌者**:发牌时 status 为 `waiting`(见 §4.4)且没离开的玩家。不足 2 人不开新的一手,牌桌等待。
- **座位顺序** = 行动顺序 = 俯视顺时针(与骗子酒馆出牌方向相同)。开局按等待厅顺序;新人排在座位顺序末尾。
- **按钮**:第一手随机。之后在上一手的座位表里,从上一手按钮的位置顺时针往后,找第一位本手上桌的玩家(按钮本人已离开或输光时同样适用)。
- **单挑**(本手只有 2 人上桌):按钮下小盲,另一人下大盲;翻牌前按钮先行动,翻牌后大盲先。
  从 ≥ 3 人变成单挑的那一手:如果上一手的大盲是这两人之一,按钮给他(他下小盲),免得同一个人连下两次大盲(TDA)。
- 小盲 = 按钮之后的下一位上桌者,大盲 = 再下一位。筹码不够就全下。
- 新入座的人不用补盲,也不免盲:第一手可能直接轮到盲注。
- 接受的简化:大盲离开后,下一位直接下小盲(不处理死按钮/死小盲)。

### 2.4 下注(无限注)

- **翻牌前**从大盲之后第一位能行动的人开始;**翻牌后**从按钮之后第一位能行动的人开始。下盲不算行动。
- **有效跟注额**:对仍在本手中(没弃牌)的每个其他人 Q,`reach(Q)` = Q 已全下时为他本轮已下,否则为当前最高下注。
  `to_call(P) = max(0, min(当前最高下注, 所有 Q 的 reach 最大值) − P 本轮已下)`,`call_amount = min(to_call, P 的筹码)`。
  例:单挑,小盲已下 10,大盲全下 10,当前最高 20 → 小盲 to_call = 0,不用再行动,直接发完公共牌。三人时按钮还没行动 → 按钮要跟 20。
- **最小下注/加注**:每条街(含翻牌前)开始时,「最近一次完整增量」= 大盲 20。下注或加注到 X:若 `X − 当前最高下注 ≥ 最近完整增量`,算完整加注,更新增量并重新开放行动;否则算不完整加注(只能是全下)。
  `min_raise_to = 当前最高下注 + 最近完整增量`(当前最高为 0 时就是 20)。例:翻牌后 A 全下 10 → B 最少加注到 30;已过牌的人面对这 10 只能跟注或弃牌。
- **能否加注** `can_raise`:①他本轮还没行动过,或自他上次行动以来累计被加注的量 ≥ 最近完整增量;②他的筹码多于 call_amount;③至少还有一个其他在本手中的人没全下。三条都满足才能加注(TDA)。
- **动作**:
  - 弃牌:轮到自己就可以。
  - 过牌:to_call 为 0 时。
  - 跟注:to_call > 0 时,放入 call_amount(不够就全下跟注)。
  - 下注/加注:统一表达为「加注到 X」(本轮自己的总下注额,10 的倍数),要求 can_raise 且 `min_raise_to ≤ X ≤ 本轮已下 + 筹码`;筹码不够 min_raise_to 时只能全下。
  - 全下:合法条件为 `can_allin = can_raise 或 筹码 ≤ to_call`;后一种情况记为跟注。
- **一轮结束**:所有在本手中且没全下的人都行动过,且 to_call 都为 0。
- **未跟注部分退回**:一轮结束(或只剩一人)时,本轮下注最高者 H 超出其余所有人(含已弃牌、已离开者)中第二高下注的部分退回给 H,即使 H 已弃牌或离开。
  例:X 下注 300、Y 全下跟 100、Z 加注到 900、X 弃牌 → Z 退回 600(不是 800)。
- 只剩 1 人没弃牌:他直接赢下全部底池,不亮牌。
- **发完公共牌**:没弃牌的人 ≥ 2,而其中没全下的 ≤ 1 人且他 to_call 为 0 → 先亮出所有没弃牌者的手牌,再把剩下的公共牌依次发完,然后摊牌。

### 2.5 底池与摊牌

- 边池按各玩家本手累计投入构建(弃牌者与离开者的投入是死钱:留在池里,但他不能赢)。按全下额度分层,每层的有资格者 = 投入 ≥ 该层且没弃牌的玩家;相邻两层有资格者相同就合并;某层没有任何有资格者时,并入下面最近一个有资格的底池。
- 摊牌时所有没弃牌的人自动亮牌(全下时已亮过的不重复)。从最后一个边池到主池依次分配:有资格者中牌最大的赢。平局平分,按 10 为单位分,零头从按钮之后顺时针第一位赢家开始依次多给一个单位。
- 只有一个有资格者的边池(摊牌时)照常分给他,不算「没摊牌就赢」。

### 2.6 输光、再领与观战

- 一手结束时筹码为 0 的人**输光**(status `busted`):他的屏幕底部出现「再领 2000」/「观战」(带倒计时)。不选不会卡住牌局,只是不发牌给他。
- **留出选择时间**:有人输光的那一手之后,下一手最早在演出结束后 `PokerPacing.BUST_DECISION`(6 秒)开始;输光者都做了选择(再领/观战/离开)就恢复为 `HAND_GAP`(1.5 秒)。
- **再领**:status 为 `busted` 或 `spectating` 时可以(注意:手牌中全下的人筹码也是 0,但不能领)。每次 2000,不限次数,累计领取 +1,status 变 `waiting`,下一手发牌。当前没有进行中的手牌且凑够 2 人时自动排期开下一手。
- **观战**:只有 `busted` 可以选。角色留在座位上不发牌;镜头切到俯视观战机位;HUD 常驻「领取 2000 上桌」。
- 其他情况的再领/观战请求回 `cannot_rebuy` / `invalid_action`,不产生事件。

### 2.7 中途加入与离开

- **中途加入**只在德州牌局进行中且没有散局请求时允许(散局中或已结算时拒绝:「牌局正在散局,请稍后再来」)。新玩家领 2000(累计领取 1 次),本手旁观;下一手开始时排进座位(座位顺序末尾),酒客在那时登场,所有人的座位跟着重排。
- **离开**(主动离开或断线):
  - 在本手中且没全下 → 立即弃牌,已下的注留在桌上;
  - 已全下 → 留在本手中照常摊牌,可以赢;
  - 不在本手中 → 牌桌空闲时立即移出,否则这一手结束时移出。
  他的酒客立即离场;座位在下一手开始时重排。他的结算筹码在他离开的那一手结束(退回与分池之后)才定格,结算里标「已离开」。
- 房主离开 = 房间解散(同骗子酒馆)。

### 2.8 回合限时

- 每次行动限时 30 秒,外加演出时间(房主权威计时,同骗子酒馆)。超时:to_call 为 0 就过牌,否则弃牌。
- **挂机离座**:连续 2 次超时的人,从下一手起离座(status `away`):保留筹码,不发牌,按钮与盲注跳过他;他的屏幕底部显示「你已离座 · 回到牌桌」,点了(意图 `sit_in`)回到 `waiting`,下一手发牌。他自己的任何一次行动都会把连续超时清零。

### 2.9 散局与结算

- 房主在牌桌上点「散局」并确认:有进行中的手牌就打完这一手再结算(公共状态 `ending` 为真,HUD 显示「本手结束后散局」);没有就立即结算。
- 结算每位玩家(含已离开的):筹码、累计领取次数、盈亏 = 筹码 − 领取次数 × 2000。按盈亏从高到低排名。所有人盈亏之和恒为 0(筹码守恒)。
- 结算面板:房主「回到等待厅」(全员回等待厅,准备状态重置),其他人「离开房间」。

## 3. 玩法、房间与协议

### 3.1 GameMode(`src/core/game_mode.gd`,纯数据,已实现)

`LIARS` / `HOLDEM` / `SHORT_DECK`、`is_valid`、`is_poker`、`is_short_deck`、`label`、`short_label`、`min_players`(2)、`max_players`(骗子酒馆 4,德州 8)、`allows_late_join`(德州)。
桌子尺寸属于 3D 层:`SeatLayout.table_radius_for(mode)` / `SeatLayout.seat_radius_for(table_radius)`。

### 3.2 开房、等待厅与房间列表

- **主菜单**:玩法三段切换放在「开一桌」小节标题那一行(3 个按钮,15 号字,内边距 4/10),不额外占行;1280×720 下面板不出现滚动条(实测约 717/720)。
  记住上次的选择(`Settings.KEY_LAST_MODE`,读到非法值回退默认)。默认房名:骗子酒馆「X 的酒馆」,德州「X 的牌局」。`Net.host_game(name, room, port, mode)`。
- **等待厅**:标题下一行「德州扑克·短牌 · 2–8 人」。玩家列表放进最多显示 4 行的 ScrollContainer(或每行 ≤ 36 像素),整个面板 ≤ 672 像素高。状态行「x/上限 人」用 `Net.max_players()`。
  德州等待厅进入时就 `app.apply_table_mode(mode)`、按德州桌重排酒客、用德州等待厅机位,并在后台开始生成德州牌面。等待厅铭牌单行(「名字 ✓」)≤ 130×44。
- **房间列表**:房主那一行写成「房主 X · 德州·短牌 · IP」;上限 > 4 时座位用文字「3/8」(或 12 号圆点)。加入按钮:可加入「加入」;德州对局中可加入「入座」;满了「已满」;不能加入的对局「对局中」。

### 3.3 协议、发现与握手

- `Protocol.VERSION = 5`(v4 已被「左轮改 5 膛」占用;v5:玩法选择 + 德州扑克)。`Protocol.MAX_PLAYERS = 8`,改为所有玩法的绝对上限(传输层槽位 `MAX_TRANSPORT_CLIENTS = MAX_PLAYERS + 2`、发现报文校验)。各玩法上限一律用 `GameMode.max_players(mode)`。
- **发现报文兼容旧版本**(已发布的 v3 客户端会丢弃 max > 4 的报文,那样旧玩家就看不到德州房间、也就没法从房主更新):
  - `max = mini(玩法上限, 4)`、`players = mini(实际人数, max)`,保持在旧解析器能接受的范围;
  - 新字段 `cap`(玩法上限 2–8)、`seated`(实际人数 0–cap)、`mode`(String)、`playing`(bool)。
  - 新版解析(v5):有 cap 时以 cap/seated 为准,校验 `MIN_PLAYERS ≤ cap ≤ GameMode.max_players(mode)` 与 `0 ≤ seated ≤ cap`,否则丢包;没有 cap 时用 max/players,校验 `max ≤ GameMode.max_players(mode)`(所以骗子酒馆报 max 5 仍丢弃)。
    mode 缺省按 LIARS;mode 不是 String 丢包;mode 截断到 `RoomList.MAX_TEXT`;未知玩法 compatible 为假。playing 缺省 false,不是 bool 丢包。
  - `open = seated < cap 且 (没开局 或 正在接受中途加入)`;`playing = 已开局`。
- 等待厅 meta 带 `"mode"`;客户端 `_apply_lobby` 校验后写入 `Net.game_mode`。
- **加入校验** `LobbyModel.check_join(version: int, in_game: bool, mode: String, accepting_late: bool) -> String`,判定顺序固定:
  ① 版本不符(必须最先判断,主菜单靠「版本」字样触发从房主更新);② 已开局且 `not accepting_late` → 「游戏已开始,请等这一局结束」(德州散局中或已结算时文案为「牌局正在散局,请稍后再来」);③ `size() >= GameMode.max_players(mode)` → 「房间已满(x/上限)」。
  `accepting_late = GameMode.allows_late_join(mode) and 会话存在 and not 会话.is_over() and not 会话.is_ending()`。容量只按已连接的等待厅成员数计。
- **握手**:`rpc_join_accepted(info: Dictionary)`,`info = {"in_game": bool, "mode": String}`。客户端用 `GameMode.is_valid` 校验 mode 并在发 `joined_lobby` 之前写入 `Net.game_mode`(等待厅一进来就要按玩法摆桌;`rpc_lobby_state` 比它晚到)。
  in_game 为真时客户端保持「加入中」(`_joining` 不清、`_join_timer` 继续),直到 `rpc_game_started` 到达才结束;超时走 `_fail_join("房主没有发来牌局信息")`。等待厅 `_refresh` 发现 `Net.game_mode` 与已摆的桌子不一致时再摆一次(兜底)。
- `rpc_game_started(seats: Array, info: Dictionary)`,`info = {"mode": String, "late": bool}`;seats 是当前桌上有酒客的人 `[{pid, name}]`:开局时等于等待厅顺序;中途加入时 = `_session.seats_with_patrons()` 配上会话里的名字(房主权威、没有演出延迟),不含加入者本人。
- 唯一新增 RPC:`rpc_poker_intent(action, amount)`(客户端 → 房主),**参数不加类型**,在函数体内校验:action 是 String 且在 `PokerRules.BET_ACTIONS + SEAT_ACTIONS` 里,amount 是 int、0 ≤ amount ≤ 1,000,000;发送者是本场成员。不合法回 `rpc_intent_rejected`(invalid_action / invalid_amount / not_seated)。
- **RPC 编号冻结**:Godot 按方法名排序给 RPC 编号。排序后下标 0–7 的方法名(`rpc_game_events, rpc_game_started, rpc_intent_challenge, rpc_intent_play, rpc_intent_rejected, rpc_join_accepted, rpc_join_denied, rpc_join_request`)不得增删改名;`rpc_join_request(pname: String, version: int)` 与 `rpc_join_denied(reason: String)` 的参数与 @rpc 模式冻结;新 RPC 的名字必须排在 `rpc_join_request` 之后。
  测试:`(load("res://src/net/network_manager.gd") as Script).get_rpc_config().keys()` 按字符串排序后前 8 个等于上表;`get_script_method_list()` 里两个握手方法的参数个数与类型不变。跨版本连接时的 checksum 报错属预期,不要去「修」。

## 4. 架构

### 4.1 文件(★ 新增,✎ 修改)

```text
src/core/game_mode.gd ★(已完成)
src/core/poker/poker_card.gd ★(已完成)  poker_rules.gd ★(已完成)
src/core/poker/poker_deck.gd ★  hand_evaluator.gd ★  pot_builder.gd ★  poker_table.gd ★(过长时拆 betting_round.gd)
src/net/poker_pacing.gd ★(已完成)  poker_views.gd ★  liars_session.gd ★  poker_session.gd ★
src/net/network_manager.gd ✎  protocol.gd ✎  lobby_model.gd ✎  room_list.gd ✎
src/world/poker/poker_faces.gd ★  chip_stack_3d.gd ★  poker_chips.gd ★  poker_cards.gd ★  dealer_button_3d.gd ★  poker_layout.gd ★
src/world/table_world.gd ✎  seat_layout.gd ✎  card_table.gd ✎  card_faces.gd ✎  tavern.gd ✎(仅接口桩)
src/ui/poker/poker_screen.gd ★  poker_director.gd ★  poker_hud.gd ★  bet_controls.gd ★  poker_nameplate.gd ★
src/ui/poker/poker_settlement.gd ★  card_strip.gd ★(2D 小牌条:公共牌条、摊牌条、自己的手牌)
src/ui/table/seat_gaze.gd ★(从 table_screen 抽出)  table_screen.gd ✎
src/ui/main.gd ✎  main_menu/main_menu.gd ✎  lobby/lobby.gd ✎  settings.gd ✎  sfx.gd ✎  debug_flags.gd ✎  rulebook/* ✎
tools/shot.gd ✎  tools/poker_showcase.gd ★  tools/poker_smoke.sh ★  README.md ✎
```

### 4.2 房主端会话与 NetworkManager

NetworkManager 只管连接、等待厅、RPC 收发与计时器;玩法逻辑在会话对象(RefCounted)里:

```gdscript
# LiarsSession / PokerSession 共同接口
func start(seat_order: Array, names: Dictionary, rng: RandomNumberGenerator) -> Array   # 开局事件(德州直接开第一手)
func handle_intent(pid: int, intent: Dictionary) -> Dictionary  # {"ok", "error"?, "events"?, "turn_action": bool}
func on_disconnect(pid: int) -> Array          # 不在会话里的 pid 返回 []
func on_turn_timeout() -> Dictionary
func public_view(turn_time_left: float) -> Dictionary
func private_view(pid: int) -> Dictionary
func viewers() -> Array                         # 要收私有视图的 pid(德州:所有没离开的成员,含观战、输光、等待、迟到者)
func is_over() -> bool
func is_ending() -> bool
func has_turn() -> bool                         # 当前有人在计时行动
func estimate(events: Array) -> float
func turn_timer_after(events: Array, pending: float, time_left: float) -> float
func accepts_late_join() -> bool                # 骗子酒馆 false;德州 = 没散局且未结束
func add_player(pid: int, name: String) -> Array
func next_hand_ready() -> bool                  # 骗子酒馆 false
func hand_gap() -> float                        # 德州:有输光者没做选择时 BUST_DECISION,否则 HAND_GAP
func start_next_hand() -> Array
func request_end() -> Array
```

- 意图字典:骗子酒馆 `{"kind": "play", "indices": [...]}` / `{"kind": "challenge"}`;德州 `{"kind": action, "amount": int}`。会话收到不属于本玩法的 kind 一律拒绝(德州 `invalid_action`,骗子酒馆 `invalid_play`)。
  `turn_action` 为真表示这是当前行动者消耗回合的动作(德州 fold/check/call/raise/allin,骗子酒馆 play/challenge)。
- **计时规则**(写死,替换现有 `_after_action` / `_schedule_turn_timer`):

```gdscript
func _after_action(events: Array, turn_action := false) -> void:
	if turn_action:
		_anim_left = 0.0     # 行动者那一端已播完排队演出才能出手;再领/观战/加入/离开/散局都不清零
	_anim_left = maxf(_anim_left, 0.0) + _session.estimate(events)
	if _session.is_over() or not _session.has_turn():
		_turn_timer.stop()
	else:
		_turn_timer.start(_session.turn_timer_after(events, _anim_left, _turn_time_left()))
	_schedule_hand_timer()
	game_events.emit(events)
	_send_to_members("rpc_game_events", [events])
	_sync_all()

func _schedule_hand_timer() -> void:
	# 已排期时只会提前(输光者选完了间隔变短),不会推迟到比原计划更晚
	if _session.is_over() or not _session.next_hand_ready():
		_hand_timer.stop()
		return
	var delay := _anim_left + _session.hand_gap()
	if not _hand_timer.is_stopped():
		delay = minf(delay, _hand_timer.time_left)
	_hand_timer.start(delay)

func _on_hand_timer() -> void:
	if in_game and _session != null and _session.next_hand_ready():
		_after_action(_session.start_next_hand())
```

  开局时先置 `_anim_left = Pacing.INTRO` 再 `_after_action(start 的事件)`。输光者做了选择(再领/观战/离开)后 `hand_gap()` 变短,`_after_action` 会按新的间隔重排 `_hand_timer`(只会提前,不会推迟到比原计划更晚)。`_turn_time_left()` 与 `_on_turn_timeout()` 都以 `_session != null and _session.has_turn()` 为前提;超时代打按 `turn_action = true` 处理。
  `leave()` 与 `request_rematch_lobby()` 都停 `_hand_timer` 并把会话置空;`leave()` 另把 `game_mode` 复位为 `GameMode.DEFAULT`。
- **可离线测试的结构**:`rpc_join_request` 只取发送者再调用 `_handle_join_request(id, pname, version)`;`rpc_poker_intent` 只取发送者再调用 `_handle_poker_rpc(pid, action, amount)`;所有直接的 `rpc_id` 改走 `_send_to(id, method, args)`,内部先判断 `_is_connected(id)`(离线测试里对未知 peer 调 rpc_id 会触发引擎错误,GUT 会判失败)。
- **中途加入的房主处理顺序**:`_lobby.add_member` → `_session.add_player(id, 名字)` → `_send_to(id, "rpc_join_accepted", [{"in_game": true}])` → 只对他发 `rpc_game_started(当前座位, {"mode", "late": true})` → `_after_action(事件)` → `_broadcast_lobby()`。
  会话先于获准收人:名单放行但 `add_player` 返回 `[]`(同一 peer id 本手里刚离开、引擎要等这一手结束才移出他;或桌上没座)时撤掉名单项、发 `rpc_join_denied("牌桌暂时坐不下,请稍后再来")` 并稍后断开,不发获准与牌局信息——否则他会被告知开局却不在会话里。入座后再发的座位表仍不含他(`seats_with_patrons()` 取本手的座位表)。
- **视线**:对局中「本场成员」= 已完成握手的等待厅成员 `_lobby`。`rpc_look` 校验 `in_game and _lobby.has(sender)`;`_relay_gaze` 遍历 `_lobby.seat_order()`(跳过房主、发送者与未连接的人)。客户端只对当前桌上有酒客的 pid 应用视线。
- `Net.seats` 在德州里只由 NetworkManager 写(开局与中途加入的引导);`PokerScreen` 自己保存座位表(演到 `hand_started` 时取它的 seats),对账时 `last_public.seats` 不同就重排。
  例外:同一手里(视图的 hand 与本地相同)座位表只增不减,离场者的座位留到下一手 `hand_started`(§2.7、§5.1:他留在桌上的注、全下后的亮牌与退款还按他的座位摆);迟到者的第一帧整个照视图(§7)。

### 4.3 Net 公开接口

```gdscript
var game_mode := GameMode.DEFAULT     # 房主:开房时选的玩法;客户端:来自等待厅 meta 或开局 info
func host_game(pname: String, room_name: String, preferred_port := 0, mode := GameMode.DEFAULT) -> Error
func max_players() -> int
func submit_poker_action(action: String, amount := 0) -> void   # fold / check / call / raise / allin
func request_rebuy() -> void
func request_spectate() -> void
func end_poker_session() -> void              # 仅房主
```

信号不变。发出 `game_started` 之前 `game_mode` 已设好。(等待厅改玩法已砍掉,没有 `set_game_mode`。)

### 4.4 德州状态机 PokerTable(`src/core/poker`,纯逻辑,只在房主端运行)

```gdscript
class_name PokerTable
enum Phase { IDLE, BETTING, OVER }        # IDLE:两手之间/等人;OVER:已散局
func _init(short_deck: bool, rng: RandomNumberGenerator)
func seat(pid: int) -> void                # 开局入座:筹码 2000,领取 1 次,status waiting
func add_player(pid: int) -> Array         # 中途加入 → [player_joined];OVER 时返回 [];座位上限只数没离开的人
func remove_player(pid: int) -> Array      # 离开/断线;不在座位上返回 []
func can_start_hand() -> bool
func start_hand() -> Array                 # not can_start_hand() 时返回 [] 且不改状态
func act(pid: int, action: String, amount := 0) -> Dictionary
func timeout_action() -> Dictionary
func rebuy(pid: int) -> Dictionary
func spectate(pid: int) -> Dictionary
func request_end() -> Array
func legal_actions(pid: int) -> Dictionary
func results() -> Array                    # [{"pid", "stack", "buyins", "net", "left"}] 按 net 降序
# 只读访问(视图层只用这些):seat_order、player、hole_cards、board、pots、hand_number、street、phase、
# current_pid、current_bet、button、small_blind、big_blind、is_ending、best_hand、seats_with_patrons、
# chips_in_play、total_bought_in、departed_stacks
```

- 错误码:`not_your_turn`、`invalid_action`、`invalid_amount`、`no_hand`、`session_over`、`cannot_rebuy`、`not_seated`。
- `legal_actions(pid)`:不轮到他时 `{}`;否则 `{"to_call", "call_amount", "can_check", "can_raise", "can_allin", "min_raise_to", "max_raise_to"}`(按 §2.4)。
- 玩家状态 `status` 与离开标记 `left` 分开:

| status | 含义 |
|---|---|
| `active` | 本手(或刚结束的一手)中没弃牌、没全下 |
| `allin` | 本手(或刚结束的一手)中已全下 |
| `folded` | 本手(或刚结束的一手)中已弃牌 |
| `waiting` | 已入座或已再领,还没被发过牌(下一手发牌) |
| `busted` | 筹码 0,还没选择 |
| `spectating` | 筹码 0,选择了观战 |
| `away` | 挂机离座(连续 2 次超时):有筹码但不发牌,按钮与盲注跳过他 |

  意图 `sit_in` 只对 `away` 有效(回到 `waiting`);`PokerRules.SEAT_ACTIONS` 包含 `rebuy`、`spectate`、`sit_in`。
  `left`(bool):已离开;全下离开的人 status 仍是 `allin`,照常摊牌。离开的人在下一手开始时移出座位。
- **两手之间**(phase IDLE,上一手结束到下一手 `hand_started`):保留上一手的 board、shown、button/sb/bb 与各人的最终 status;street 为这一手结束时所在的街(摊牌结束为 `showdown`);pots 为 []。
  `start_hand()` 时被发牌的人改为 `active`(盲注全下的为 `allin`)。客户端「等待下一手」的界面只认 `waiting`。
- 测试钩子:`button_pid`(下一手按钮为他之后的下一位上桌者;为 null 时第一手随机)、`rigged`(`{"holes": {pid: [两张]}, "board": [5 张]}`,下一手按它发)。

### 4.5 事件(房主 → 全体,客户端按顺序演出)

| type | 字段 | 说明 |
|---|---|---|
| `hand_started` | hand, button, sb, bb, seats(座位顺序 pid,含不发牌的观战/输光者), dealt(发牌顺序,从小盲起) | 新的一手;客户端按 seats 重排座位 |
| `blind` | pid, kind(`sb`/`bb`), amount, bet, stack, all_in | 下盲 |
| `hole_cards` | hand, pids(发牌顺序) | 每人 2 张;牌面在各自的私有视图里 |
| `turn` | pid | 轮到某人;可选动作看公共视图的 `actions` |
| `action` | pid, action(`fold`/`check`/`call`/`bet`/`raise`), amount(这次放进去的), bet(本轮累计), stack, all_in, timeout | 玩家行动 |
| `bets_collected` | pots([{amount, eligible}]), refund({pid, amount} 或 {}) | 一轮结束:先退未跟注部分,再把下注收进底池 |
| `street` | street(`flop`/`turn`/`river`), cards(新牌), board(全部公共牌) | 发公共牌 |
| `reveal` | hands([{pid, cards}]), reason(`allin`/`showdown`) | 亮牌(只含还没亮过的人) |
| `pot_won` | index, amount, winners, shares({pid: 数额}), hand_name, best({pid: 5 张}), uncontested | 分配一个底池;index 0 是主池,依次是边池,按从最后一个边池到主池的顺序发 |
| `hand_over` | hand, stacks({pid: 筹码}), busted([pid]) | 一手结束 |
| `rebuy` | pid, amount, buyins, stack | 再领筹码 |
| `spectate` | pid | 选择观战 |
| `away` | pid | 连续超时被移出下一手(一手结束时发) |
| `sit_in` | pid | 离座的人回到牌桌 |
| `player_joined` | pid, name | 中途加入(下一手发牌) |
| `player_left` | pid, folded(这次离开是否让他弃了牌) | 离开或断线 |
| `ending` | — | 房主散局:本手结束后结算 |
| `session_over` | results([{pid, name, stack, buyins, net, left}]) | 结算 |

- `uncontested` 为真(没摊牌就赢)时 `hand_name = ""`、`best = {}`;`best` 只能包含本手已经亮过牌的人。
- `player_joined` 与 `session_over` 里的名字由网络会话补(引擎不知道名字)。

### 4.6 视图(PokerViews)

公共视图(所有人一样,永远不含没亮的手牌):

```text
{
  "mode": String, "hand": int, "phase": "idle"|"betting"|"over",
  "street": "preflop"|"flop"|"turn"|"river"|"showdown"|"",
  "board": [牌], "pots": [{"amount", "eligible"}],     # 已收进底池的部分,不含本轮下注
  "button": pid|null, "sb": pid|null, "bb": pid|null,
  "current_pid": pid|null, "current_bet": int,
  "actions": {} 或 {"pid", "to_call", "call_amount", "can_check", "can_raise", "can_allin", "min_raise_to", "max_raise_to"},
  "blinds": [10, 20],
  "seats": [pid],             # 当前桌上有酒客的人:本手 hand_started.seats 去掉已离场的;空闲时为上一手的座位表去掉离场者
  "players": [{"pid", "name", "stack", "bet", "committed", "status", "left", "buyins", "net", "shown": [牌]}],  # 按 seats 顺序,还没登场的新人排在最后
  "turn_time_left": float, "ending": bool,
  "results": [] 或结算行(phase 为 over 时)
}
```

私有视图:`{"hand": int, "hole": [两张] 或 [], "best": {} 或 {"category", "name", "detail", "cards": [5 张]}}`。没被发牌的人 `hole` 为空;公共牌 ≥ 3 张时由房主算好 best。

牌用 int 编码(`PokerCard`,已实现):`card = rank * 4 + suit`,取值 8–59,与骗子酒馆的牌型(-1 牌背、0–3)不重叠。

### 4.7 演出预算(`PokerPacing`,已实现)

HAND_STARTED 1.4、BLIND 0.5、HOLE 0.45 + 0.07/张、ACTION 0.7 / 全下 1.2、BETS_COLLECTED 0.7、STREET 0.5 + 0.4/张、REVEAL 0.4 + 0.5/人、POT_WON 2.0、HAND_OVER 0.6、REBUY 0.6、PLAYER_LEFT 0.8、PLAYER_JOINED 0.2、SESSION_OVER 3.0、HAND_GAP 1.5、BUST_DECISION 6.0(有人输光后的一手间隔);`away` / `sit_in` / `spectate` 不占演出时间;交出回合的事件只有 `turn`。
新入座者(中途加入或离座回来)的镜头从观战机位回到自己座位,这段运镜算在 HAND_STARTED 的 1.4 秒里。
导演每段演出的实际时长加余量(每个 await 一帧,至少 4 帧)必须不超过预算,由测试读取导演与资产类的节奏常量来保证(同骗子酒馆的 `test_pacing.gd`)。

## 5. 3D 表现

### 5.1 牌桌与座位

- `SeatLayout.POKER_TABLE_RADIUS = 1.45`、`SEAT_GAP = 0.30`(已实现)。座位半径 = 桌面半径 + 0.30,酒客到桌沿的距离不变。8 人时椅背在 2.11 米,离吧台、壁炉、窗都有余量。
- `TableWorld.configure_table(radius)`(已实现)+ `main.apply_table_mode(mode)`(已实现):德州时桌子 1.45、隐藏烛台与目标牌立牌、不摆左轮。
- 座位变化时酒客**沿圆弧**移动到新座位(按角度插值,不走弦线,否则会穿过桌沿);筹码堆与庄家按钮跟着同一角度动画。
- `TableWorld.remove_patron(pid)`:让酒客 `vanish` 并移除,座位角度保留到下一次 `arrange`。用于 `player_left`。
- **拆台**:德州的 3D 节点(筹码、下注、底池、公共牌架与牌、亮出的牌、弃牌堆、庄家按钮)都放在 `TableWorld` 下的容器 `poker_root` 里;`TableWorld.clear_poker()` 释放容器内全部节点,并释放所有酒客 Fan 下不属于 `CardTable` 的 Card3D(德州的手牌),幂等。
  `PokerScreen._exit_tree`、`LobbyScreen._ready`、`main._show_menu` 都调用它;`TableScreen._ready` 也调用 `app.apply_table_mode(Net.game_mode)`(从德州房间出来再进骗子酒馆时桌子、烛台、立牌、左轮都要复原)。
- 每个 `hand_started`:所有酒客 `reset_pose()`、`set_active(false)`(清掉上一手的庆祝、表情)。
- 灯光:吊灯聚光在桌面高度只照到半径约 1.5 米,德州桌沿与 8 位酒客在半影外;隐藏烛台还去掉了桌沿补光。处理见 §9 约定(聚光随桌子放大、留一点桌沿暖光),以截图为准。

### 5.2 牌面(`PokerFaces`)

- 自己的缓存、`build()`、`is_built()`、`clear()`、`built` 信号;`CardFaces.texture(kind)` 只在 `PokerCard.is_card(kind)` 时转给它;`CardFaces.is_built()` 的含义不变(只管骗子酒馆的 5 张)。
- 尺寸 256×372(52 张含 mipmap 约 25 MiB)。生成时每帧最多 13 个 SubViewport,分批完成,不卡顿;生成完调用 `Card3D.refresh_materials()`,并让 2D 小牌重新取纹理。
- 触发:进入德州等待厅、迟到者进入牌桌、说明书翻到德州那本,哪个先到就在后台开始;导演在第一次发牌前等它完成。`main._exit_tree` 里与 `CardFaces.clear()` 一起 `PokerFaces.clear()`。
- 牌面:超大角标——点数约占牌高 38%,左上与右下(倒置)各一个,花色在点数下方;中央一个大花色,J/Q/K 加冠饰。纸底与金边沿用 `CardFaces` 风格,牌背沿用现有牌背。
  四色花色在暖光与牌面着色器(会压暗)下要分得清:♠ 墨黑、♥ 红、♦ 亮蓝(约 0.2, 0.45, 0.95)、♣ 亮绿(约 0.15, 0.6, 0.25)。花色用多边形与圆绘制,不依赖字体。

### 5.3 卡牌尺寸与朝向

透视算下来,1280×720 下从自己座位看桌心,平放的牌只有二三十像素宽,光靠放大不够。因此:

- **所有公共信息都有 2D 大图**(§6.1):公共牌条常驻左上;摊牌条从 `reveal` 到 `hand_over` 显示在底部中间。
- 3D 公共牌放大 1.8 倍,立在桌心一道向本机镜头倾斜 35° 的小牌架上(约 41×50 像素)。
- 桌上所有牌(公共牌、亮出的牌)都按**本机视角正立**摆放(牌顶朝 −Z,因为每个客户端都把自己的座位放在 +Z),不按座位径向摆。
- 自己举着的两张手牌总放大倍数 1.4(与骗子酒馆牌扇相同);德州时牌扇抬到座位坐标 HIP + (0.30, 0.74, −0.30),落在公共牌与下注控件之间(由德州牌桌设置 `fan.transform`,不改 `patron_3d.gd`)。
- 2D 小牌纹理一律 `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`(从 256 像素缩小很多倍)。

### 5.4 筹码与庄家按钮

- 面额与颜色:10 象牙白、50 红、100 绿、500 黑、1000 金、5000 紫。金额按面额贪心拆分,每列最多 10 枚,每堆最多显示 40 枚;准确金额由 2D 标签显示。
- 每摞筹码用一个 MultiMeshInstance3D(逐实例颜色),筹码、下注、底池都 `cast_shadow = OFF`(最坏约 900 枚,逐枚建网格且投影会多出上千次绘制)。
- 每个座位有一摞筹码(桌沿内侧偏右手)与本轮下注(更靠桌心);底池在公共牌靠本机一侧(主池与边池并排)。
- 动画:下注从筹码堆滑到下注位;一轮结束收进底池;赢家的底池滑回赢家;再领时一摞新筹码落到座位前。
- 庄家按钮:白色圆片写「D」,一手开始时滑到新按钮座位前。

### 5.5 机位(德州的确切数值;骗子酒馆的数值不变)

- 越肩:`pos = dir·(seat_radius + THIRD_PERSON_BACK − SEAT_RADIUS) + right·THIRD_PERSON_SIDE + (0, THIRD_PERSON_HEIGHT, 0)`,`target = −dir·0.12 + (0, 0.78, 0)`;骗子酒馆用上游拉远后的 BEHIND 1.2 / HEIGHT 2.05 / SIDE 0.6(半径 0.95 时正好是现在的机位);德州桌用 `TableWorld.POKER_THIRD_PERSON`(右移 0.55、高 1.92、座位外 0.85;再远再高 8 个铭牌会重叠,见 test_poker_view_layout),即 (0.55, 1.92, 2.6) → (0, 0.78, −0.12)。
- 观战(德州):(0, 2.00, 2.60) → (0, 0.78, 0.00)。
- 等待厅(德州):(1.65, 2.75, 3.35) → (1.35, 0.75, 0.10)。
- 散局环绕:半径 ≥ 3.0,镜头高约 2.0(现在 2.4 米的环绕会擦过 2.11 米处的椅背)。
- 以上都让最远的头与 1.60 米高的帽子避开吊灯罩(灯摆动 ±3 厘米)。4:3 窗口要额外截图检查。
- **用哪个机位**:自己在当前座位表里且 status 不是 `spectating` → 越肩(输光还没选、刚再领等下一手、离座的人都留在越肩);不在座位表里(迟到者)或在观战 → 观战机位。
- 观战机位从本机座位(角度 0)的后上方看过去,那个位置不能挡镜头:观战者自己的酒客在本机上设为不可见(别人照样看得到;不要用 `arrange` 的 show_self,它会释放并重建酒客、可能换成别的动物);
  迟到者按「座位表 + 自己」排座、show_self 为假,于是本机座位空着,正好是下一手他会被排进的位置(新人排在末尾),入座时桌子不用转。

### 5.6 酒客动作(复用 Patron 现有接口)

- 当前行动者 `set_active`,其他人看向他;下注/跟注/全下 `reach_toward_center`,全下轻微震屏;弃牌把牌推进弃牌堆,`set_expression("worried")`;赢下底池 `celebrate`;输光 `worried`;离开 `TableWorld.remove_patron`。
- 每手开始 `reset_pose()`(见 §5.1)。

## 6. 界面

### 6.1 德州牌桌 HUD(1280×720 的布局预算)

- **左上** ≤ 380×108(底边 ≤ y 128):「德州·长牌 · 盲注 10/20 · 第 N 手」、底池合计与边池摘要一行(「底池 3,240 · 边池 ×2」)、5 张公共牌的 2D 牌条(每张 ≥ 36×50)。
- **右上**:「规则 · F1」;房主另有「散局」(请求后变灰,显示「本手结束后散局」)。离开牌桌用 Esc(确认后离开;房主离开会解散)。
- **底部中间** ≤ 600×170(x 340–940,顶边 ≥ y 528):轮到自己时是下注控件;从 `reveal` 到 `hand_over` 换成摊牌条(每人:名字省略显示、2 张 ≥ 30×42 的小牌、牌型名;最多 2 行 × 4 人,≤ 600×170);
  输光时是「再领 2000 / 观战」;观战时是「领取 2000 上桌」;等待下一手时是「已入座,下一手开始发牌」。
  优先级:输光提示 > 摊牌条 > 观战 / 离座 / 等待下一手的提示 > 下注控件(摊牌是公共信息,观战的人也要看到 2D 大图)。结算面板出现后底部清空。
- **左下** ≤ 300 宽(x 24–324):自己的名字、筹码、盈亏、领取次数;两张手牌的 2D 大图 + 当前最大牌型(`best.detail`)。
- **右下**(x 956–1256):事件日志。画面中部是大字宣告(「翻牌」「全下!」「X 赢得 1,240 · 葫芦」)。
- 界面文字里**不出现花色符号**(界面字体里没有 ♠♥♦♣ 字形,系统回退可能变成彩色 emoji):要展示具体的牌一律用 2D 小牌;日志与宣告只写牌型名与点数(如「葫芦 · Q 带 7」)。

### 6.2 下注控件(`BetControls`,≤ 600×170)

- 布局:回合横幅与倒计时环一行;5 个预设(最小、½ 池、¾ 池、1 池、全下)+ 220 像素滑条 + 金额同一行;4 个按钮(弃牌、过牌/跟注 N、下注 X/加注到 X、全下)46 像素高;一行快捷键提示。
- 预设公式:`pot = 底池合计 + 桌上所有本轮下注`;本轮没人下注时下注到 `pot × f`;有人下注时加注到 `当前最高下注 + (pot + to_call) × f`。结果按 10 取整并夹到 `[min_raise_to, max_raise_to]`。
- 按 `can_raise` / `can_allin` 禁用对应控件,悬停提示说明原因(不完整加注不重开、对手都已全下、筹码只够跟注)。
- 所有按钮与滑条 `focus_mode = FOCUS_NONE`(同 TableHud,焦点会吃掉空格/回车)。快捷键只在轮到自己、没有说明书/确认框打开时由牌桌的 `_unhandled_input` 处理,忽略按键重复:
  F 弃牌(**能免费过牌时不弃牌**,提示「可以免费过牌」;此时点「弃牌」按钮要确认);C 或空格 过牌/跟注;R 或回车 按当前金额下注/加注;↑/↓ 增减一个大盲;1–5 选预设。WASD 仍是探头,不占用。
- 控件只发信号,不直接调用 `Net` / `Sfx`(这样截图工具能离线摆出整套 HUD)。

### 6.3 铭牌(`PokerNameplate`)

- ≤ 150×64,两行:名字(超长省略号)+ D/小盲/大盲徽记;筹码 + 状态(下注 40 / 弃牌 / 全下 / 观战 / 等待下一手 / 已离开)。行动者铜色高亮;弃牌、观战的人变暗。
- 挂点:座位原点 + (0, 1.62, 0)(高过最高的帽子),由德州牌桌从酒客的 `global_transform` 算,不改 Patron 接口。

### 6.4 输光与观战

- 不用模态确认框:输光提示放在底部中间(「你的筹码输光了」+「再领 2000」「观战」两个按钮,Esc 选观战),不挡房主的「散局」,也不会被正在按的空格/回车误触。
- 观战时底部常驻「领取 2000 上桌」。「领取」按钮按 status 显示,不按筹码数。

### 6.5 散局结算(`PokerSettlement`)

- 标题「散局结算」。行放进 ScrollContainer,最多显示 8 行(离开的人也在列表里,可能超过 8 行)。
- 列宽:名次 70、名字(自适应、省略号;离开的人标灰「已离开」)、筹码 90、领取 60、盈亏 100(赢绿、输红,带正负号与千分位)。
- 按钮:房主「回到等待厅」(`Net.request_rematch_lobby()`),其他人「离开房间」。

### 6.6 说明书

- `Rulebook.new(in_match, book)`,book ∈ {`liars`, `poker`};顶部两个页签切换。切换时重建章节导航并把当前页复位(否则停在第 0 页时不会重绘)。`main` 按书分别记住上次读到的页。
- 默认打开哪本:在房间里用 `Net.game_mode`;主菜单用 `Settings.KEY_LAST_MODE`。
- 骗子酒馆那本内容不变;其中人数改为取 `GameMode.max_players(GameMode.LIARS)`(`Protocol.MAX_PLAYERS` 已改为 8)。
- 德州那本(数字全部取自 `PokerRules`、`Protocol.TURN_TIMEOUT`):怎么玩(现金局、2–8 人、2000、10/20、再领与观战、中途入座、散局结算)、牌型、下注(动作、最小加注、不完整加注、边池、未跟注退回、超时)、操作(快捷键)。
- 新块类型 `hands`:单列 9 行,从大到小,每行:牌型名、5 张 ≤ 40×58 的示例小牌、长牌名次与短牌名次两列,短牌与长牌不同的那一处(同花/葫芦)高亮;注明 A-2-3-4-5 与 A-6-7-8-9。块等 `PokerFaces` 生成完再画牌。

### 6.7 音效(程序化)

新增 `chips`(筹码碰撞)、`chips_push`(全下推筹码)、`fold`(轻推牌);其余复用 deal / flip / win / join / bell。

## 7. 容错

- 客户端只渲染视图:任何时刻都能只凭公共视图 + 私有视图把牌桌摆对(中途加入的人靠它画出进行中的这一手);事件只负责动画,演出结束后按最新视图对账。
- `PokerScreen._ready` 先同步连接 `Net` 信号、读取 `Net.last_public` / `last_private`,之后才做任何 `await`(同 TableScreen);否则和 `game_started` 同一批到达的事件会丢。自己不在 `seats` 里时用观战机位、不建自己的酒客;没有酒客的 pid 的 `player_left` 什么也不做。
- **迟到者的第一帧**:开始演出事件队列之前,先按最新公共/私有视图把整张桌瞬时摆好(座位、筹码、下注、底池、公共牌、亮牌、按钮、2D 牌条),并丢弃在此之前排队的事件(房主每批事件之后都发视图,最新视图已经包含它们);开场运镜结束时还没收到第一份视图就等它到。
- **导演容错**:缺少前置状态的事件(没有下注堆的收注、手里没牌的弃牌、Fan 里没牌的亮牌、前面槽位空着的转牌)一律按视图补齐或跳过动画,不报错。
- 断线、离开、散局在任何阶段发生都不能卡住:每批事件之后要么有人在计时行动,要么一手间隔计时器在走,要么牌桌在等人,要么已散局。
- 筹码守恒(房主每次状态变化后):在座者筹码 + 本手已投入 + 已离开者带走的 = 累计领取总额。离开者在被移出座位之前算在座者里。
- 结算里可能出现已离开者与在座者同名(离开后用同一昵称重进),已离开的那行标「已离开」,不另做去重。

## 8. 测试策略

- **单元测试**(GUT,纯逻辑优先):
  - `PokerDeck`、`HandEvaluator`(长短牌各牌型、短牌那一处差异、两种最小顺子、踢脚、平局、只用公共牌、7 选 5)、`PotBuilder`(多层边池、死钱、无资格层并入下层、退回含已弃牌者、按 10 分池与零头顺序)。
  - `PokerTable`:正常与单挑的盲注与行动顺序、3→2 人的按钮规则、大盲只剩 10 的三种情形(单挑直接发完 / 三人时按钮已弃牌则小盲不用行动 / 按钮还没行动要跟 20)、大盲选择权、翻牌前与翻牌后的最小加注、不完整加注不重开与累计重开、对手都全下时不能加注、一轮结束条件、只剩一人(且不泄露牌型)、全下亮牌后发完公共牌、平分与零头、按钮移动(新人坐在按钮与小盲之间、按钮离开、按钮输光)、再领与观战的状态约束、中途加入下一手发牌、离开的三种情形(含唯一最高下注者离开且跟注者都全下)、超时、散局(空闲/手牌中)、两手之间的视图字段、结算盈亏。
  - 随机模拟:固定 8 个种子 × 150 手,2–8 人,长短牌各半;每一步随机合法动作,穿插随机再领、加入、离开。每一步断言筹码守恒、金额非负且是 10 的倍数、BETTING 时一定有行动者、每手有限步内结束。失败信息带种子、手号与最近若干步动作。总耗时 < 10 秒;更长的浸泡测试只在命令行开关下跑。
  - `PokerViews`:**按字段路径**检查不泄露(牌值 8–59 会和筹码数、手数撞值,不能按数值搜):board 只含公共牌;没亮过的人 `shown` 为空;视图里带牌的键只有白名单(board、players[].shown);事件里手牌只能出现在 `reveal.hands` 与已亮过的人的 `pot_won.best`。没摊牌就赢的那手(公共牌 ≥ 3)任何事件与视图都不含赢家的手牌与牌型名。
  - `PokerPacing` 与导演节奏;`GameMode` / `RoomList`(含 v3 校验规则能接受新版德州报文、新版读到 cap/seated)/ `LobbyModel` / `Protocol` / RPC 编号冻结。
  - 离线 NetworkManager(经 `_handle_join_request`、`_handle_poker_rpc`、`_handle_intent` 等内部函数):德州开局计时;一手间隔排期;回合中旁人再领只补 REBUY 预算、一手间隔中再领不缩短 `_hand_timer`;间隔里散局、断线到 1 人、`leave()` 后 `_hand_timer` 都已停;中途加入的完整顺序且下一手发牌,之后视线转发对象里有他;名单放行但会话拒收的迟到者只收到拒绝、不留在名单里;输光者在选择时间里断线则下一手提前到演完后 HAND_GAP;断线弃牌后行动继续;散局与回等待厅。
  - 输光选择时间:三人局一人输光后 3 秒再领 → 他在下一手的 dealt 里;都不选 → 下一手在演出后约 6 秒开始,不卡住;最后一个没选的人选了观战 → 间隔恢复 HAND_GAP。
  - 挂机离座:连续 2 次超时 → 下一手 `away`、不发牌、按钮与盲注跳过;sit_in 后下一手发牌;中间自己行动一次 → 清零。
  - 拆台:打完一手回等待厅 → `TableWorld` 下没有德州节点、酒客 Fan 下没有德州 Card3D;德州房间 → 离开 → 开骗子酒馆房间 → 桌子 0.95、立牌与烛台可见、有左轮、没有德州节点。
  - 迟到者:翻牌后加入,开场运镜期间到达 action / bets_collected / street → 演完后 3D 状态与视图一致,没有错误日志。
  - UI 纯逻辑:下注预设与金额夹取、按钮文案、结算排名;无头布局测试:8 个铭牌挂点在越肩与观战机位下投影到 1280×720 都在 24 像素安全边内且两两不重叠(按 150×64 估),镜头到每个头部的连线不穿过吊灯罩。
- **需要随改的现有测试与调用点**:`test_net_turn_timer`(改读 `net.last_public["current_pid"]`、调 `_handle_intent(pid, {"kind": "play", "indices": [0]})`,期望值不变,作为抽取前后行为一致的回归);`test_cursor_look`(改用 `SeatGaze`);`test_room_list`(坏样例改为 `[2, Protocol.MAX_PLAYERS + 1]`,新增 `[8, 8]` 合法);`test_lobby_model`(新 check_join 签名);`test_pacing` 与 `lobby.gd` 状态行(不再用 `Protocol.MAX_PLAYERS` 指骗子酒馆上限);`test_rulebook_content`(骗子酒馆那本用 `GameMode.max_players(GameMode.LIARS)`)。
- **联机冒烟** `MODE=holdem|short_deck tools/poker_smoke.sh`(SPEED=4,CAP_SECONDS=300):房主 `--autohost=3 --mode=$MODE --hands=6`、直连 bot、局域网发现 bot;房主日志出现 `HAND_STARTED hand=1` 后再启动第 4 个 bot(`--discover`,验证对局中的德州房间可加入)。
  通过条件:4 个进程都以 0 退出;都打印 `SESSION_OVER`;迟到者 `dealt_in ≥ 1`;房主 `net_sum=0`;每个日志都有 `GAZE peers=3 necks=3`;没有 `SCRIPT ERROR`。`tools/lan_smoke.sh`(骗子酒馆)必须原样通过。
- **截图验收**:
  - 离线展台:`tools/shot.gd --poker-showcase` 用 `TableWorld` 的机位函数(不抄数字),摆 8 位酒客、5 张公共牌、2 人亮牌、筹码、下注、2 个底池、按钮,以及用假视图数据喂的 PokerHud / BetControls / 铭牌;机位 poker_seat / poker_overview / poker_lobby,1280×720 与 4:3 各一套。
  - 真机:1 个有窗口的房主 `--autohost=8 --mode=holdem --bot --shots=<目录> --hands=3 --quit-after-match` + 7 个无头 `--autojoin=127.0.0.1:端口` bot(每台机器只有 4 个发现端口,所以用直连)。德州截图标记:deal、flop、my_turn、allin、showdown、pot_won、spectate、settlement。
- **性能**:德州展台(8 位酒客、满筹码)的帧耗时不超过同机骗子酒馆 4 人展台的 1.25 倍,并打印 `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` 对比。

### 8.1 调试开关(德州)

- `--mode=liars|holdem|short_deck`:只配合 `--autohost`;非法值退出码 1;默认房名跟着玩法。
- `--hands=N`(房主,德州):演到第 N 手的 `hand_started` 时调用 `Net.end_poker_session()`(本手结束后散局)。
- `--bot` 在德州走 `PokerScreen` 与按键/按钮相同的入口,按 `pub.actions` 选动作:能过牌时 过牌 55% / 下注(最小或 ½ 池)35% / 全下 10%;要跟注时 弃牌 15% / 跟注 60% / 加注预设 15% / 全下 10%;输光时总是「再领 2000」(观战由单测覆盖)。
- `PokerDirector` 与 `TableDirector` 一样有 `event_started(ev)` 信号,DebugFlags 挂在当前存在的导演上;`session_over` 置 `_match_finished`,房主 5 秒、客户端 4 秒后退出。迟到者不依赖 `joined_lobby` 信号。
- 日志标记:`HAND_STARTED hand=N`;自己被发到牌时 `DEALT hand=N`;`SESSION_OVER hands_dealt=K net=X`;房主另打印 `net_sum=<所有人盈亏之和>`;视线照旧打印 `GAZE peers=… necks=…`。

## 9. 与 3D 模型重做的协作

另一个会话在 `feature/model-detail` 重写 `tavern.gd`、`patron_3d.gd`、`patron_parts.gd`、`revolver_3d.gd`、`mesh_kit.gd`、`materials.gd`,并把 `tavern.gd` 拆成多个道具文件。约定:

- 他们提供 `Tavern.set_table_radius(radius: float)`(桌面、包边、铜圈、绒布跟随半径;桌面高度不变;按半径缓存网格;桌腿不动)与 `Tavern.set_table_decor_visible(visible: bool)`(连同烛台的灯一起隐藏)。本分支在 `tavern.gd` 里放了极小的接口桩,合并时以他们的实现为准。
- 本分支额外希望(合并时核对,没做的由本分支补):`set_table_radius` 同时把吊灯聚光放宽到桌面高度覆盖半径约 r + 0.15(1.45 时约 54°–58°);`set_table_decor_visible(false)` 时保留一点桌沿暖光。
- `PatronParts.SPECIES` 扩到 8 种(前 4 种的下标不变),接口 `species(index)` / `first_free_species(used)` 不变。合并前 8 人桌可能出现重复动物,属预期。
- 酒客座位局部几何(爪子、伸手、桌沿距离)与 Patron 公开接口、节点名(Body/Head/ArmL/ArmR/Hand/Fan/Hat/Neck)不变;`TableWorld` / `CardTable` 由本分支修改。
- 本分支的 3D 新内容只放在 `src/world/poker/` 下的新文件里。

## 10. 实施顺序

1. 地基(已完成):规格与计划、`GameMode`、`PokerCard`、`PokerRules`、`PokerPacing`、牌桌按玩法放大的接口、Net 接口桩。
   第二批开工前先把 `feature/liars-tavern-mvp`(0.5.2 之后的渲染预算、脖子 0.85 米、发布脚本等)合进 `feature/texas-holdem`,减少 main.gd / tavern.gd / shot.gd 的冲突。
2. 并行:德州规则引擎、3D 资产与机位、玩法接入(主菜单/等待厅/发现/协议/握手)、视线逻辑抽取、说明书。
3. 并行:网络会话(含骗子酒馆会话抽取)、德州牌桌界面。
4. 联调:bot 与冒烟、截图验收、性能检查、修正。
5. 审查:多维度审查与对抗验证,修复确认的问题。

## 11. 发布

- 本功能**不改 `project.godot`**:不加自动加载(`PokerFaces` 等用静态类),快捷键用 `InputEventKey` 的 keycode(同 TableScreen),不改渲染与输入设置。这样旧安装包能经网上或局域网更新拿到德州;协议 v5 本身不需要改 `base_build`(旧客户端收到「版本不匹配」后走更新)。
- 发布时整体合入 main(连同 `feature/liars-tavern-mvp` 与 `feature/model-detail` 的进度),按 release-update 流程;`build.json` 的 build = 那时 main 的 build + 1,version 0.7.0(0.6.0 已被左轮 5 膛那一版用掉;新玩法改第二位),base_build 不变。万一必须改 `project.godot`,base_build 设为新 build,README 与 Release 说明写明需要重装。
- README:两种玩法的介绍(骗子酒馆 2–4 人 / 德州 2–8 人)、德州规则摘要、德州操作键、新调试开关、德州冒烟与截图命令、每台机器 4 个发现端口的限制。
