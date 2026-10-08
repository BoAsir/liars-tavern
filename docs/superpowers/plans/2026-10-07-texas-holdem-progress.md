# 德州扑克玩法 进度记录

> 换机器接着做时先读这份。规格:[2026-10-07-texas-holdem-design.md](../specs/2026-10-07-texas-holdem-design.md);
> 实施计划:[2026-10-07-texas-holdem.md](2026-10-07-texas-holdem.md)。每完成一步就更新本文并提交。

## 分支

- 主开发分支:`feature/texas-holdem`(基于 `feature/liars-tavern-mvp`;本机在 `.claude/worktrees/texas-holdem` 里开发)。
- 第一批子任务分支(各自从 `cc18285` 分出,已完成、已审查修复,待合并):
  `th/engine`(任务 1 规则引擎)、`th/faces`(任务 2a 牌面)、`th/world`(任务 2b 3D 资产与机位)、
  `th/modes`(任务 3 玩法接入)、`th/gaze`(任务 4 视线抽取,已合并一次,之后又有修复)、`th/rulebook`(任务 5 说明书)。
- 相关的其他分支:`feature/liars-tavern-mvp`(上游主线;`eadc745` 左轮改 5 膛 + 协议 v4 + 越肩镜头拉远 + 版本 0.6.0)、
  `feature/model-detail`(另一会话的 3D 模型重做,见规格 §9 的接口约定)。

## 状态(2026-10-08 14:55,进行中:任务 6/7a 审查修复 + 7b 开发,分支 th/net-fix、th/hud-fix、th/screen,均从 ad70b2a 分出)

| 任务 | 状态 | 说明 |
|---|---|---|
| 0 地基 | ✅ 已在 feature/texas-holdem | GameMode / PokerCard / PokerRules / PokerPacing、桌子按玩法放大的接口、Net 接口桩 |
| 1 规则引擎 | ✅ th/engine 完成、审查通过、修完 | PokerDeck / HandEvaluator / PotBuilder / PokerTable / PokerHand / BettingRound;457 测试;随机模拟 8 种子×150 手,另有 `tests/soak_poker_simulation.gd` 浸泡(只在点名时跑) |
| 2a 牌面 | ✅ th/faces 完成、审查通过、修完 | PokerFaces(256×372、分批生成、built 信号源)、CardFaces 分流、`tools/poker_faces_sheet.gd` 验收图 |
| 2b 3D 资产 | ✅ th/world 完成、审查后修完 | PokerLayout / ChipStack3D / PokerChips / PokerCards / BoardRack / DealerButton3D;TableWorld 德州机位、圆弧换座、remove_patron、poker_root + clear_poker;灯光补丁;`tools/poker_showcase.gd`、shot.gd 德州机位;无头布局测试 |
| 3 玩法接入 | ✅ th/modes 完成、审查通过、修完 | 协议 v4(合并时改 v5)、兼容旧版的发现报文(cap/seated/mode/playing)、check_join 新顺序、rpc_join_accepted 带 mode、主菜单 ModePicker、房间行 RoomRow、等待厅、Settings.KEY_LAST_MODE、RPC 编号冻结测试 |
| 4 视线抽取 | ✅ th/gaze 完成 | SeatGaze;已合并到 feature/texas-holdem(cc18285),之后又有一个修复提交(探头不往后探)待合并 |
| 5 说明书 | ✅ th/rulebook 完成、审查通过、修完 | 两本书页签、hands 牌型表、按书记页、README 写明开房后不能改玩法 |
| 合并第一批 | ✅ 102f73a | 6 个分支 + 上游 eadc745/51a8431 都已合进 feature/texas-holdem;协议 v5;德州越肩机位用 TableWorld.POKER_THIRD_PERSON;710 测试全过 |
| 6 网络会话 | ✅ 已写完并合并(c478450),**还没做独立审查** | GameSession 接口 + LiarsSession(骗子酒馆零变化)+ PokerSession + PokerViews;NetworkManager 游戏部分改走会话(规格 §4.2 计时、`_hand_timer`、`rpc_poker_intent` 校验、中途加入顺序、视线成员 = 等待厅名单);`PokerPacing.BUST_DECISION`;Net 多了 `request_sit_in()`;lan_smoke 通过。接手时先按计划任务 6 的审查要点做一次审查 |
| 7a HUD 控件 | 🟡 基本写完并合并(c478450),**展台截图未完成、未审查** | 已有:BetControls(预设/夹取/文案/禁用原因/快捷键/F 免费过牌保护)、PokerHud、CardStrip、PokerNameplate、PokerPrompts(输光/观战/等待/离座的非模态提示)、ShowdownStrip、PokerSettlement、ChipText、音效 chips/chips_push/fold,各有单测。暂停时的中间状态:`tools/poker_showcase.gd` 与 `tools/shot.gd` 正在接入这些控件(提交 2bacc5b 标 wip),接手时先跑 `tools/shot.gd --poker-showcase` 看能否截图,再按规格 §6.1 的布局预算核对、修正,然后做独立审查 |
| 7b 控制器与演出 | ⏳ 进行中 | 分支 th/screen(从 ad70b2a 分出);按计划任务 7 的控制器部分做:poker_screen.gd、poker_director.gd、main.gd 接线(选屏、拆台调用、PokerFaces 清理)、SeatGaze 接法、迟到者第一帧、机位规则、bot 入口;test_poker_screen、test_poker_director_pacing |
| 8 bot 与冒烟 | ⬜ 未开始 | |
| 9 联调与截图验收 | ⬜ 未开始 | |
| 10 审查 | ⬜ 未开始 | |

## 合并清单(第一批 → feature/texas-holdem)—— 已完成,留作记录

1. 依次合并 `th/gaze`、`th/rulebook`、`th/faces`、`th/modes`、`th/engine`、`th/world`,每次跑全量测试
   (`$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`)。
   预演过:分支之间只有 `src/ui/settings.gd` 的一行注释冲突(取 th/modes 的)。
2. 再合并 `feature/liars-tavern-mvp`(eadc745、51a8431)。预演过的冲突与解法:
   - `src/net/protocol.gd`:`VERSION := 5`,注释写明 v4 = 左轮 5 膛、v5 = 玩法选择 + 德州;`test_rpc_order` / 发现报文测试里的版本号跟着改。
   - `src/world/table_world.gd`:上游把越肩镜头改成 BACK 2.45 / HEIGHT 2.05 / SIDE 0.6;本分支是「座位外 BEHIND 0.85」的公式。
     取 `THIRD_PERSON_BEHIND = 2.45 − 1.25 = 1.2`、HEIGHT 2.05、SIDE 0.6,保留德州公式(规格 §5.5)。
   - `src/ui/table/table_screen.gd`:保留 SeatGaze 抽取;上游在 `next_neck_input` 里改用 `Patron.clamp_neck`(探头平移不抬高、不往后探),
     th/gaze 的最后一个提交已经做了同样的事,核对 `seat_gaze.gd` 即可。
   - `tests/test_cursor_look.gd`:`SEAT_CAMERA` 改用 TableWorld 常量计算(上游写法)。
3. 合并后:全量测试;8 人铭牌布局测试在更远的越肩镜头下是否仍过(不过就调规格 §5.5 的德州机位);`tools/lan_smoke.sh`;
   `tools/shot.gd --poker-showcase` 重拍一次看镜头。
4. 发布时版本 0.7.0(0.6.0 已被上游用掉)。

## 接手须知(当前)

1. 先做任务 6 与 7a 的独立审查(对照规格 §4.2–4.6、§6.1–6.5 与计划里的测试清单),修掉问题。
2. 7a 的展台截图收尾:`$GODOT --path . -s tools/shot.gd -- --out=<目录> --views=poker_seat,poker_overview --poker-showcase`(窗口模式),按规格 §6.1 预算核对。
3. 开 7b(th/screen),然后任务 8(bot、`tools/poker_smoke.sh`、README)、任务 9 联调截图、任务 10 审查。
4. 每一步:全量测试 + `tools/lan_smoke.sh` 回归,提交并推送,更新本文。

## 第二批怎么开(原记录)

- 任务 6(网络会话)与任务 7a(HUD 控件)并行,各开一个 worktree(`git worktree add ../th-net -b th/net`、`../th-hud -b th/hud`);
  7a 合并后再开任务 7b(`th/screen`)。每个任务:实现 → 独立审查 → 修复 → 合并。提示词要点都在计划的任务 6 / 任务 7 小节。
- 规格后来补充、归第二批的条目已写在计划的任务 6 / 7 小节末尾(BUST_DECISION、hand_gap、sit_in、拆台调用方、迟到者第一帧、机位规则)。
- 第一批交付说明里留给第二批的要点:
  - 任务 6:意图分派(5 个下注动作走 act,rebuy/spectate/sit_in 各自方法);turn_action 只对下注动作为真;`hand_gap()` 在有 busted 且未离开者时取 BUST_DECISION;
    `player_joined` / `session_over` 补名字;公共视图 `seats = seats_with_patrons()`,players 按 seats 顺序、新人排最后;Net 还缺 `request_sit_in()`。
  - 任务 7:离座提示(「你已离座 · 回到牌桌」→ sit_in);BetControls 处理 `min_raise_to == max_raise_to`(只能全下);「等待下一手」只看 status waiting;
    SeatGaze 接法(at_seat = 在座位表里且不是观战;excluded = 观战/已离开;rest_point = 桌心;被排除时收回脖子);
    说明书的牌面刷新钩子 `book_shown` / `refresh_card_faces` 由 main 接 PokerFaces 的 built 信号。

## 环境与命令

- Godot 4.7.1:`export GODOT=/Applications/Godot.app/Contents/MacOS/Godot`;新目录先 `$GODOT --headless --path . --import`。
- 截图工具已改为强制绘制(窗口被遮挡也不会卡住):`tools/shot.gd`、`DebugFlags` 的 `--shots`。
- 另一会话在重做 3D 模型(`feature/model-detail`),`tavern.gd` 的 `set_table_radius` / `set_table_decor_visible` 在本分支只是接口桩,合并时以对方为准(规格 §9)。
