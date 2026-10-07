# 德州扑克玩法 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 开房选玩法;新增德州扑克:
- 长牌 / 短牌,2–8 人无限注现金局,2000 筹码,盲注 10/20;
- 输光再领或观战,中途入座,房主散局结算;
- 在放大的 3D 酒馆牌桌上进行,公共信息另有清晰的 2D 大图。

**Architecture:**
- 规则全部在 `src/core/poker/` 的纯逻辑里,房主端状态机是 `PokerTable`。
- 网络层把玩法逻辑抽成会话对象(`LiarsSession` / `PokerSession`),`NetworkManager` 只管连接、等待厅、RPC 与计时。
- 客户端德州牌桌(`src/ui/poker/`)只渲染公共 / 私有视图,事件只驱动动画。
- 3D 新内容全部放在 `src/world/poker/` 的新文件里。

**Tech Stack:** Godot 4.7.1 / GDScript,GUT 9.7 单元测试,ENet 局域网;全部美术与音效程序化生成。

**规格:** [docs/superpowers/specs/2026-10-07-texas-holdem-design.md](../specs/2026-10-07-texas-holdem-design.md)。规格是唯一的事实来源,下面「实现规格 §x」指要完整实现那一节。计划与规格冲突时以规格为准,并在交付说明里写出冲突。

---

## 0. 通用约定(每个任务都适用)

- **工作目录**:每个任务在自己的 git worktree 里做,完成后提交到该 worktree 的分支,由协调者合并。不要改主仓库目录 `/Users/murphy/Desktop/dev/LiarsTavern` 本身的文件,其他会话正在那里工作;也不要改别的任务的 worktree。
- **Godot**:`export GODOT=/Applications/Godot.app/Contents/MacOS/Godot`。新 worktree 先导入一次,注册 class_name:`$GODOT --headless --path . --import`。每次新增带 `class_name` 的脚本后要再导入一次。
- **跑测试**:
  - 全部:`$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`,约 45 秒。
  - 只跑几个文件:`-gtest=res://tests/test_a.gd,res://tests/test_b.gd`。
  - 输出里看 `Passing Tests` / `Failing Tests` 和 `---- All tests passed! ----`。
  - 基线是 325 个测试全过。交付时全部测试必须通过。
- **TDD**:先写失败的测试并看它失败,再写最少的实现让它通过,然后整理。纯逻辑必须有单测,包括规则、视图、预算、布局数学、下注预设、文案。3D 和界面以截图验收为主,但其中的纯函数仍要单测。
- **代码风格**:照着周围代码写:
  - 中文注释,说明「为什么」;`snake_case`;类型标注;用 `const` 常量,不写魔法数。
  - 单个函数 < 50 行,单个文件 < 400 行(最多 800)。
  - 网络来的数据一律先校验类型与范围。
  - 不改 `project.godot`(规格 §11)。
- **GUT 注意**:引擎错误会让测试判失败。离线测试不要对未知 peer 调 `rpc_id`,用规格 §4.2 的 `_send_to`。被测脚本若引用 `Net`、`Sfx`、`Discovery` 等自动加载,只能在完整项目里测;`tools/*.gd`(以 `-s` 启动)不能引用它们。
- **提交**:中文约定式提交,如 `feat: 德州规则引擎(牌型评估、边池、下注状态机)`。可以多次提交。
- **RPC**:不得新增方法名排在 `rpc_join_request` 之前的 RPC(规格 §3.3)。
- **模型重做分支**(规格 §9):不要改 `patron_3d.gd`、`patron_parts.gd`、`revolver_3d.gd`、`mesh_kit.gd`、`materials.gd`。`tavern.gd` 只保留已有的接口桩,确有必要时可以在桩里加最少的改动并写清注释。
- **截图**(需要窗口,不能 `--headless`):`$GODOT --path . -s tools/shot.gd -- --out=<目录> --views=<机位>`。生成的 PNG 用 Read 工具查看。截图目录放在系统临时目录或 scratchpad 里,不要放进仓库。
- **交付说明**:完成时列出提交 SHA、全部测试结果、与规格的偏差及原因、留给后续任务的问题。

## 1. 文件归属与执行顺序

| 任务 | 新增 | 修改 |
|---|---|---|
| 0 地基(已完成) | `game_mode.gd`、`poker_card.gd`、`poker_rules.gd`、`poker_pacing.gd` 与测试 | `seat_layout.gd`、`tavern.gd`(桩)、`table_world.gd`(`configure_table`)、`card_table.gd`(`set_stand_visible`)、`main.gd`(`apply_table_mode`)、`network_manager.gd`(桩) |
| 1 规则引擎 | `src/core/poker/{poker_deck,hand_evaluator,pot_builder,poker_table}.gd`(可拆 `betting_round.gd`)、测试 | — |
| 2 3D 资产与机位 | `src/world/poker/*.gd`、`tools/poker_showcase.gd`、测试 | `table_world.gd`、`card_faces.gd`、`tools/shot.gd`、`tavern.gd`(仅灯光补丁,见任务 2) |
| 3 玩法接入 | 测试 | `protocol.gd`、`lobby_model.gd`、`room_list.gd`、`network_manager.gd`(房间/握手/发现)、`main_menu.gd`、`lobby.gd`、`settings.gd` |
| 4 视线抽取 | `src/ui/table/seat_gaze.gd`、测试 | `table_screen.gd` |
| 5 说明书 | 测试 | `src/ui/rulebook/*.gd`、`main.gd`(`show_rules`) |
| 6 网络会话 | `src/net/{liars_session,poker_session,poker_views}.gd`、测试 | `network_manager.gd`(游戏部分) |
| 7 德州牌桌界面 | `src/ui/poker/*.gd`、测试 | `main.gd`(选屏、退出清理)、`sfx.gd`、`tools/shot.gd`(HUD 展台) |
| 8 bot 与冒烟 | `tools/poker_smoke.sh`、测试 | `debug_flags.gd`、`README.md` |

顺序:任务 1–5 并行 → 合并 → 任务 6、7 并行 → 合并 → 任务 8 → 联调(任务 9)→ 审查(任务 10)。

---

## 任务 1:德州规则引擎

**实现规格** §2(全部规则)、§4.4、§4.5(引擎产生的事件)、§7(守恒)。**Files:** 见上表。

接口(规格 §4.4 之外的补充):

```gdscript
class_name PokerDeck
static func build(short_deck: bool) -> Array[int]                                  # 按点数、花色升序
static func shuffled(short_deck: bool, rng: RandomNumberGenerator) -> Array[int]   # Fisher-Yates

class_name HandEvaluator
static func evaluate(cards: Array, short_deck: bool) -> Dictionary
#   5–7 张 → {"category", "score", "cards": [最好的 5 张,展示顺序], "name", "detail"}
#   score = strength << 20 | 5 个 4 位比较点数;同一玩法内大者赢、相等平局
#   展示顺序:成组的在前,同组与踢脚按点数降序;顺子从大到小(A-2-3-4-5 为 5 4 3 2 A)
#   name 为牌型名(A 高同花顺为「皇家同花顺」);detail:「高牌 · A」「一对 · K」「两对 · A 和 8」「三条 · 9」
#        「顺子 · 到 J」「同花 · A 高」「葫芦 · Q 带 7」「四条 · 9」「同花顺 · 到 9」「皇家同花顺」(点数用 J/Q/K/A,不出现花色符号)
static func compare(a: Dictionary, b: Dictionary) -> int                           # 1 / 0 / -1

class_name PotBuilder
static func build(committed: Dictionary, folded: Dictionary, seat_order: Array) -> Array  # 规格 §2.5,主池在前
static func uncalled(bets: Dictionary) -> Dictionary                               # 规格 §2.4 的退回:{"pid", "amount"} 或 {}
static func split(amount: int, winners: Array, unit: int) -> Dictionary            # winners 已按按钮后顺时针排好
```

PokerTable 的只读访问:`seat_order()`、`player(pid)`(`{"stack","bet","committed","status","left","buyins","net","shown"}` 的拷贝)、`hole_cards(pid)`、`board()`、`pots()`、`hand_number()`、`street()`、`phase()`、`current_pid()`、`current_bet()`、`button()`、`small_blind()`、`big_blind()`、`is_ending()`、`best_hand(pid)`、`seats_with_patrons()`(规格 §4.6 的 seats)、`chips_in_play()`、`total_bought_in()`、`departed_stacks()`。测试钩子 `button_pid`、`rigged` 见规格 §4.4。

测试(先写;牌用 `PokerCard.make(rank, suit)`):
- [ ] `test_poker_deck.gd`:长牌 52 张各不相同、最小 2;短牌 36 张各不相同、最小 6;同种子结果相同,不同种子不同。
- [ ] `test_hand_evaluator.gd`:
  - 皇家同花顺,胜四条 A。
  - A-2-3-4-5 同花顺「到 5」,输给 2–6 同花顺。
  - A-2-3-4-5 顺子输给 2–6 顺子,胜三条。
  - 四条带大踢脚。KKK22 胜 QQQAA。同花比到第 5 张。AA88K 胜 AA88Q。
  - 7♥7♦ + 7♣7♠K♥K♦2♣ 为四条 7 带 K。
  - 三个对子取最大两对加踢脚。两个三条成葫芦。6 张同花取最大 5 张。
  - 公共牌成顺子时平局。每种 detail 文案。
  - 短牌:A-6-7-8-9 为顺子「到 9」,输给 6–10。同花胜葫芦,顺子仍胜三条,A♥6♥7♥8♥9♥ 为同花顺。
  - 同一手 7 张在长短牌下葫芦与同花的胜负相反。
- [ ] `test_pot_builder.gd`:
  - 三人各 100 → 300 [A,B,C]。
  - A 50 全下、B/C 200 → 150 [A,B,C] + 300 [B,C]。
  - A 100 已弃牌、B/C 300 → 700 [B,C]。
  - A 50、B 120 全下,C/D 300 → 200 / 210 / 360。
  - 无资格层并入下层(X 下 500 后离开、Y 全下 200、Z 全下 300 的例子)。
  - uncalled 含已弃牌者:X 300、Y 100、Z 900 → Z 退 600。
  - split:30 分两人 → 20/10;70 分三人 → 30/20/20。
- [ ] `test_poker_table_blinds.gd`:
  - 三人与单挑的按钮/盲注/首个行动者/dealt 顺序。
  - 3→2 人时按钮给上一手大盲。
  - 大盲只剩 10 的三种情形(规格 §8)。
  - 新人坐在按钮与小盲之间。按钮离开、按钮输光后按钮的位置。
- [ ] `test_poker_table_betting.gd`:
  - 错误码:`not_your_turn` / `no_hand` / `invalid_action` / `invalid_amount`。
  - 翻牌前最小加注 60 → 100 → 340。
  - 翻牌后全下 10 → 最少加注到 30,已过牌的人只能跟或弃。
  - 不完整加注不重开,累计 ≥ 完整增量后重开。
  - 对手都全下时 can_raise 假;全下只在 can_allin 时合法。
  - 大盲选择权。
  - 一轮结束 → `bets_collected` → `street` → 首个行动者。
  - 全员弃牌给大盲:退回并 uncontested,且任何事件里都没有他的牌与牌型名(公共牌 ≥ 3 时也一样)。
  - timeout:过牌或弃牌。
- [ ] `test_poker_table_showdown.gd`(用 `rigged`):
  - 河牌摊牌:reveal(showdown)、赢家拿池。
  - 平局零头给按钮后第一位赢家。
  - 翻牌前全下:reveal(allin) 后连发三个 street,再 pot_won。
  - 三人不同额度全下:主池与边池由不同的人赢,pot_won 从最后一个边池到主池。
  - 两手之间的状态字段(规格 §4.4「两手之间」)。
- [ ] `test_poker_table_seats.gd`:
  - 输光进入 `hand_over.busted`,status `busted`。
  - rebuy 只对 busted/spectating 有效(手牌中全下者不能领)。spectate 只对 busted 有效。
  - 手牌中 add_player 下一手发牌。OVER 时 add_player 返回 []。
  - 离开的三种情形(规格 §2.7),含唯一最高下注者离开而跟注者都全下。
  - request_end:空闲 / 手牌中。之后的意图回 `session_over`。
  - results 按 net 降序,和为 0(含离开者)。
- [ ] `test_poker_simulation.gd`:规格 §8 的随机模拟(固定 8 个种子 × 150 手,< 10 秒)。

步骤:
- [ ] Deck → Evaluator → PotBuilder:各自先写测试、看到失败、实现、通过、提交。
- [ ] PokerTable:按 blinds → betting → showdown → seats 的顺序,每个测试文件先写、后实现、通过后提交。
- [ ] 最后加随机模拟,修掉它找出的问题,全部测试通过后提交。

---

## 任务 2:3D 资产与机位

**实现规格** §5(全部)、§6.1 里的 2D 小牌纹理要求(mipmap 过滤由任务 7 的 `card_strip.gd` 用,本任务保证纹理带 mipmap)、§8 的离线展台与性能检查、§9 灯光补丁。

接口:

```gdscript
class_name PokerFaces       # 规格 §5.2
signal built                # 静态类没有实例信号:用 static var 持有一个 RefCounted 信号源,或提供 static func await_built(host)
static func build(host: Node) -> void      # 分批生成(每帧 ≤ 13 个 SubViewport),并发调用时等第一次完成
static func is_built() -> bool
static func texture(card: int) -> Texture2D
static func clear() -> void

class_name PokerLayout      # 纯数学,本机座位角度 = 0;常量写在这里,截图后调
const BOARD_SCALE := 1.8
const BOARD_TILT_DEG := 35.0
const SHOWN_SCALE := 1.4
static func board_slot(index: int) -> Transform3D
static func pot_position(index: int, count: int) -> Vector3
static func stack_position(angle: float, table_radius: float) -> Vector3
static func bet_position(angle: float, table_radius: float) -> Vector3
static func button_position(angle: float, table_radius: float) -> Vector3
static func shown_card(angle: float, table_radius: float, i: int) -> Transform3D   # 本机视角正立
static func muck_position() -> Vector3
static func poker_fan_offset() -> Vector3     # 规格 §5.3 的牌扇位置(座位坐标)

class_name ChipStack3D extends Node3D          # MultiMeshInstance3D,cast_shadow OFF
const DENOMINATIONS := [5000, 1000, 500, 100, 50, 10]
static func breakdown(amount: int) -> Array   # [[面额, 枚数]],从大到小
func set_amount(amount: int) -> void

class_name PokerChips extends Node3D           # 动画方法都是协程;时长常量公开,供任务 7 的预算测试读取
signal sfx(name: String)
func _init(p_world: TableWorld)
func sync(players: Array, pots: Array) -> void
func bet(pid: int, bet: int, stack: int) -> void
func collect(pots: Array, refund: Dictionary) -> void
func award(index: int, shares: Dictionary, stacks: Dictionary) -> void
func rebuy(pid: int, stack: int) -> void
func remove_seat(pid: int) -> void
func clear() -> void
func stack_anchor(pid: int) -> Vector3
func bet_anchor(pid: int) -> Vector3
func pot_anchor(index: int) -> Vector3

class_name PokerCards extends Node3D           # 同上
signal sfx(name: String)
func _init(p_world: TableWorld)
func deal_hole(order: Array, my_pid: int, my_cards: Array) -> void
func deal_board(cards: Array, first_index: int) -> void
func fold(pid: int) -> void
func reveal(pid: int, cards: Array) -> void
func highlight(cards: Array) -> void
func sweep() -> void
func sync(seats: Array, players: Array, board: Array, my_pid: int, my_hole: Array) -> void
func clear() -> void

class_name DealerButton3D extends Node3D
func move_to(target: Vector3, duration: float) -> Tween
```

`TableWorld` 改动:
- 机位按规格 §5.5 的公式与数值;半径 0.95 时与现在完全一致。
- 酒客沿圆弧换座(规格 §5.1)。
- 新增 `remove_patron(pid)`、`poker_overview_view()`、`poker_lobby_view()`,或者让现有函数按 `table_radius` 分支。
- 新增 `nameplate_anchor(pid) -> Vector3`(座位原点 + (0, 1.62, 0))。

`CardFaces.texture(kind)`:`PokerCard.is_card(kind)` 时转给 `PokerFaces`。

灯光(规格 §9):`tavern.gd` 的接口桩里,`set_table_radius` 顺带放宽吊灯聚光,`set_table_decor_visible(false)` 时留一点桌沿暖光。改动保持最小,写清「合并时以模型重做分支为准」。

测试:
- [ ] `test_poker_faces.gd`:
  - 无头模式 build 后 52 张都有纹理。
  - `CardFaces.texture(德州牌)` 走 PokerFaces;骗子酒馆牌不变,`CardFaces.is_built()` 含义不变。
  - 并发两次 build 不重复生成;clear 后回到占位。
- [ ] `test_chip_stack.gd`:
  - breakdown(0) = [],breakdown(1990) = [[1000,1],[500,1],[100,4],[50,1],[10,4]]。
  - 大额总和对得上。
  - 显示枚数 ≤ 40。
- [ ] `test_poker_layout.gd`(半径 0.95 与 1.45 都测):
  - 8 座位的筹码堆、下注位、按钮、亮牌位都在桌面内,且离桌心 < r − 0.05。
  - 相邻座位筹码堆间距 > 4 × 筹码半径。
  - 公共牌槽互不重叠且在 0.6 米内;底池不压公共牌。
  - 亮牌与公共牌的牌顶朝 −Z。
- [ ] `test_poker_world.gd`(无头):
  - 用假视图 sync,节点数符合预期;人数变少后多余节点被收走;clear 无残留。
  - `remove_patron` 后酒客消失,座位角度保留。
- [ ] `test_table_world.gd`:
  - `configure_table(1.45)` 后座位离桌心 1.75,越肩机位 = 规格 §5.5 的数值。
  - `configure_table(0.95)` 后各机位与改动前完全一致。
- [ ] 无头布局测试(规格 §8):8 个铭牌挂点在越肩与德州观战机位下投影到 1280×720,都在安全边内且两两不重叠;镜头到每个头的连线不穿过吊灯罩。

截图验收:
- [ ] 写 `tools/poker_showcase.gd`:8 位酒客、5 张公共牌、2 人亮牌、筹码、下注、2 个底池、按钮、自己的两张手牌。
- [ ] `tools/shot.gd` 加 `--poker-showcase` 与机位 `poker_seat` / `poker_overview` / `poker_lobby`,机位取自 `TableWorld` 的函数。
- [ ] 拍 1280×720 与 1280×960 两套,逐张 Read 检查:
  - 公共牌与亮牌认得出;筹码颜色可分辨;
  - 没有穿模,吊灯罩不挡,8 人都在画面里;
  - 桌沿与酒客脸不黑。
- [ ] 不满意就调 `PokerLayout` 常量、机位与灯光补丁,重拍。
- [ ] 性能(规格 §8):展台与骗子酒馆 4 人展台各打印帧耗时与 draw calls,写进交付说明。
- [ ] 提交。

---

## 任务 3:玩法接入(协议、发现、握手、主菜单、等待厅)

**实现规格** §3(全部)、§4.2 中「可离线测试的结构」里的 `_handle_join_request` 与 `_send_to`、§4.3 的 `host_game(..., mode)` 与 `max_players()`。

不做:
- 中途加入的会话部分(`add_player`、`rpc_game_started` late 分支的会话调用)归任务 6。本任务只做准入判断、`rpc_join_accepted(info)` 的收发与客户端「加入中」保持,接口按规格写好。
- 说明书文件归任务 5。

测试:
- [ ] `test_rpc_order.gd`:规格 §3.3 的编号冻结(排序前 8 个方法名;两个握手方法的参数个数与类型)。
- [ ] `test_room_list.gd`:
  - v4 德州报文能通过一份 v3 校验规则(上限 4)的副本;v4 解析读到 cap 8 / seated n。
  - 没有 cap 时按 max 与 mode 校验(骗子酒馆 max 5 丢包)。
  - mode 缺省 / 非 String / 未知;playing 缺省 / 非 bool。
  - 坏样例改为 `[2, Protocol.MAX_PLAYERS + 1]`;`[8, 8]` 合法。
- [ ] `test_lobby_model.gd`:
  - 新签名 `check_join(version, in_game, mode, accepting_late)`。
  - 判定顺序:版本先于已开局与已满。
  - 德州对局中可加入;散局中拒绝并给出文案。
  - 8 人满;骗子酒馆 4 人满。
- [ ] `test_lobby_mode.gd`(离线 NetworkManager):
  - `host_game` 带玩法 → 发现报文的 mode/cap/seated/max/players/open/playing 正确。
  - 客户端收到 meta 后 `game_mode` 更新;非法 mode 被忽略。
  - `_handle_join_request` 走完准入(不连网也不报引擎错误)。
  - `leave()` 后 `game_mode` 复位。
- [ ] `test_main_menu_rooms.gd`:座位文字 / 圆点、玩法标签与按钮文案的纯函数(写成 static)。
- [ ] `test_pacing.gd` 与 `lobby.gd` 状态行:不再用 `Protocol.MAX_PLAYERS` 指骗子酒馆上限。
- [ ] 主菜单与等待厅:用 `tools/shot.gd` 的 menu 机位或真机截图,确认 1280×720 下主菜单不滚动、8 人等待厅不溢出。
- [ ] 全部测试与 `tools/lan_smoke.sh` 通过 → 提交。

---

## 任务 4:视线与探头逻辑抽取(`SeatGaze`)

**实现规格** §4.1 中的 `seat_gaze.gd`。

把 `TableScreen` 的以下内容搬进 `SeatGaze`(Node):
- 常量 `CURSOR_LOOK_FAR`、`NECK_SPEED`、`NECK_KEYS`;
- 状态 `_gaze`、`_neck_input`;
- 方法 `_gaze_free`、`_follow_cursor_with_head`、`_held_neck_direction`、`next_neck_input`、`_follow_remote_gazes`、`_on_gaze`、`_seat_of`、`cursor_look_target`;
- `_process` 里的调用,以及 `Net.gaze_updated` 的连接。

```gdscript
class_name SeatGaze extends Node
func _init(p_app: Node, p_world: TableWorld, p_my_pid: int)
var gaze_free := func() -> bool: return true          # 镜头在常驻机位且没在结算
var at_seat := func() -> bool: return true            # 在自己座位的越肩机位
var excluded := func(_pid: int) -> bool: return false  # 出局/观战/没有酒客的人不跟随
var rest_point := func() -> Vector3: return Vector3.ZERO  # 他人停发视线后看回哪里
func receive(pid: int, point: Vector3, neck: Vector3, active: bool) -> void
func forget(pid: int) -> void                          # 不在树内时也安全
func neck_input() -> Vector3
static func cursor_look_target(origin: Vector3, direction: Vector3, table_radius := SeatLayout.TABLE_RADIUS) -> Vector3
static func next_neck_input(current: Vector3, held: Vector3, delta: float) -> Vector3
```

- 行为与现在完全一致。
- `test_cursor_look.gd` 改为调用 `SeatGaze`(或 `TableScreen` 保留同名 static 包装,二选一)。
- [ ] 先写 `test_seat_gaze.gd`:两种桌面半径下光标命中 / 不命中桌面;探头上限与停留;excluded 的人不跟随;不在树内时 forget 安全。
- [ ] 抽取 → 全部测试通过 → `tools/lan_smoke.sh` 通过(`GAZE peers=2 necks=2`)→ 提交。

---

## 任务 5:德州说明书

**实现规格** §6.6。

- 依赖:任务 2 的 `PokerFaces` 在本任务的 worktree 里还不存在。示例小牌用 `CardFaces.texture(德州牌)`,没生成时是占位色块。
- 「等生成完再画」用 `CardFaces.texture` 加一个可选的完成回调接口,接口在任务 7 合并时接上,本任务先把块画出来、留好刷新入口。
- [ ] 测试:
  - poker 书各章节存在,块类型合法。
  - `hands` 块的长短牌名次与 `PokerRules.category_order` 一致,只有一处差异被高亮。
  - 文案里出现 2000、10/20、2–8、30 秒。
  - 骗子酒馆那本内容不变,人数来自 `GameMode.max_players(GameMode.LIARS)`。
  - `Rulebook.new(in_match, book)` 切书后重建导航、当前页复位。
  - `main` 按书记页。
- [ ] 截图看两本书的样子(主菜单 F1),再提交。

---

## 任务 6:网络会话

**实现规格** §4.2(全部,含计时规则伪代码、离线可测结构、中途加入顺序、视线成员)、§4.3、§4.6、§3.3 的 `rpc_poker_intent` 与握手的会话部分、§7。

- `LiarsSession` 原样搬走现有的 `GameState` / `Views` / `Pacing` 用法,骗子酒馆行为零变化。
- `PokerSession` 持有 `PokerTable` 与名字表;`PokerViews` 只用 `PokerTable` 的只读访问。
- 测试:
  - [ ] `test_poker_views.gd`:
    - 按字段路径检查不泄露(规格 §8),含「没摊牌就赢」。
    - `actions` 与 `legal_actions` 一致。
    - 两手之间的视图字段;seats 的含义。
    - 没被发牌者的私有视图。
  - [ ] `test_poker_session.gd`:
    - 非法 intent → 对应错误码;跨玩法 kind → 拒绝。
    - `turn_action` 标记;on_disconnect 未知 pid → []。
    - `player_joined` 与 `session_over` 带名字;viewers 的范围。
  - [ ] `test_net_poker.gd`:规格 §8「离线 NetworkManager」那一条的全部子项。
  - [ ] `test_net_turn_timer.gd`:改读 `last_public` 与新 `_handle_intent` 签名,期望值不变。
  - [ ] `tools/lan_smoke.sh` 原样通过。
- [ ] 提交。

---

## 任务 7:德州牌桌界面

**实现规格** §5.3(牌扇与朝向的界面侧部分)、§5.5 的机位使用、§5.6、§6.1–6.5、§6.7、§7(PokerScreen 的引导顺序)、§8.1 中 `PokerDirector.event_started` 与 `PokerScreen` 给 bot 的入口。

- 文件:`poker_screen.gd`(控制器)、`poker_director.gd`(演出)、`poker_hud.gd`、`bet_controls.gd`、`poker_nameplate.gd`、`poker_settlement.gd`、`card_strip.gd`(2D 小牌条)。
- `main.gd`:`_show_table` 按 `Net.game_mode` 选 `PokerScreen`;`_exit_tree` 里 `PokerFaces.clear()`。
- `sfx.gd`:加 `chips` / `chips_push` / `fold`。
- 依赖:任务 6 的 `Net` 接口签名已经作为桩存在。视图字段以规格 §4.6 为准,可以用假视图字典开发与测试。
- 给 bot 的入口:`is_my_turn()`、`legal()`、`submit(action, amount := 0)`(与按钮同路径)、`my_status()`、`choose_rebuy()`、`choose_spectate()`。
- 测试:
  - [ ] `test_bet_controls.gd`:
    - 底池 60 + 桌上下注 40、当前最高 20、要跟 20、最少加到 40、最多 1000 时:½ 池 = 80,1 池 = 140,全下 = 1000。
    - 取整与夹取;无人下注时的公式。
    - can_raise / can_allin 对控件的禁用。
    - 文案「过牌」「跟注 20」「下注 40」「加注到 80」「全下 1,000」。
    - F 键在能免费过牌时不弃牌。
  - [ ] `test_poker_settlement.gd`:排名、正负号与千分位、已离开、超过 8 行能滚动。
  - [ ] `test_poker_screen.gd`(不入树):
    - 演出中不是自己回合;
    - 观战 / 输光 / 等待时底部区域的内容;
    - 提交后等回执期间不能重复提交,被拒绝后恢复;
    - 不在 seats 里时用观战机位。
  - [ ] `test_poker_director_pacing.gd`:导演与资产各段时长常量之和(最坏情况:8 人发牌、多个底池、全下)加 4 帧余量 ≤ `PokerPacing` 预算。
- 截图:`tools/shot.gd --poker-showcase` 加上用假视图喂的 HUD、下注控件、铭牌、摊牌条,拍 1280×720 与 4:3,检查规格 §6.1 的布局预算。
- [ ] 提交。

---

## 任务 8:bot、联机冒烟与文档

**实现规格** §8 的联机冒烟、§8.1 调试开关、§11 的 README 要求。

- [ ] `test_debug_flags.gd`:新开关的解析;`--mode` 非法值的处理。
- [ ] `debug_flags.gd`:
  - 德州 bot 与 `--hands`;日志标记。
  - 导演信号挂法;德州截图标记。
  - 迟到者不依赖 `joined_lobby`。
- [ ] `tools/poker_smoke.sh`:按规格 §8 的编排与通过条件。
- [ ] 跑通 `MODE=holdem` 与 `MODE=short_deck` 两次,`tools/lan_smoke.sh` 仍通过。
- [ ] README 更新 → 提交。

## 任务 9:联调与截图验收

- [ ] 合并后跑全部单测、骗子酒馆冒烟、两种德州冒烟。
- [ ] 真机截图:规格 §8「截图验收」的 8 人局;另跑 2 人单挑与骗子酒馆各一局,确认骗子酒馆没被影响。
- [ ] 发现的问题逐个修:先写能复现的测试,修完重跑相关测试与冒烟。

## 任务 10:审查

- [ ] 多维度审查:规则正确性、网络与不可信输入、状态机卡死与守恒、界面与演出预算、对骗子酒馆的回归、代码质量。
- [ ] 每条发现做对抗验证;确认的问题修掉并补测试。
