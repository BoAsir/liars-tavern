# 德州扑克玩法设计文档

- 日期:2026-10-07
- 状态:已确认(用户确认:德州 2–8 人且牌桌与桌上的牌放大、房主随时散局、开打后新玩家下一手入座;盲注等细节由本设计决定)
- 依附于:[《骗子酒馆》设计文档](2026-08-14-liars-tavern-design.md)(网络、3D 酒馆、HUD 等沿用其约定)
- 协作:3D 模型重做在 `feature/model-detail` 分支进行(见 §9),本分支只在新文件里加 3D 内容

## 1. 概述与范围

新增「玩法」:开房时选择 **骗子酒馆 / 德州扑克·长牌 / 德州扑克·短牌**,等待厅里房主还可以改。
德州扑克为**无限注现金局**:

- 2–8 人;入座领 2000 筹码;盲注 10/20,固定不升。
- 筹码输光可再领 2000(次数不限),也可以选择观战;观战中随时可以领筹码,下一手上桌。
- 房主随时「散局」:打完当前这一手后结算,按「当前筹码 − 累计领取」排盈亏,然后全员回等待厅。
- 开打后新玩家仍可加入,下一手开始发牌。
- 在同一个 3D 酒馆里打:牌桌放大(半径 0.95 → 1.45 米),公共牌、手牌放大,四色大字牌面;3D 筹码与庄家按钮。

明确不做:AI 补位、前注与升盲、锦标赛、时间银行、预选动作(提前过牌/弃牌)、主动亮牌或埋牌、聊天、断线重连(断线 = 离桌)、自定义买入额。

## 2. 规则

### 2.1 牌堆

- 长牌:标准 52 张(2–A × ♠♥♦♣)。
- 短牌:去掉 2–5,共 36 张(6–A)。
- 每手由房主 RNG 用 Fisher-Yates 重新洗牌;不烧牌。

### 2.2 牌型大小

| 长牌(大 → 小) | 短牌(大 → 小,Triton / GGPoker 现行规则) |
|---|---|
| 同花顺(A 高的叫皇家同花顺) | 同花顺(A 高的叫皇家同花顺) |
| 四条 | 四条 |
| 葫芦 | **同花** |
| 同花 | **葫芦** |
| 顺子 | **三条** |
| 三条 | **顺子** |
| 两对 | 两对 |
| 一对 | 一对 |
| 高牌 | 高牌 |

- A 可以当最小牌接顺子:长牌 A-2-3-4-5 是最小顺子(按 5 高算);短牌 A-6-7-8-9 是最小顺子(按 9 高算)。同花顺同理。
- 牌型相同按标准踢脚比较;五张完全一样则平分。花色不分大小。
- 7 选 5:2 张手牌 + 5 张公共牌里取最大的 5 张(可以只用公共牌)。

### 2.3 庄家与盲注

- 筹码单位 10:所有下注额都是 10 的倍数。起始 2000、盲注 10/20、分池按 10 为单位分,因此筹码永远是 10 的倍数。
- **上桌者**:筹码 > 0、没离开、没在观战的玩家(含中途加入后等待的人)。不足 2 人不开新的一手,牌桌等待。
- 庄家按钮:第一手随机;之后顺时针移到上一手按钮之后的下一位上桌者(上一手的按钮已离开时,以他原来的座位位置为准)。不处理死按钮。
- 小盲 = 按钮后的下一位上桌者,大盲 = 再下一位。**单挑**(2 人)时按钮下小盲,另一人下大盲。
- 筹码不够盲注就全下;其他人跟注仍按完整大盲 20 计,最小加注量也是 20。
- 新入座的人不用补盲。
- 座位顺序 = 行动顺序 = 俯视顺时针(与骗子酒馆的出牌顺序同向)。

### 2.4 下注(无限注)

- 翻牌前从大盲之后的第一位可行动者开始(单挑时按钮先行动);翻牌后从按钮之后的第一位可行动者开始(单挑时大盲先)。
- 动作:
  - **弃牌**:轮到自己就可以。
  - **过牌**:不需要跟注时。
  - **跟注**:补到当前最高下注;筹码不够就全下跟注。
  - **下注 / 加注**:统一表达为「加注到 X」(本轮自己的总下注额)。本轮还没人下注时 X ≥ 20;已有人下注时 X ≥ 当前最高下注 + 本轮最近一次完整加注的增量(翻牌前初始为大盲 20)。上限是自己全部筹码;不够最小额时只能全下。
  - **全下**:押上全部筹码。按情形属于跟注、下注或加注。
- **不完整加注**:全下的加注增量小于最小加注量时,不会重新开放加注。已经行动过的玩家再轮到时只能跟注或弃牌,除非自他上次行动以来累计被加注的量 ≥ 最小加注量(TDA 规则)。
- 大盲选择权:翻牌前所有人只跟注时,大盲仍可过牌或加注。
- 除自己之外的未弃牌玩家都已全下时,只能跟注或弃牌(不能加注)。
- 一轮结束:所有未弃牌且未全下的玩家都行动过,且下注额都等于当前最高下注。
- 未被跟注的部分:一轮结束时,最高下注者超出第二高下注的部分退回给他。
- 只剩 1 人没弃牌:他直接赢下全部底池,不亮牌。
- 没人能再下注(未弃牌者中能行动的 ≤ 1 人,且他不用再跟注)而仍有 ≥ 2 人没弃牌:先亮出所有未弃牌者的手牌,再把剩下的公共牌依次发完,然后摊牌。

### 2.5 底池与摊牌

- 边池按各玩家本手累计投入构建。弃牌者的投入是死钱:留在池里,但他不能赢。按全下额度分层,每层的有资格者 = 投入 ≥ 该层且没弃牌的玩家;相邻两层有资格者相同就合并。
- 摊牌时所有未弃牌者自动亮牌(全下时已经亮过的不再重复)。从最后一个边池到主池依次分配:有资格者中牌最大的赢。平局平分,按 10 为单位分,零头从按钮之后顺时针第一位赢家开始依次多给一个单位。

### 2.6 输光、再领与观战

- 一手结束时筹码为 0 的玩家**输光**:他的屏幕弹出「再领 2000」/「观战」。不选择不会卡住牌局,只是不再发牌给他。
- **再领**:只有筹码为 0 时可以领,每次固定 2000,不限次数,计入累计领取。领到后从下一手开始发牌;当前没有进行中的手牌且凑够 2 人时自动开下一手。
- **观战**:角色留在座位上,不发牌;镜头切到俯视观战机位;HUD 常驻「领取 2000 上桌」按钮,随时可以领。

### 2.7 中途加入与离开

- 德州房间开打后仍出现在局域网房间列表。未满 8 人时可以加入,按钮写「入座」;直连同样可以。
- 新玩家加入:领 2000(计 1 次领取),这一手旁观,下一手开始发牌。所有人的座位在下一手开始时重新排列,新人的酒客也在那时登场。
- 离开(主动离开或断线):若在本手中且没弃牌,立即视为弃牌,已投入的筹码留在池里;他的酒客立即离场,座位在下一手开始时重排。他离开时的筹码计入结算,标「已离开」。
- 房主离开 = 房间解散(同骗子酒馆)。

### 2.8 回合限时

- 每次行动限时 30 秒,外加演出时间(房主权威计时,同骗子酒馆)。超时:能过牌就过牌,否则弃牌。

### 2.9 散局与结算

- 房主在牌桌上点「散局」并确认:有进行中的手牌就打完这一手再结算(公共状态标记 `ending`,HUD 显示「本手结束后散局」);没有就立即结算。
- 结算每位玩家(含已离开的):当前筹码、累计领取(次数 × 2000)、盈亏 = 筹码 − 累计领取。按盈亏从高到低排名。所有人盈亏之和恒为 0(筹码守恒)。
- 结算面板:房主「回到等待厅」(全员回等待厅,准备状态重置),其他人「离开房间」。

## 3. 玩法、房间与协议

### 3.1 GameMode(`src/core/game_mode.gd`,纯数据)

```gdscript
class_name GameMode
const LIARS := "liars"
const HOLDEM := "holdem"            # 德州·长牌
const SHORT_DECK := "short_deck"    # 德州·短牌
const ALL := [LIARS, HOLDEM, SHORT_DECK]
const DEFAULT := LIARS
static func is_valid(mode: Variant) -> bool          # String 且在 ALL 里
static func is_poker(mode: String) -> bool
static func is_short_deck(mode: String) -> bool
static func label(mode: String) -> String            # 骗子酒馆 / 德州扑克·长牌 / 德州扑克·短牌
static func short_label(mode: String) -> String      # 骗子酒馆 / 德州·长牌 / 德州·短牌
static func min_players(mode: String) -> int         # 2
static func max_players(mode: String) -> int         # 骗子酒馆 4,德州 8
static func allows_late_join(mode: String) -> bool   # 德州 true
```

桌子尺寸属于 3D 层:`SeatLayout.table_radius_for(mode)`(骗子酒馆 `TABLE_RADIUS`,德州 `POKER_TABLE_RADIUS`)与 `SeatLayout.seat_radius_for(table_radius)`。

### 3.2 开房与等待厅

- 主菜单「开一桌」区加玩法三段切换(骗子酒馆 / 德州·长牌 / 德州·短牌),记住上次的选择(`Settings.KEY_LAST_MODE`)。默认房名:骗子酒馆「X 的酒馆」,德州「X 的牌局」。
- 等待厅标题下显示玩法与人数范围(如「德州扑克·短牌 · 2–8 人」)。房主可以用同样的三段切换改玩法,改了全员准备状态重置;当前人数超过某玩法上限时,该选项不可选并提示原因。
- 房间列表每行显示玩法标签与座位圆点(最多 8 个)。加入按钮:可加入时「加入」;德州对局中未满时「入座」;满了「已满」;骗子酒馆对局中「对局中」。

### 3.3 协议与发现

- `Protocol.VERSION = 4`(v4:玩法选择 + 德州扑克)。
- `Protocol.MAX_PLAYERS = 8`,改为**所有玩法的绝对上限**,用于传输层槽位(`MAX_TRANSPORT_CLIENTS = MAX_PLAYERS + 2`)、发现报文校验、主菜单座位圆点。各玩法上限一律用 `GameMode.max_players(mode)`;骗子酒馆专属的文案与演出预算测试改用 `GameMode.max_players(GameMode.LIARS)`。
- 发现报文新增 `"mode": String` 与 `"playing": bool`;`"max"` 改为该玩法上限;`"open"` = 未满且(没开局或该玩法允许中途加入)。解析时:没有 mode(旧房主)按 LIARS;mode 不是 String 整包丢弃;未知玩法标为不兼容。
- 等待厅 meta 加 `"mode"`。
- `rpc_join_accepted(info: Dictionary)`,`info = {"in_game": bool}`。in_game 为真时客户端不进等待厅,等随后的 `rpc_game_started`。
- `rpc_game_started(seats: Array, info: Dictionary)`,`info = {"mode": String, "late": bool}`。
- 只新增一个 RPC:`rpc_poker_intent(action: String, amount: int)`(客户端 → 房主)。
- **RPC 编号约束**:Godot 按方法名排序给 RPC 编号。新增或改名的 RPC 方法名必须排在 `rpc_join_request` 之后(`rpc_poker_intent` 满足)。不得新增排在它之前的 RPC,否则旧版本客户端收不到「版本不匹配」的拒绝。为此加单元测试,锁定排序后前 8 个 RPC 方法名不变。

## 4. 架构

### 4.1 文件(★ 新增,✎ 修改)

```text
src/core/game_mode.gd ★
src/core/poker/poker_card.gd ★      牌编码与文字
src/core/poker/poker_rules.gd ★     常量(起始筹码、盲注、单位、座位上限)
src/core/poker/poker_deck.gd ★      建牌/洗牌(长/短)
src/core/poker/hand_evaluator.gd ★  7 选 5 牌型评估(长/短)
src/core/poker/pot_builder.gd ★     边池、退回未跟注、按单位分池
src/core/poker/poker_table.gd ★     房主端状态机(过长时拆出 betting_round.gd)
src/net/poker_views.gd ★  src/net/poker_pacing.gd ★
src/net/liars_session.gd ★(从 network_manager 抽出)  src/net/poker_session.gd ★
src/net/network_manager.gd ✎  protocol.gd ✎  lobby_model.gd ✎  room_list.gd ✎
src/world/poker/poker_faces.gd ★  chip_stack_3d.gd ★  poker_chips.gd ★  poker_cards.gd ★
src/world/poker/dealer_button_3d.gd ★  poker_layout.gd ★
src/world/table_world.gd ✎  seat_layout.gd ✎  card_table.gd ✎  card_faces.gd ✎  tavern.gd ✎(仅接口桩,见 §9)
src/ui/poker/poker_screen.gd ★  poker_director.gd ★  poker_hud.gd ★  bet_controls.gd ★
src/ui/poker/poker_nameplate.gd ★  poker_settlement.gd ★
src/ui/table/seat_gaze.gd ★(从 table_screen 抽出视线与探头)  table_screen.gd ✎
src/ui/main.gd ✎  main_menu/main_menu.gd ✎  lobby/lobby.gd ✎  settings.gd ✎  sfx.gd ✎  debug_flags.gd ✎
src/ui/rulebook/* ✎(德州说明书)
tools/poker_smoke.sh ★
```

### 4.2 房主端会话(NetworkManager 解耦)

NetworkManager 只管连接、等待厅、RPC 收发与计时器。玩法逻辑放进会话对象(RefCounted):

```gdscript
# LiarsSession / PokerSession 共同接口
func start(seat_order: Array, names: Dictionary, rng: RandomNumberGenerator) -> Array   # 开局事件
func handle_intent(pid: int, intent: Dictionary) -> Dictionary  # {"ok", "error"?, "events"?}
func on_disconnect(pid: int) -> Array
func on_turn_timeout() -> Dictionary
func public_view(turn_time_left: float) -> Dictionary
func private_view(pid: int) -> Dictionary
func viewers() -> Array                  # 要收私有视图的 pid
func is_over() -> bool
func has_turn() -> bool                  # 当前有人在计时行动
func estimate(events: Array) -> float    # 这一批事件的演出预算
func turn_timer_after(events: Array, pending: float, time_left: float) -> float
# 德州专有(LiarsSession 返回空/false)
func supports_late_join() -> bool
func add_player(pid: int, name: String) -> Array
func next_hand_ready() -> bool           # 现在可以(在排队演出之后)开下一手
func start_next_hand() -> Array
func request_end() -> Array
```

- 意图字典:骗子酒馆 `{"kind": "play", "indices": [...]}` / `{"kind": "challenge"}`;德州 `{"kind": action, "amount": int}`,action ∈ `fold` `check` `call` `raise` `allin` `rebuy` `spectate`。
- NetworkManager 新增一手间隔计时器 `_hand_timer`:每批事件之后若 `next_hand_ready()`,就在 `pending + PokerPacing.HAND_GAP` 秒后调用 `start_next_hand()`。牌桌在等人(不足 2 人)时,再领或新人入座让条件满足,同样按这个规则排期。
- 断线调用 `on_disconnect(pid)`;中途加入调用 `add_player`;房主散局 `Net.end_poker_session()` → `request_end()`;`request_rematch_lobby()` 以 `is_over()` 判定。
- 视线转发与校验的成员范围改为本场所有成员(含中途加入、观战的人),不再只看开局座位表。

### 4.3 Net 公开接口变化

```gdscript
var game_mode := GameMode.DEFAULT     # 房主:房间玩法;客户端:来自等待厅 meta 或开局 info
func host_game(pname: String, room_name: String, preferred_port := 0, mode := GameMode.DEFAULT) -> Error
func set_game_mode(mode: String) -> bool       # 仅房主、等待厅中;人数超过上限返回 false
func max_players() -> int                       # 当前玩法上限
func submit_poker_action(action: String, amount := 0) -> void   # fold / check / call / raise / allin
func request_rebuy() -> void
func request_spectate() -> void
func end_poker_session() -> void               # 仅房主
```

信号不变(`game_started` / `game_events` / `state_public_updated` / `state_private_updated` / `intent_rejected` / `returned_to_lobby` / `lobby_updated`)。发出 `game_started` 之前 `game_mode` 已设好。

### 4.4 德州状态机 PokerTable(`src/core/poker`,纯逻辑,只在房主端运行)

```gdscript
class_name PokerTable
enum Phase { IDLE, BETTING, OVER }        # IDLE:两手之间/等人;OVER:已散局
func _init(short_deck: bool, rng: RandomNumberGenerator)
func seat(pid: int) -> void                # 开局入座:筹码 2000,领取 1 次
func add_player(pid: int) -> Array         # 中途加入 → [player_joined]
func remove_player(pid: int) -> Array      # 离开/断线
func can_start_hand() -> bool
func start_hand() -> Array
func act(pid: int, action: String, amount := 0) -> Dictionary
func timeout_action() -> Dictionary        # 当前行动者:能过牌就过牌,否则弃牌
func rebuy(pid: int) -> Dictionary
func spectate(pid: int) -> Dictionary
func request_end() -> Array
func legal_actions(pid: int) -> Dictionary
func results() -> Array                    # [{"pid", "stack", "buyins", "net", "left"}] 按 net 降序
```

- `act` 的 amount 只对 `raise` 有效,含义为「加注到」(本轮总下注额,10 的倍数);其他动作忽略 amount。本轮没人下注时,事件里把这次 raise 记为 `bet`。
- 错误码(与 `Protocol.ERROR_MESSAGES` 对应):`not_your_turn`、`invalid_action`、`invalid_amount`、`no_hand`、`session_over`、`cannot_rebuy`、`not_seated`。
- 所有入参来自网络,一律校验类型与范围(action 必须是已知字符串,amount 必须是 int)。

玩家状态(`players[].status`):

| status | 含义 |
|---|---|
| `active` | 在本手中,还能行动 |
| `allin` | 在本手中,已全下 |
| `folded` | 本手已弃牌 |
| `waiting` | 有筹码但不在本手中(中途加入或手牌中途再领),下一手发牌 |
| `busted` | 筹码 0,还没选择 |
| `spectating` | 筹码 0,选择了观战 |
| `left` | 已离开,下一手开始时移出座位 |

`legal_actions(pid)`:不轮到他时返回 `{}`;否则返回
`{"to_call", "call_amount", "can_check", "can_raise", "min_raise_to", "max_raise_to"}`。
`to_call = 当前最高下注 − 他本轮已下`,`call_amount = min(to_call, 筹码)`,`max_raise_to = 本轮已下 + 筹码`。
不够最小加注额时 `min_raise_to = max_raise_to`(只能全下)。

### 4.5 事件(房主 → 全体,客户端按顺序演出)

| type | 字段 | 说明 |
|---|---|---|
| `hand_started` | hand, button, sb, bb, seats(座位顺序 pid), dealt(发牌顺序,从小盲起) | 新的一手;客户端按 seats 重排座位 |
| `blind` | pid, kind(`sb`/`bb`), amount, bet, stack, all_in | 下盲 |
| `hole_cards` | hand, pids(发牌顺序) | 每人 2 张;牌面在各自的私有视图里 |
| `turn` | pid | 轮到某人;可选动作看公共视图的 `actions` |
| `action` | pid, action(`fold`/`check`/`call`/`bet`/`raise`), amount(这次放进去的), bet(本轮累计), stack, all_in, timeout | 玩家行动 |
| `bets_collected` | pots([{amount, eligible}]), refund({pid, amount} 或 {}) | 一轮结束:先退未跟注部分,再把下注收进底池 |
| `street` | street(`flop`/`turn`/`river`), cards(新牌), board(全部公共牌) | 发公共牌 |
| `reveal` | hands([{pid, cards}]), reason(`allin`/`showdown`) | 亮牌 |
| `pot_won` | index, amount, winners, shares({pid: 数额}), hand_name, best({pid: 5 张}), uncontested | 分配一个底池 |
| `hand_over` | hand, stacks({pid: 筹码}), busted([pid]) | 一手结束 |
| `rebuy` | pid, amount, buyins, stack | 再领筹码 |
| `spectate` | pid | 选择观战 |
| `player_joined` | pid, name | 中途加入(下一手发牌) |
| `player_left` | pid | 离开或断线 |
| `ending` | — | 房主散局:本手结束后结算 |
| `session_over` | results([{pid, name, stack, buyins, net, left}]) | 结算 |

单个底池时 index 为 0;多个底池时 0 是主池,依次是边池。

### 4.6 视图(PokerViews)

公共视图(所有人一样,永远不含未亮的手牌):

```text
{
  "mode": String, "hand": int, "phase": "idle"|"betting"|"over",
  "street": "preflop"|"flop"|"turn"|"river"|"showdown"|"",
  "board": [牌], "pots": [{"amount", "eligible"}],     # 已收进底池的部分,不含本轮下注
  "button": pid|null, "sb": pid|null, "bb": pid|null,
  "current_pid": pid|null, "current_bet": int,
  "actions": {} 或 {"pid", "to_call", "call_amount", "can_check", "can_raise", "min_raise_to", "max_raise_to"},
  "blinds": [10, 20],
  "players": [{"pid", "name", "stack", "bet", "committed", "status", "buyins", "net", "shown": [牌]}],  # 座位顺序
  "turn_time_left": float, "ending": bool,
  "results": [] 或结算行(phase 为 over 时)
}
```

私有视图:`{"hand": int, "hole": [两张] 或 [], "best": {} 或 {"category", "name", "cards": [5 张]}}`。公共牌 ≥ 3 张时由房主算好 best。

牌用 int 编码(`PokerCard`):`card = rank * 4 + suit`,rank 2–14(J=11、Q=12、K=13、A=14),suit 0=♠ 1=♥ 2=♦ 3=♣,取值 8–59。
它与骗子酒馆的牌型(-1 牌背、0–3)不重叠,`CardFaces.texture(kind)` 可以按取值范围分流。

### 4.7 演出预算(`PokerPacing`)

房主按这些预算延长回合计时与一手间隔。导演每段演出的实际时长必须不超过预算,由测试读取常量来保证(同骗子酒馆的 `Pacing`)。

| 常量 | 秒 | 说明 |
|---|---|---|
| INTRO | = Pacing.INTRO | 开场运镜 |
| HAND_STARTED | 1.4 | 收上一手的牌与筹码、重排座位、移动按钮 |
| BLIND | 0.5 | 每个盲注 |
| HOLE_BASE / HOLE_PER_CARD | 0.45 / 0.07 | 发手牌:基础 + 每张 |
| ACTION / ACTION_ALLIN | 0.7 / 1.2 | 一次行动 / 全下 |
| BETS_COLLECTED | 0.7 | 收下注进底池 |
| STREET_BASE / STREET_PER_CARD | 0.5 / 0.4 | 发公共牌 |
| REVEAL_BASE / REVEAL_PER_HAND | 0.4 / 0.5 | 亮牌 |
| POT_WON | 2.0 | 每个底池的分配 |
| HAND_OVER | 0.6 | 一手收尾 |
| REBUY / PLAYER_LEFT / PLAYER_JOINED | 0.6 / 0.8 / 0.2 | 座位变化 |
| SESSION_OVER | 3.0 | 结算前的谢幕 |
| HAND_GAP | 1.5 | 一手之间的停顿(房主排期用,不对应事件) |

`turn` 事件交出回合(`TURN_EVENTS = ["turn"]`),回合计时算法与骗子酒馆相同。

## 5. 3D 表现

### 5.1 牌桌与座位

- `SeatLayout.POKER_TABLE_RADIUS = 1.45`,`SeatLayout.SEAT_GAP = SEAT_RADIUS − TABLE_RADIUS`(0.30)。座位半径 = 桌面半径 + SEAT_GAP,所以酒客到桌沿的距离不变,酒客座位局部坐标里的爪子与伸手位置照常可用。
- `TableWorld.configure_table(radius)`:设置桌面半径(调用 `Tavern.set_table_radius`)与座位半径;越肩、观战、等待厅等机位按桌子大小推远。主菜单与骗子酒馆用 0.95,德州用 1.45。进入等待厅与牌桌时按房间玩法设置,回主菜单复原。
- 德州时隐藏桌面摆设(`Tavern.set_table_decor_visible(false)`)与骗子酒馆的目标牌立牌(`CardTable.set_stand_visible(false)`),不摆左轮(`arrange(..., with_revolvers = false)`)。
- 最多 8 位酒客按 `SeatLayout.seat_angle` 均匀分布(函数本身支持任意人数)。

### 5.2 牌面(`PokerFaces`)

- 52 张牌面在离屏 SubViewport 中程序化绘制。风格沿用 `CardFaces` 的纸质底与金边;牌背沿用现有牌背。
- 清晰优先:四色花色(♠ 墨黑、♥ 红、♦ 蓝、♣ 绿)。四角是大号点数 + 花色,中央一个大花色,J/Q/K 在中央加冠饰。花色用多边形与圆绘制,不依赖字体里的花色字形。
- 进入德州房间(等待厅或牌桌)时按需生成一次,之后缓存。无头模式退化为纯色纹理。新增显存约 40 MB 以内。

### 5.3 卡牌尺寸

- 公共牌放大约 1.6 倍,在桌心排成一行;摊牌时亮出的手牌放大约 1.4 倍,摆在各自面前的桌上;自己举在胸前的两张手牌放大约 1.25 倍。
- 具体倍数与位置用截图调,原则是 1280×720 下站在自己座位能一眼认出所有公共牌与亮出的牌。
- HUD 左下另以 2D 大图显示自己的两张手牌与当前最大牌型(双保险)。

### 5.4 筹码与庄家按钮

- 面额与颜色:10 象牙白、50 红、100 绿、500 黑、1000 金、5000 紫。金额按面额贪心拆分,每列最多 10 枚,每堆最多显示 40 枚,准确金额由 2D 标签显示。
- 每个座位有一摞筹码(桌沿内侧、偏右手)和本轮下注(更靠桌心);桌心有底池(一个池一堆,边池并排)。
- 动画:下注时筹码从筹码堆滑到下注位;一轮结束收进底池;赢家的底池滑回赢家;再领时在座位前落下一摞新筹码。
- 庄家按钮:白色圆片写「D」,一手开始时滑到新的按钮座位前。

### 5.5 机位

- 有座位的人(含输光还没选择的)用越肩机位,距离与高度按桌子大小推远。观战与等待下一手的人用俯视观战机位。
- 机位要避开吊灯罩,8 人桌在 1280×720 下所有人的铭牌都不出画、不互相压住(截图验证)。

### 5.6 酒客动作(复用 Patron 现有接口)

- 当前行动者高亮(`set_active`),其他人看向他。
- 下注/跟注/全下时伸手向桌心(`reach_toward_center`)。全下时轻微震屏。
- 弃牌时把牌推进桌心的弃牌堆,表情 `worried`。
- 赢下底池 `celebrate`;输光时表情 `worried`;离开 `vanish`;新人入座 `appear`(由 `arrange` 负责)。

## 6. 界面

### 6.1 德州牌桌 HUD

- 左上:「德州扑克·长牌 · 盲注 10/20 · 第 N 手」,下面是底池总额(含边池明细)。
- 右上:「规则 · F1」;房主另有「散局」(散局请求后变灰,显示「本手结束后散局」)。离开牌桌仍用 Esc(确认后离开;房主离开会解散)。
- 底部居中:回合横幅与倒计时环 + 下注控件(轮到自己时)。观战/输光时换成「领取 2000 上桌」按钮;等待下一手时显示「下一手开始发牌」。
- 左下:自己的名字、筹码、盈亏、领取次数;两张手牌的 2D 大图 + 当前最大牌型。
- 右下:事件日志。画面中部是大字宣告(「翻牌」「全下!」「X 赢得 1,240 · 葫芦」等)。

### 6.2 下注控件(`BetControls`)

- 按钮:「弃牌」「过牌 / 跟注 N」「下注 X / 加注到 X」「全下」。
- 滑条(步长 10)+ 预设:最小、½ 池、¾ 池、1 池、全下。
  预设公式:`pot = 底池合计 + 桌上所有本轮下注`;本轮没人下注时下注到 `pot × f`;有人下注时加注到 `当前最高下注 + (pot + to_call) × f`。结果按 10 取整并夹到 `[min_raise_to, max_raise_to]`。
- 快捷键:F 弃牌;C 或空格 过牌/跟注;R 或回车 按当前金额下注/加注;↑/↓ 增减一个大盲;1–5 选预设。WASD 仍是探头,不占用。
- 不能加注时(不完整加注不重开、对手都已全下、筹码只够跟注)加注区禁用,并在悬停提示里说明原因。

### 6.3 铭牌(`PokerNameplate`)

两行,紧凑:名字 + D/小盲/大盲徽记;筹码 + 状态(下注 40 / 弃牌 / 全下 / 观战 / 等待下一手 / 已离开)。行动者铜色高亮;弃牌、观战的人变暗。

### 6.4 输光与观战

- 输光时弹出确认框「你的筹码输光了」:「再领 2000」(确认)/「观战」(取消,Esc 同)。
- 观战时 HUD 常驻「领取 2000 上桌」。中途加入的人在下一手之前显示「已入座,下一手开始发牌」。

### 6.5 散局结算(`PokerSettlement`)

标题「散局结算」。每行:名次、名字(已离开的人标灰「已离开」)、筹码、领取次数、盈亏(赢绿、输红)。按钮:房主「回到等待厅」,其他人「离开房间」。

### 6.6 说明书

- 说明书分两本:骗子酒馆(现有章节不变)与德州扑克。翻开时默认显示当前房间玩法那一本;主菜单默认显示上次选择的玩法,顶部可以切换。
- 德州的章节:怎么玩(现金局、2000 筹码、盲注、再领、观战、散局)、牌型大小(长牌与短牌对照,带示例牌面)、下注(动作、最小加注、全下与边池)、操作(快捷键)。数字一律取自规则常量。

### 6.7 音效(程序化)

新增 `chips`(筹码碰撞)、`chips_push`(全下推筹码)、`fold`(轻推牌)。其余复用 deal / flip / win / join / bell 等。

## 7. 容错

- `rpc_poker_intent` 来自不可信对端:action 必须是已知字符串,amount 必须是 int 且在合理范围内,发送者必须是本场成员;不合法时回 `rpc_intent_rejected`。
- 客户端只渲染视图。任何时刻都能只凭公共视图 + 私有视图把牌桌摆对(中途加入的人靠它画出进行中的这一手),事件只负责动画。演出结束后按最新视图对账。
- 中途加入的客户端先收到 `rpc_join_accepted({"in_game": true})`,再收到 `rpc_game_started(seats, {"mode", "late": true})` 与当前视图,直接进牌桌。
- 断线、离开、散局在任何阶段发生都不能让状态机卡住:每批事件之后要么有人在计时行动,要么一手间隔计时器在走,要么牌桌在等人,要么已散局。
- 房主端每次状态变化后筹码守恒:所有人筹码 + 本手已投入 + 已离开者带走的 = 累计领取总额(测试断言)。

## 8. 测试策略

- 单元测试(GUT,纯逻辑优先):
  - `PokerCard` 编解码;`PokerDeck` 长 52 张、短 36 张各不重复,固定种子可复现。
  - `HandEvaluator`:长短牌每种牌型、短牌两处顺序差异、两种最小顺子(A-2-3-4-5 / A-6-7-8-9)、踢脚、平局、只用公共牌、7 选 5 取最大、同花顺与皇家同花顺。
  - `PotBuilder`:多人全下的多层边池、弃牌死钱、退回未跟注、按 10 分池与零头顺序。
  - `PokerTable`:正常与单挑的盲注和行动顺序、短码盲注、大盲选择权、最小加注、不完整加注不重开、一轮结束条件、只剩一人、全下亮牌后发完公共牌、平分、按钮移动(含加入、离开、输光)、再领与观战的约束、中途加入下一手发牌、手牌中途断线(含轮到他时)、超时过牌/弃牌、手牌中途散局与空闲散局、结算盈亏。
  - 随机模拟:上千手随机合法动作,夹杂随机再领、加入、离开,每一步断言筹码守恒、筹码非负、每手都会结束,且状态机不会卡住。
  - `PokerViews`:公共视图不泄露未亮的手牌;`actions` 与 `legal_actions` 一致。
  - `PokerPacing`:导演各段时长常量不超过预算。
  - `GameMode` / `RoomList` / `LobbyModel` / `Protocol`:mode 字段解析、各玩法上限、德州对局中可加入、RPC 编号前缀不变。
  - 离线 NetworkManager:德州开局计时、意图、一手间隔排期、中途加入、断线、散局、回等待厅。
  - UI 纯逻辑:下注预设与金额夹取、结算排名、牌桌控制器状态。
- 联机冒烟 `tools/poker_smoke.sh`:房主 + 局域网发现 bot + 直连 bot,开局后再加一个中途加入的 bot。打满 N 手后房主散局。通过条件:全部以 0 退出、都打印 `SESSION_OVER`、中途加入者至少打了 1 手、日志里没有脚本错误。长牌、短牌各跑一次。
- 截图验收:窗口模式跑 bot 对局并 `--shots`,检查 8 人桌座位、铭牌、公共牌大小与清晰度、筹码、HUD 在 1280×720 下不重叠。

## 9. 与 3D 模型重做的协作

另一个会话在 `feature/model-detail` 重写 `tavern.gd`、`patron_3d.gd`、`patron_parts.gd`、`revolver_3d.gd`、`mesh_kit.gd`、`materials.gd`,并把 `tavern.gd` 拆成多个道具文件。约定:

- 他们提供 `Tavern.set_table_radius(radius: float)`(桌面、包边、铜圈、绒布跟随半径;桌面高度不变;按半径缓存网格)与 `Tavern.set_table_decor_visible(visible: bool)`(连同烛台的灯一起隐藏)。本分支在 `tavern.gd` 里先放一个极小的接口桩,合并时以他们的实现为准。
- `PatronParts.SPECIES` 扩到 8 种(前 4 种的下标不变),接口 `species(index)` / `first_free_species(used)` 不变。合并前 8 人桌可能出现重复动物,属预期。
- 酒客座位局部几何(爪子、伸手、桌沿距离)与 `Patron` 公开接口、节点名不变;`TableWorld` / `CardTable` 由本分支修改。
- 本分支的 3D 新内容只放在 `src/world/poker/` 下的新文件里。

## 10. 实施顺序

1. 地基:规格与计划、`GameMode`、`PokerCard`、`PokerRules`、`PokerPacing`、Net 接口桩。
2. 并行:德州规则引擎、3D 资产与牌桌尺寸、玩法与房间接入(主菜单/等待厅/发现/协议)、视线逻辑抽取、说明书。
3. 并行:网络会话(含骗子酒馆会话抽取)、德州牌桌界面。
4. 联调:bot 与冒烟、截图验收、修正。
5. 审查:多维度审查与对抗验证,修复确认的问题。
