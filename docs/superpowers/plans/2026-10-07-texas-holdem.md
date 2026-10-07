# 德州扑克玩法 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 开房可选玩法;新增德州扑克(长牌 / 短牌,2–8 人无限注现金局,2000 筹码、盲注 10/20、输光再领或观战、中途入座、房主散局结算),在放大的 3D 酒馆牌桌上进行。

**Architecture:** 规则全部在 `src/core/poker/` 的纯逻辑里(房主端状态机 `PokerTable`)。网络层把玩法逻辑抽成会话对象(`LiarsSession` / `PokerSession`),`NetworkManager` 只管连接、等待厅、RPC 与计时。
客户端德州牌桌(`src/ui/poker/`)只渲染公共/私有视图,事件只驱动动画;3D 新内容全部放在 `src/world/poker/` 的新文件里。

**Tech Stack:** Godot 4.7.1 / GDScript,GUT 9.7 单元测试,ENet 局域网,全部美术与音效程序化生成。

**规格:** [docs/superpowers/specs/2026-10-07-texas-holdem-design.md](../specs/2026-10-07-texas-holdem-design.md)。规格是唯一的事实来源;本计划与规格冲突时以规格为准,并回报冲突。

---

## 0. 通用约定(每个任务都适用)

- **工作目录**:每个任务在自己的 git worktree 里做(基于 `feature/texas-holdem`),完成后提交到该 worktree 的分支,由协调者合并。不要改主仓库目录(`/Users/murphy/Desktop/dev/LiarsTavern` 本身)里的任何文件——其他会话正在那里工作。
- **Godot**:`export GODOT=/Applications/Godot.app/Contents/MacOS/Godot`。新 worktree 先导入一次(注册 class_name):`$GODOT --headless --path . --import`。之后每新增带 `class_name` 的脚本都要再导入一次。
- **跑测试**:全部 `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`(约 40 秒);
  只跑某几个文件:`-gtest=res://tests/test_a.gd,res://tests/test_b.gd`。基线:297 个测试全过。完成任务时全部测试必须通过。
- **TDD**:先写失败的测试,看它失败,再写最少的实现让它通过,然后整理。纯逻辑(规则、视图、预算、布局数学、下注预设)必须有单测;3D/界面以截图验收为主,但其中的纯函数仍要单测。
- **代码风格**:照着周围代码写——中文注释(说明「为什么」)、`snake_case`、类型标注、`const` 常量不写魔法数、单个函数 < 50 行、单个文件 < 400 行(最多 800)。网络来的数据一律先校验类型与范围。
- **提交**:中文约定式提交,如 `feat: 德州规则引擎(牌型评估、边池、下注状态机)`。一个任务可以有多次提交。
- **RPC 命名**:不得新增方法名排在 `rpc_join_request` 之前的 RPC(规格 §3.3)。
- **与模型重做分支协作**(规格 §9):不要改 `patron_3d.gd`、`patron_parts.gd`、`revolver_3d.gd`、`mesh_kit.gd`、`materials.gd`;`tavern.gd` 只保留已有的接口桩。新 3D 内容放 `src/world/poker/`。
- **截图验收**(有窗口,不能 `--headless`):`$GODOT --path . -s tools/shot.gd -- --out=<目录> --views=<机位>`,生成的 PNG 用 Read 工具查看。

## 1. 文件结构与归属

| 任务 | 新增 | 修改 |
|---|---|---|
| 0 地基(已完成) | `src/core/game_mode.gd`、`src/core/poker/poker_card.gd`、`poker_rules.gd`、`src/net/poker_pacing.gd`、对应测试 | `seat_layout.gd`(德州常量)、`tavern.gd`(接口桩)、`network_manager.gd`(接口桩) |
| 1 规则引擎 | `src/core/poker/poker_deck.gd`、`hand_evaluator.gd`、`pot_builder.gd`、`poker_table.gd`(可拆 `betting_round.gd`)、测试 | — |
| 2 3D 资产 | `src/world/poker/*.gd`、`tools/poker_showcase.gd`、测试 | `table_world.gd`、`card_table.gd`、`card_faces.gd`、`tools/shot.gd` |
| 3 玩法接入 | 测试 | `protocol.gd`、`lobby_model.gd`、`room_list.gd`、`network_manager.gd`(房间部分)、`main_menu.gd`、`lobby.gd`、`settings.gd`、`main.gd`(桌子尺寸) |
| 4 视线抽取 | `src/ui/table/seat_gaze.gd`、测试 | `table_screen.gd` |
| 5 说明书 | 测试 | `src/ui/rulebook/*.gd`、`main.gd`(说明书参数) |
| 6 网络会话 | `src/net/liars_session.gd`、`poker_session.gd`、`poker_views.gd`、测试 | `network_manager.gd`(游戏部分)、`tests/test_net_turn_timer.gd` |
| 7 德州牌桌 | `src/ui/poker/*.gd`、测试 | `main.gd`(选屏)、`sfx.gd` |
| 8 bot 与冒烟 | `tools/poker_smoke.sh`、测试 | `debug_flags.gd`、`README.md` |

执行顺序:任务 1–5 并行 → 合并 → 任务 6、7 并行 → 合并 → 任务 8 与联调 → 审查。

---

## 任务 1:德州规则引擎(`src/core/poker/`)

**Files:**
- Create: `src/core/poker/poker_deck.gd`、`hand_evaluator.gd`、`pot_builder.gd`、`poker_table.gd`(超过约 400 行就把下注轮拆到 `betting_round.gd`)
- Test: `tests/test_poker_deck.gd`、`test_hand_evaluator.gd`、`test_pot_builder.gd`、`test_poker_table_blinds.gd`、`test_poker_table_betting.gd`、`test_poker_table_showdown.gd`、`test_poker_table_seats.gd`、`test_poker_simulation.gd`
- 依赖(已存在):`PokerCard`、`PokerRules`(含 `Category`、`CATEGORY_NAMES`、`strength()`、动作与状态常量)

### 1.1 接口

```gdscript
class_name PokerDeck
static func build(short_deck: bool) -> Array[int]                      # 按点数、花色升序
static func shuffled(short_deck: bool, rng: RandomNumberGenerator) -> Array[int]   # Fisher-Yates

class_name HandEvaluator
static func evaluate(cards: Array, short_deck: bool) -> Dictionary
#   cards:5–7 张。返回 {"category": int, "score": int, "cards": [最好的 5 张,展示顺序], "name": String, "detail": String}
#   score 在同一玩法内可直接比较(大者赢,相等平局):strength << 20 | 5 个 4 位的比较点数
#   cards 展示顺序:成组的在前(四条/三条/对子),同组与踢脚按点数降序;顺子从大到小(A-2-3-4-5 为 5 4 3 2 A)
#   name:牌型名(A 高同花顺为「皇家同花顺」);detail 如「高牌 · A」「一对 · K」「两对 · A 和 8」「三条 · 9」
#        「顺子 · 到 J」「同花 · A 高」「葫芦 · Q 带 7」「四条 · 9」「同花顺 · 到 9」「皇家同花顺」
static func compare(a: Dictionary, b: Dictionary) -> int                # 1 / 0 / -1

class_name PotBuilder
static func build(committed: Dictionary, folded: Dictionary, seat_order: Array) -> Array
#   committed:pid → 本手累计投入;folded:pid → 是否弃牌(没弃牌的全下者算有资格)
#   返回 [{"amount", "eligible": [pid,按 seat_order]}],主池在前;相邻两层有资格者相同就合并;
#   没有任何有资格者的层并入下面一层(防御性)
static func uncalled(bets: Dictionary) -> Dictionary                   # 本轮最高下注超出第二高的部分:{"pid", "amount"} 或 {}
static func split(amount: int, winners: Array, unit: int) -> Dictionary # winners 已按「按钮后顺时针」排好;pid → 份额
```

`PokerTable` 的接口见规格 §4.4。另外给网络视图提供只读访问(都返回拷贝,视图层只用这些):

```gdscript
func seat_order() -> Array
func player(pid: int) -> Dictionary          # {"stack", "bet", "committed", "status", "buyins", "net", "left", "shown"}
func hole_cards(pid: int) -> Array
func board() -> Array
func pots() -> Array                         # 已收进底池的部分(不含本轮下注)
func hand_number() -> int
func street() -> String                      # PokerRules.PREFLOP… 或 ""
func phase() -> int                          # Phase.IDLE / BETTING / OVER
func current_pid() -> Variant                # int 或 null
func current_bet() -> int
func button() -> Variant                     # 本手的按钮 / 小盲 / 大盲 pid 或 null
func small_blind() -> Variant
func big_blind() -> Variant
func is_ending() -> bool
func best_hand(pid: int) -> Dictionary       # 公共牌 ≥ 3 张且他有手牌时的 evaluate 结果,否则 {}
func chips_in_play() -> int                  # 所有在座者筹码 + 本手已投入(守恒断言用)
func total_bought_in() -> int                # 所有人(含已离开)累计领取 × 2000
func departed_stacks() -> int                # 已离开者带走的筹码合计
```

测试钩子(只给测试用,写清注释):
- `var button_pid: Variant = null`:为 null 时第一手随机选按钮;测试把它设成某人,下一手的按钮就是他之后的下一位上桌者。
- `var rigged := {}`:非空时下一手不洗牌,按 `{"holes": {pid: [两张]}, "board": [5 张]}` 发(用完清空)。

### 1.2 关键行为(规格 §2 的落地细节)

- 上桌者 = status 为 `waiting` 且未离开的玩家。`can_start_hand()` = phase 为 IDLE、没在散局、上桌者 ≥ 2。
- `start_hand()`:手数加一;移除上一手标了离开的人;定按钮/小盲/大盲(单挑按钮下小盲);下盲(筹码不够全下,`current_bet` 仍记 20,最小加注量 20);发牌顺序从小盲开始每人两张;事件依次为 `hand_started`、`blind`×2、`hole_cards`、`turn`。
- 行动顺序、一轮结束、未跟注退回、不完整加注不重开(按「自他上次行动以来累计加注量 ≥ 最小加注量」判断)、大盲选择权、对手全都全下时不能加注:见规格 §2.4。
- 每一轮结束:`bets_collected`(先算退回,再把本轮下注并进 committed 重建底池);只剩一人 → `pot_won`(uncontested,不亮牌)→ `hand_over`;
  能行动的人 ≤ 1 → 在河牌前时先 `reveal`(reason `allin`,只含还没亮过的人),再依次 `street` 发完 → 摊牌;到河牌 → `reveal`(showdown)→ 摊牌。
- 摊牌:从最后一个边池到主池,每个池一个 `pot_won`(index 0 是主池);赢家多于一人时按 `split` 分,零头从按钮之后顺时针第一位赢家起每人多一个单位。
- 一手结束:清下注;在手牌中的人改回 `waiting`(筹码 > 0)或 `busted`(筹码 0);移除离开的人,记入离开名单;发 `hand_over`;若在散局中,phase → OVER 并追加 `session_over`。
- `act` 的校验顺序:phase 不是 BETTING → `no_hand`;不是当前行动者 → `not_your_turn`;action 不是 `PokerRules.BET_ACTIONS` → `invalid_action`;
  `check` 时要跟注、`call` 时不用跟注、不能加注时 `raise`/超出跟注的 `allin` → `invalid_action`;`raise` 的 amount 不是 int、不是 10 的倍数或不在 `[min_raise_to, max_raise_to]` → `invalid_amount`。
- 离开(`remove_player`):在手牌中且 active → 弃牌(若正轮到他,行动继续往下走);全下后离开 → 手牌仍有效,分完池再按最终筹码记入离开名单;不在手牌中 → 空闲时立即移除,否则这手结束时移除。事件 `player_left` 在前,后续事件跟在后面。
- `rebuy`:只有 status 为 `busted`/`spectating`(筹码 0、不在手牌中)可以,否则 `cannot_rebuy`;筹码 2000、领取次数 +1、status `waiting`。`spectate`:只有 `busted` 可以。不在座位上 → `not_seated`;phase 为 OVER → `session_over`。
- `request_end()`:IDLE → phase OVER + `[session_over]`;BETTING → 标记散局 + `[ending]`(重复调用返回 `[]`);OVER → `[]`。
- `results()`:每个在座者与离开者 `{"pid", "stack", "buyins", "net", "left"}`,按 net 降序;net 之和恒为 0。`session_over` 的 results 用它(名字由网络会话补上)。
- `player_joined` 与 `session_over` 事件里的名字由网络会话补(引擎不知道名字)。

### 1.3 测试清单(先写测试,每条都要有;牌用 `PokerCard.make(rank, suit)`,下面用「A♠」简写)

`test_poker_deck.gd`
- [ ] 长牌 52 张各不相同、最小 2;短牌 36 张各不相同、最小 6;同种子两次 shuffled 结果相同,不同种子不同。

`test_hand_evaluator.gd`(长牌)
- [ ] A♠K♠Q♠J♠10♠ + 2♥3♦ → 同花顺、name「皇家同花顺」;胜过四条 A。
- [ ] A♥2♥3♥4♥5♥ + K♠Q♠ → 同花顺「到 5」;输给 2♥…6♥ 同花顺。
- [ ] A♠2♦3♣4♥5♠ 顺子输给 2♦3♣4♥5♠6♦ 顺子;两者都赢三条。
- [ ] 四条 9 带 K 胜四条 9 带 Q(7 张里取最大踢脚)。
- [ ] KKK22 胜 QQQAA;同花比到第 5 张;AA88K 胜 AA88Q。
- [ ] 7♥7♦ + 7♣7♠K♥K♦2♣ → 四条 7 带 K(不是葫芦)。
- [ ] 三个对子 AA KK QQ + 2 → 两对 A 和 K、踢脚 Q。两个三条 999 888 + x → 葫芦 9 带 8。6 张同花取最大的 5 张。
- [ ] 公共牌 A♠K♦Q♣J♥10♠ 为顺子时两个玩家都只能用公共牌 → score 相等(平局)。
- [ ] detail 文案逐一检查(见 1.1)。

`test_hand_evaluator.gd`(短牌)
- [ ] A♠6♦7♣8♥9♠ 是顺子「到 9」,输给 6♦7♣8♥9♠10♦。
- [ ] 同花胜葫芦;三条胜顺子;四条胜同花;A♥6♥7♥8♥9♥ 是同花顺(最小的同花顺)。
- [ ] 同一手牌在长牌下葫芦胜同花、顺子胜三条(同一组输入,两种玩法结论相反)。

`test_pot_builder.gd`
- [ ] 三人各 100 → 一个池 300、三人有资格。
- [ ] A 50 全下、B 200、C 200 → 主池 150 [A,B,C],边池 300 [B,C]。
- [ ] A 100 已弃牌、B 300、C 300 → 合并成一个池 700 [B,C]。
- [ ] A 50、B 120(都全下)、C 300、D 300 → 200 [A,B,C,D]、210 [B,C,D]、360 [C,D]。
- [ ] uncalled:{A: 500, B: 200, C: 0} → {A, 300};{A: 200, B: 200} → {}。
- [ ] split:30 分给 [X, Y](单位 10)→ X 20、Y 10;70 分给三人 → 30/20/20;份额之和 = amount。

`test_poker_table_blinds.gd`
- [ ] 3 人 [1,2,3],button_pid = 3 → 本手按钮 1、小盲 2、大盲 3;小盲 10、大盲 20;第一个行动者 1(大盲之后);dealt 从 2 开始。
- [ ] 单挑 [1,2],button_pid = 2 → 按钮 1 下小盲并先行动;翻牌后 2 先行动。
- [ ] 大盲只有 15:全下 15,跟注的人仍要补到 20;小盲只有 5 同理。
- [ ] 第二手按钮顺时针移一位;跳过 busted / spectating / 已离开的人;上一手按钮离开后按他原来的座位位置往下找。

`test_poker_table_betting.gd`
- [ ] 不轮到时行动 → `not_your_turn`;未开手 → `no_hand`;未知 action → `invalid_action`。
- [ ] 要跟注时 check → `invalid_action`;raise 金额不是 10 的倍数、低于最小、高于上限 → `invalid_amount`。
- [ ] 最小加注:翻牌前 1 号加注到 60 → 下一位 min_raise_to 100;再加到 200 → 下一位 min_raise_to 340。
- [ ] 不完整加注不重开:1 加到 100、2 跟、3 全下 150 → 轮回 1 时 can_raise 为假,只能跟/弃;若 4 再全下到 200(累计 100 ≥ 80)→ 1 可以加注。
- [ ] 大盲选择权:翻牌前大家只跟 20 → 轮到大盲可过牌或加注,大盲过牌后进入翻牌。
- [ ] 一轮结束条件:所有人行动过且下注相等 → `bets_collected` → `street`(flop 3 张)→ `turn` 给按钮后第一位。
- [ ] 全员弃牌给大盲 → 退回未跟注部分、`pot_won` uncontested、无 `reveal`。
- [ ] 对手全都全下时 can_raise 为假、allin 超出跟注额 → `invalid_action`。
- [ ] timeout_action:能过牌就过牌,否则弃牌;事件 timeout 为真。

`test_poker_table_showdown.gd`(用 rigged 定牌)
- [ ] 河牌摊牌:两人比牌,赢家拿全部;`reveal` reason 为 showdown,含两人手牌。
- [ ] 平局按 10 分池,零头给按钮后第一位赢家。
- [ ] 翻牌前全下被跟:`reveal`(allin)→ flop/turn/river 三个 `street` → `pot_won`。
- [ ] 三人不同额度全下:主池与边池分别由不同的人赢,`pot_won` 从最后一个边池到主池。
- [ ] 弃牌者的投入留在池里;最高下注没人跟的部分退回。

`test_poker_table_seats.gd`
- [ ] 输光的人在 `hand_over.busted` 里,status `busted`,不再发牌;rebuy 后 2000、buyins 2、下一手发牌;有筹码时 rebuy → `cannot_rebuy`。
- [ ] spectate 只对 busted 有效;观战的人可以 rebuy。
- [ ] 手牌中 add_player → `player_joined`、status `waiting`、这手不发牌;下一手座位排在最后并发牌。
- [ ] 轮到某人时他离开 → `player_left` 后行动给下一位;只剩一人 → 直接赢池。不轮到他时离开 → 这手结束时移除,结算里标 left。
- [ ] 全下后离开:手牌仍参与摊牌,赢了按最终筹码记入离开名单。
- [ ] request_end:空闲 → `session_over`;手牌中 → `ending`,这手打完追加 `session_over`;散局后一切意图 → `session_over` 错误。
- [ ] results 按 net 降序,net 之和为 0(含离开的人)。

`test_poker_simulation.gd`
- [ ] 固定若干种子,每个种子 300 手(长短牌各半):每一步随机选一个合法动作(按 legal_actions;raise 在 [min, max] 里随机取 10 的倍数),每手开始前随机再领、偶尔加入新人或让人离开(保持 2–8 人)。
  每一步断言:`chips_in_play() + departed_stacks() == total_bought_in()`;所有筹码 ≥ 0 且是 10 的倍数;BETTING 时一定有当前行动者;每手在有限步内结束;`can_start_hand()` 为真时 `start_hand()` 一定成功。

### 1.4 步骤

- [ ] 写 `test_poker_deck.gd` → 失败 → 实现 `PokerDeck` → 通过 → 提交。
- [ ] 写 `test_hand_evaluator.gd` → 失败 → 实现 `HandEvaluator`(枚举 7 选 5 的 21 种组合,逐个评 5 张取最大)→ 通过 → 提交。
- [ ] 写 `test_pot_builder.gd` → 失败 → 实现 `PotBuilder` → 通过 → 提交。
- [ ] 按 blinds → betting → showdown → seats 的顺序逐个写测试文件并实现 `PokerTable`,每个文件通过后提交。
- [ ] 写 `test_poker_simulation.gd`,修掉它找出的问题 → 全部测试通过 → 提交 `feat: 德州规则引擎(牌型评估、边池、下注状态机、座位与再领)`。

---

## 任务 2:3D 资产与牌桌尺寸(`src/world/poker/`)

**Files:**
- Create: `src/world/poker/poker_faces.gd`、`chip_stack_3d.gd`、`poker_chips.gd`、`poker_cards.gd`、`dealer_button_3d.gd`、`poker_layout.gd`、`tools/poker_showcase.gd`
- Modify: `src/world/card_faces.gd`(德州牌分流)、`src/world/table_world.gd`(机位随桌子大小)、`tools/shot.gd`(德州机位与 `--poker-showcase`)
- Test: `tests/test_poker_faces.gd`、`test_chip_stack.gd`、`test_poker_layout.gd`、`test_poker_world.gd`;更新 `tests/test_table_world.gd`
- 已存在(地基):`TableWorld.configure_table(radius)`、`table_radius`/`seat_radius`、`CardTable.set_stand_visible`、`Tavern.set_table_radius`/`set_table_decor_visible`(桩)、`main.apply_table_mode(mode)`

### 2.1 接口

```gdscript
class_name PokerFaces       # 风格见规格 §5.2;无头模式退化为纯色;并发调用 build 时等第一次完成
static func build(host: Node) -> void
static func is_built() -> bool
static func texture(card: int) -> Texture2D   # 未生成时返回纯色占位
static func clear() -> void
# CardFaces.texture(kind):PokerCard.is_card(kind) 时转给 PokerFaces.texture(kind)。CardFaces.is_built() 的含义不变(只管骗子酒馆的 5 张)

class_name PokerLayout      # 纯数学:位置都在「本机座位角度 = 0」的世界坐标里,桌面高度 SeatLayout.TABLE_TOP
const BOARD_SCALE := 1.6      # 公共牌放大倍数(截图调)
const SHOWN_SCALE := 1.4      # 摊牌亮出的手牌
const MY_HAND_SCALE := 1.25   # 自己举在胸前的手牌
static func board_slot(index: int) -> Transform3D                          # 5 张公共牌,桌心一行,正面朝上
static func pot_position(index: int, count: int) -> Vector3                 # 底池:主池与边池并排,在公共牌靠本机一侧
static func stack_position(angle: float, table_radius: float) -> Vector3    # 每人的筹码堆:桌沿内侧偏右手
static func bet_position(angle: float, table_radius: float) -> Vector3      # 本轮下注:更靠桌心
static func button_position(angle: float, table_radius: float) -> Vector3   # 庄家按钮:座位前偏左手
static func shown_card(angle: float, table_radius: float, i: int) -> Transform3D   # 亮出的手牌(2 张并排、朝上、朝向桌心外侧可读)
static func muck_position() -> Vector3                                     # 弃牌堆

class_name ChipStack3D extends Node3D
const DENOMINATIONS := [5000, 1000, 500, 100, 50, 10]   # 颜色:紫、金、黑、绿、红、象牙白
static func breakdown(amount: int) -> Array              # [[面额, 枚数], …] 贪心,从大到小;0 → []
func set_amount(amount: int) -> void                     # 每列最多 10 枚,最多显示 40 枚
var amount: int

class_name PokerChips extends Node3D   # 管理每人的筹码堆、本轮下注、桌心底池;动画方法都是协程
signal sfx(name: String)
func _init(p_world: TableWorld)
func sync(players: Array, pots: Array) -> void          # 按公共视图瞬时摆好(中途加入与对账用);players 同公共视图 players
func bet(pid: int, bet: int, stack: int) -> void        # 筹码从筹码堆滑到下注位
func collect(pots: Array, refund: Dictionary) -> void   # 先把退回的部分滑回去,再把下注收进底池
func award(index: int, shares: Dictionary, stacks: Dictionary) -> void   # 底池滑向赢家,赢家筹码堆更新
func rebuy(pid: int, stack: int) -> void                # 新的一摞落到座位前
func remove_seat(pid: int) -> void
func clear() -> void
func stack_anchor(pid: int) -> Vector3                  # 2D 标签挂点(WorldLabels)
func bet_anchor(pid: int) -> Vector3
func pot_anchor(index: int) -> Vector3

class_name PokerCards extends Node3D   # 管理德州的牌:各人手牌(举在酒客的 Fan 上)、公共牌、弃牌、亮牌
signal sfx(name: String)
func _init(p_world: TableWorld)
func deal_hole(order: Array, my_pid: int, my_cards: Array) -> void   # 每人两张,自己的正面朝镜头
func deal_board(cards: Array, first_index: int) -> void              # 飞到 board_slot 后翻面
func fold(pid: int) -> void                                          # 手牌推到弃牌堆
func reveal(pid: int, cards: Array) -> void                          # 从 Fan 移到 shown_card 位置,正面朝上
func highlight(cards: Array) -> void                                 # 赢牌的 5 张发光(公共牌与亮出的牌里找)
func sweep() -> void                                                 # 全部收走
func sync(players: Array, board: Array, my_pid: int, my_hole: Array) -> void   # 瞬时摆好
func clear() -> void

class_name DealerButton3D extends Node3D
func move_to(target: Vector3, duration: float) -> Tween
```

- `TableWorld` 的越肩、观战、等待厅、特写机位都随 `table_radius`/`seat_radius` 推远(骗子酒馆的数值保持不变,用桌子半径为 0.95 时结果与现在一致来保证)。
- 德州的所有 3D 节点都挂在 `TableWorld` 下,由界面层创建与释放(`PokerChips.new(world)` 等);骗子酒馆不受影响。

### 2.2 测试清单

- [ ] `test_poker_faces.gd`:无头模式 build 后 52 张都有纹理;`CardFaces.texture(德州牌)` 返回 PokerFaces 的纹理;`CardFaces.texture(Card.QUEEN)` 不变;并发两次 build 不重复生成;clear 后回到占位。
- [ ] `test_chip_stack.gd`:breakdown(0) 为空;breakdown(10) = [[10,1]];breakdown(1990) = [[1000,1],[500,1],[100,4],[50,1],[10,4]];breakdown(37000) 的面额 × 枚数之和 = 37000;set_amount 显示的枚数 ≤ 40。
- [ ] `test_poker_layout.gd`:8 个座位的筹码堆、下注位、按钮、亮牌位都在桌面内(到桌心距离 < table_radius − 0.05);相邻座位的筹码堆间距 > 4 × 筹码半径;公共牌 5 个槽位互不重叠、都在 0.6 米半径内;底池位置不压公共牌;table_radius = 0.95 与 1.45 都成立。
- [ ] `test_poker_world.gd`(无头):用假的公共视图(8 人、5 张公共牌、两个底池)调用 `PokerChips.sync` / `PokerCards.sync`,节点数符合预期;再 sync 一份人数变少的视图,多余的节点被收走;`clear` 后没有残留。
- [ ] `test_table_world.gd`:`configure_table(1.45)` 后座位离桌心 = 1.75,越肩机位在座位之后;`configure_table(0.95)` 后各机位与改动前完全一致。

### 2.3 截图验收

- [ ] `tools/poker_showcase.gd`:8 位酒客(用 `TableWorld.arrange`)、每人筹码与下注、桌心 5 张公共牌与两个底池、庄家按钮、两个人亮出手牌、自己举着两张手牌。
- [ ] `$GODOT --path . -s tools/shot.gd -- --out=<目录> --views=poker_seat,poker_overview,poker_lobby --poker-showcase`,逐张 Read 检查:
  公共牌与亮出的牌点数花色一眼可认;筹码颜色可分辨;没有穿模(筹码/牌/酒客爪子);吊灯罩不挡画面;8 人都在画面里。不满意就调 `PokerLayout` 常量与机位,重拍。
- [ ] 提交 `feat: 德州 3D 资产(四色牌面、筹码、庄家按钮、公共牌位)与放大的牌桌机位`。

---

## 任务 3:玩法接入(协议、发现、等待厅、主菜单)

**Files:**
- Modify: `src/net/protocol.gd`、`lobby_model.gd`、`room_list.gd`、`network_manager.gd`(只动房间/握手/发现部分)、`src/ui/main_menu/main_menu.gd`、`src/ui/lobby/lobby.gd`、`src/ui/settings.gd`
- Test: 新增 `tests/test_rpc_order.gd`、`test_lobby_mode.gd`;更新 `test_protocol.gd`、`test_room_list.gd`、`test_lobby_model.gd`、`test_main_menu_rooms.gd`、`test_discovery_broadcast.gd`、`test_pacing.gd`(用 `GameMode.max_players(GameMode.LIARS)` 代替 `Protocol.MAX_PLAYERS` 的骗子酒馆专属用法)
- 不碰说明书相关文件(归任务 5;说明书里骗子酒馆的「2–4 人」由任务 5 改为取 `GameMode.max_players(GameMode.LIARS)`)

### 3.1 要点(规格 §3)

- `Protocol.VERSION = 4`;`MAX_PLAYERS = 8`(注释说明是所有玩法的绝对上限);新增德州错误码与中文提示:
  `invalid_action`「现在不能这么做」、`invalid_amount`「下注金额不对」、`no_hand`「这一手还没开始」、`session_over`「牌局已经散了」、`cannot_rebuy`「还有筹码,不能再领」、`not_seated`「你不在牌桌上」。
- `LobbyModel.check_join(version, in_game, capacity, allow_in_game)`:版本 → 对局中(`allow_in_game` 为假才拒绝)→ 人数 ≥ capacity 拒绝。
- `RoomList.decode`:`mode` 可缺省(按 LIARS)、非 String 丢包、未知玩法 compatible 为假;`playing` 可缺省(false)、非 bool 丢包;人数校验用 `Protocol.MAX_PLAYERS`。
- `NetworkManager`:`host_game(..., mode)`;`set_game_mode(mode)` 的完整实现(房主、等待厅、合法玩法、人数不超上限 → 改玩法、全员准备重置、广播);发现报文 `mode`/`playing`/`max`/`open`;等待厅 meta 带 `mode`,客户端 `_apply_lobby` 校验后写入 `game_mode`;
  `rpc_join_accepted(info)`(in_game 为真时不发 `joined_lobby`);`rpc_game_started(seats, info)`(写入 `game_mode`);加入校验按玩法上限与是否允许中途加入。
- 主菜单:「开一桌」区上方加玩法三段切换(骗子酒馆 / 德州·长牌 / 德州·短牌),记在 `Settings.KEY_LAST_MODE`(读到非法值回退默认);默认房名按玩法;房间行加玩法标签,加入按钮按规格 §3.2 的四种文案。1280×720 下面板仍放得下(必要时压缩行距)。
- 等待厅:标题下「玩法 · 人数范围」;房主的三段切换(人数超上限的选项禁用并在悬停提示里说明);状态行「x/上限 人」;玩法变化时调用 `app.apply_table_mode(Net.game_mode)` 并重排酒客。
- `test_rpc_order.gd`:取 `network_manager.gd` 脚本的 `get_rpc_config()` 的方法名按字符串排序,断言前 8 个依次为
  `rpc_game_events, rpc_game_started, rpc_intent_challenge, rpc_intent_play, rpc_intent_rejected, rpc_join_accepted, rpc_join_denied, rpc_join_request`。

### 3.2 测试清单

- [ ] RoomList:带 mode 的报文往返;缺 mode → LIARS;mode 为数字 → 丢包;未知 mode → compatible 假;players 5 / max 8 合法,max 9 丢包;`playing` 类型不对丢包。
- [ ] LobbyModel:德州对局中可加入、骗子酒馆对局中拒绝;满 8 人拒绝;骗子酒馆满 4 人拒绝。
- [ ] 离线 NetworkManager(`test_lobby_mode.gd`):host_game 指定玩法 → 发现报文 mode/max 正确;set_game_mode 在 5 人时切到骗子酒馆返回 false;切换后准备状态重置;对局中 set_game_mode 返回 false;客户端收到 meta 后 game_mode 更新、非法 mode 被忽略。
- [ ] 主菜单 `clamp_seats` 上限变 8;玩法标签与按钮文案的纯函数(把文案逻辑写成 static 便于测试)。
- [ ] 全部测试通过 → 提交 `feat: 开房选择玩法(协议 v4、发现报文与等待厅带玩法、德州最多 8 人可中途加入)`。

---

## 任务 4:视线与探头逻辑抽取(`SeatGaze`)

**Files:**
- Create: `src/ui/table/seat_gaze.gd`
- Modify: `src/ui/table/table_screen.gd`
- Test: 新增 `tests/test_seat_gaze.gd`;`test_cursor_look.gd`、`test_patron_neck.gd`、`test_table_screen.gd` 保持通过(TableScreen 保留同名 static 包装,或把测试改为调用 SeatGaze,二选一)

把 `TableScreen` 里自己转头/探头/同步视线与他人视线跟随(`_follow_cursor_with_head`、`_held_neck_direction`、`next_neck_input`、`_follow_remote_gazes`、`_on_gaze`、`_seat_of`、`cursor_look_target` 及相关常量与 `_gaze`/`_neck_input` 状态)搬进 `SeatGaze`(Node)。两种牌桌共用:

```gdscript
class_name SeatGaze extends Node
func _init(p_app: Node, p_world: TableWorld, p_my_pid: int)
var gaze_free := func() -> bool: return true    # 镜头在常驻机位且没在结算(由牌桌注入)
var at_seat := func() -> bool: return true      # 在自己座位的越肩机位
var excluded := func(pid: int) -> bool: return false   # 出局/观战/不在座位上的人不跟随
var rest_point := func() -> Vector3: return Vector3.ZERO   # 他人停发视线后看回哪里
func receive(pid: int, point: Vector3, neck: Vector3, active: bool) -> void
func forget(pid: int) -> void
func neck_input() -> Vector3
static func cursor_look_target(origin: Vector3, direction: Vector3, table_radius := SeatLayout.TABLE_RADIUS) -> Vector3
static func next_neck_input(current: Vector3, held: Vector3, delta: float) -> Vector3
```

- 行为与现在完全一致(骗子酒馆截图、联机冒烟不变);`cursor_look_target` 的桌面半径改为参数(德州传 `world.table_radius`)。
- [ ] 先写 `test_seat_gaze.gd`(cursor_look_target 在两种半径下命中/不命中桌面、next_neck_input 上限与停留、excluded 的人不跟随)→ 抽取 → 全部测试通过 → `tools/lan_smoke.sh` 通过 → 提交 `refactor: 视线与探头逻辑抽成 SeatGaze,两种牌桌共用`。

---

## 任务 5:德州说明书

**Files:**
- Modify: `src/ui/rulebook/rulebook_content.gd`、`rulebook_blocks.gd`、`rulebook.gd`、`src/ui/main.gd`(`show_rules` 传玩法)
- Test: 更新 `tests/test_rulebook_content.gd`、`test_rulebook.gd`

- 骗子酒馆那本里的人数改为取 `GameMode.max_players(GameMode.LIARS)`(任务 3 把 `Protocol.MAX_PLAYERS` 改成了所有玩法的绝对上限 8),`test_rulebook_content.gd` 同步。
- 说明书分两本:`RulebookContent.sections(book: String)`,book 为 `GameMode.LIARS`(现有章节原样)或 `"poker"`(德州章节)。`Rulebook.new(in_game, book)`;顶部两个页签切换,默认打开当前房间玩法那本(在房间里用 `Net.game_mode`,主菜单用 `Settings.KEY_LAST_MODE`)。
- 德州章节(数字全部取自 `PokerRules` 与 `Protocol.TURN_TIMEOUT`):
  1. 怎么玩:现金局、2–8 人、入座 2000、盲注 10/20、输光再领或观战、中途入座、房主散局与盈亏结算。
  2. 牌型:新块类型 `hands`——从大到小列出牌型,每行一组示例牌(用 `CardFaces.texture(德州牌)` 画小牌面)、名称与一句说明;长牌、短牌各一列,短牌里与长牌顺序不同的两处(同花/葫芦、三条/顺子)高亮,注明 A-2-3-4-5 与 A-6-7-8-9。
  3. 下注:弃牌/过牌/跟注/加注/全下、最小加注、不完整加注、边池、未跟注退回、超时规则。
  4. 操作:F 弃牌、C/空格 过牌跟注、R/回车 下注加注、↑↓ 调金额、1–5 预设、WASD 探头、F1、Esc。
- [ ] 测试:poker 书的章节都存在且块类型合法;`hands` 块长短牌顺序与 `PokerRules.category_order` 一致;文案里出现 2000、10/20、2–8;骗子酒馆那本内容不变 → 提交 `feat: 说明书加德州扑克一本(牌型对照、下注、操作)`。

---

## 任务 6:网络会话(骗子酒馆会话抽取 + 德州会话)

**Files:**
- Create: `src/net/liars_session.gd`、`src/net/poker_session.gd`、`src/net/poker_views.gd`
- Modify: `src/net/network_manager.gd`(开局、意图、计时、断线、中途加入、散局、视线转发范围)、`tests/test_net_turn_timer.gd`(只改内部字段访问)
- Test: 新增 `tests/test_poker_views.gd`、`test_poker_session.gd`、`test_net_poker.gd`

### 6.1 要点(规格 §4.2–4.3、§7)

- `LiarsSession` 原样搬走现有 `GameState` / `Views` / `Pacing` 的用法,骗子酒馆行为零变化(现有测试与 `tools/lan_smoke.sh` 证明)。
- `PokerSession(short_deck)`:持有 `PokerTable`、名字表;`start` 让所有人 `seat` 后开第一手;`handle_intent` 校验 intent(kind 是 String 且在 `PokerRules.BET_ACTIONS + SEAT_ACTIONS` 里,amount 是 int)后分派到 `act`/`rebuy`/`spectate`;
  `add_player(pid, name)` 记名字后调用 `add_player`,并给 `player_joined` 补上 name;`session_over` 的 results 补上 name(离开的人也要有名字)。
- `PokerViews.public_state(table, names, mode, turn_time_left)` / `private_state(table, pid)`:按规格 §4.6,只用 `PokerTable` 的只读访问;公共视图永远不含没亮的手牌。
- `NetworkManager`:
  - `_session` 取代 `_gs`;开局按 `game_mode` 选会话;`rpc_game_started(seats, {"mode", "late": false})`;开场预算 `Pacing.INTRO`。
  - `_after_action(events)`:按会话的 `estimate` / `turn_timer_after` 排回合计时,再按 `next_hand_ready()` 排一手间隔计时器(`_hand_timer`,`pending + PokerPacing.HAND_GAP`),然后发事件、同步视图。
  - 中途加入(对局中且 `supports_late_join()`):`rpc_join_accepted({"in_game": true})` → `rpc_game_started(当前座位, {"mode", "late": true})` → `add_player` 的事件走 `_after_action`。把这段逻辑写成不依赖 RPC 发送者的私有方法,便于离线测试。
  - `rpc_poker_intent(action, amount)`:校验类型、长度与发送者是本场成员,再交给 `_handle_intent`。`submit_poker_action` / `request_rebuy` / `request_spectate` / `end_poker_session` 填上实现。
  - 断线:`on_disconnect` 的事件走 `_after_action`;视线转发与校验改为本场全体成员(`_match_names`)。
  - `request_rematch_lobby` 用 `is_over()`;`leave()` 停掉 `_hand_timer`。

### 6.2 测试清单

- [ ] `test_poker_views.gd`:公共视图不含任何未亮手牌(遍历整个字典查找手牌值);亮牌后 `shown` 出现;`actions` 与 `legal_actions(current)` 一致;私有视图有自己的两张手牌,公共牌 ≥ 3 时有 best。
- [ ] `test_poker_session.gd`:非法 intent(kind 非 String、未知动作、amount 为字符串)→ `invalid_action`;rebuy/spectate 分派;`player_joined` 与 `session_over` 带名字。
- [ ] `test_net_poker.gd`(离线 NetworkManager,同 `test_net_turn_timer.gd` 的做法):德州开局首批事件含 hand_started/blind/hole_cards/turn,回合计时 = INTRO + 本批预算 + 30;一手结束后 `_hand_timer` 按 pending + HAND_GAP 排期,到点开下一手;超时代打(过牌或弃牌);中途加入走完整流程且下一手发牌;断线的人被弃牌、行动继续;散局:手牌中 → 这手结束后 is_over,空闲 → 立即 is_over;`request_rematch_lobby` 回等待厅。
- [ ] `test_net_turn_timer.gd` 只改内部字段访问后全部通过;`tools/lan_smoke.sh`(骗子酒馆)通过。
- [ ] 提交 `feat: 网络层按玩法分会话(骗子酒馆会话抽取、德州会话与视图、一手间隔排期、中途入座、散局)`。

---

## 任务 7:德州牌桌界面(`src/ui/poker/`)

**Files:**
- Create: `src/ui/poker/poker_screen.gd`(控制器)、`poker_director.gd`(演出)、`poker_hud.gd`、`bet_controls.gd`、`poker_nameplate.gd`、`poker_settlement.gd`
- Modify: `src/ui/main.gd`(`_show_table` 按 `Net.game_mode` 选 `PokerScreen`;退出时 `PokerFaces.clear()`)、`src/ui/sfx.gd`(`chips`、`chips_push`、`fold`)
- Test: `tests/test_bet_controls.gd`、`test_poker_settlement.gd`、`test_poker_screen.gd`、`test_poker_director_pacing.gd`

### 7.1 要点(规格 §5–6)

- `PokerScreen` 结构同 `TableScreen`:订阅 `Net` 信号 → 事件排队交给导演逐个演出(演出期间锁输入)→ 演出结束按最新公共/私有视图对账(`PokerChips.sync` / `PokerCards.sync`)。进入时 `app.apply_table_mode(Net.game_mode)`、`await PokerFaces.build(app)` 后 `Card3D.refresh_materials()`,开场运镜不超过 `Pacing.INTRO`。
  中途加入(`late`)时先按视图把进行中的这一手摆好,镜头用观战机位;在下一个 `hand_started` 按 `seats` 重排座位(`world.arrange(..., with_revolvers = false)`)并回到自己座位。
- 导演按规格 §4.5 的事件逐个演出,每段时长常量写在导演/资产类里,`test_poker_director_pacing.gd` 读取这些常量断言不超过 `PokerPacing` 预算(含 8 人发牌、多个底池等最坏情况,加 4 帧余量,同 `test_pacing.gd`)。
- 视线与探头用任务 4 的 `SeatGaze`(`cursor_look_target` 传 `world.table_radius`)。
- `BetControls` 的金额逻辑写成 static 纯函数:`presets(pub, my_pid) -> Dictionary`(最小/½ 池/¾ 池/1 池/全下 → 加注到多少)、`clamp_amount(x, actions) -> int`、`raise_label(actions, amount) -> String`。
- 给 bot 用的接口(任务 8):`is_my_turn() -> bool`、`legal() -> Dictionary`、`submit(action: String, amount := 0) -> void`(与按钮同一路径)、`my_status() -> String`。
- 输光确认框、观战与等待状态、房主「散局」按钮与确认、Esc 离开确认、`session_over` 后显示 `PokerSettlement`(房主「回到等待厅」调用 `Net.request_rematch_lobby()`)。

### 7.2 测试清单

- [ ] `test_bet_controls.gd`:底池 60 + 桌上下注 40、当前最高 20、要跟 20、最小加到 40、最多 1000 时,½ 池 = 80、1 池 = 140、全下 = 1000;结果按 10 取整并夹到范围;本轮无人下注时 ½ 池 = pot × 0.5;不能加注时预设全部禁用;按钮文案「过牌」「跟注 20」「下注 40」「加注到 80」「全下 1000」。
- [ ] `test_poker_settlement.gd`:按 net 降序排名;盈亏文字带正负号与千分位;离开的人标「已离开」。
- [ ] `test_poker_screen.gd`(不入树,只测状态逻辑):演出中不是自己回合;观战/输光/等待时下注控件不出现而「领取 2000 上桌」或等待提示出现;提交后等待回执期间不能重复提交;被拒绝后恢复。
- [ ] `test_poker_director_pacing.gd`:见上。
- [ ] 提交 `feat: 德州牌桌界面(下注控件、铭牌、演出导演、输光再领与观战、散局结算)`。

---

## 任务 8:bot、联机冒烟与文档

**Files:**
- Modify: `src/ui/debug_flags.gd`、`README.md`
- Create: `tools/poker_smoke.sh`
- Test: `tests/test_debug_flags.gd`(解析新开关)

- 新开关:`--mode=liars|holdem|short_deck`(房主玩法,默认 liars)、`--hands=N`(房主打满 N 手后自动散局)、`--late-join=秒`(推迟这么久才发起加入,用来测中途入座)、`--bot-spectate`(bot 输光后选观战,默认再领)。
- bot 德州决策(走 `PokerScreen` 的接口,思考时间同 `BOT_THINK`):能过牌时 70% 过牌、25% 加注(在 [最小, 最小 × 3] 里取)、5% 全下;要跟注时 55% 跟注、25% 弃牌、15% 加注、5% 全下;不合法的就退回跟注/过牌。输光时按开关再领或观战。
- 日志标记:每手开始打印 `POKER_HAND <手数>`;`session_over` 时打印 `SESSION_OVER hands=<N> me=<盈亏>`;中途加入者第一次被发到牌时打印 `POKER_LATE_DEALT`。`--quit-after-match` 对德州是在结算后退出。
- `tools/poker_smoke.sh`(参考 `tools/lan_smoke.sh`,`MODE` 环境变量默认 holdem):房主 `--autohost=3 --mode=$MODE --hands=8`、局域网发现 bot、直连 bot、`--late-join=10` 的直连 bot。
  通过条件:四个进程都以 0 退出、都有 `SESSION_OVER`、中途加入者有 `POKER_LATE_DEALT`、日志里没有 `SCRIPT ERROR`。`MODE=holdem` 与 `MODE=short_deck` 各跑一次。
- README:玩法选择、德州规则摘要(长短牌差异、盲注、再领、观战、中途入座、散局)、德州操作键、冒烟命令。
- [ ] 测试 → 实现 → 两种玩法冒烟都通过、骗子酒馆冒烟仍通过 → 提交 `feat: 德州 bot 与联机冒烟脚本;README 加玩法说明`。

---

## 任务 9:联调与截图验收

- [ ] 合并全部任务后跑全部单测、`tools/lan_smoke.sh`、`MODE=holdem tools/poker_smoke.sh`、`MODE=short_deck tools/poker_smoke.sh`。
- [ ] 窗口模式:1 个有窗口的房主(`--shots=<目录>`)+ 7 个无头 bot 跑 8 人德州,检查座位、铭牌、公共牌清晰度、筹码、下注控件、输光弹窗、观战机位、结算面板在 1280×720 下不重叠、不出画;再跑 2 人单挑与骗子酒馆各一局确认没被影响。
- [ ] 发现的问题逐个修(先写能复现的测试),每次修完重跑相关测试与冒烟。

## 任务 10:审查

- [ ] 多维度审查(规则正确性、网络与不可信输入、状态机卡死与守恒、界面与演出预算、与骗子酒馆的回归、代码质量),每条发现做对抗验证,确认的问题修掉并补测试。
