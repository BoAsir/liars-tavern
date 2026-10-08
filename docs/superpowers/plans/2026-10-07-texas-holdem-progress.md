# 德州扑克玩法 进度记录

> 换机器接着做时先读这份。规格:[2026-10-07-texas-holdem-design.md](../specs/2026-10-07-texas-holdem-design.md);
> 实施计划:[2026-10-07-texas-holdem.md](2026-10-07-texas-holdem.md)。每完成一步就更新本文并提交。

## 分支

- 主开发分支:`feature/texas-holdem`(本机在 `.claude/worktrees/texas-holdem` 里开发)。**2026-10-08 起用户要求直接在主分支开发**:不再为审查/修复开子分支,每步直接提交到 `feature/texas-holdem`,然后 `git push origin feature/texas-holdem feature/texas-holdem:main`,`origin/main` 始终等于最新进度(本机主目录的 `main` 检出被别的会话占用,所以不能在本 worktree 直接 checkout main;换机器后可以直接在 main 上做)。
- 第一批子任务分支(各自从 `cc18285` 分出,已完成、已审查修复,待合并):
  `th/engine`(任务 1 规则引擎)、`th/faces`(任务 2a 牌面)、`th/world`(任务 2b 3D 资产与机位)、
  `th/modes`(任务 3 玩法接入)、`th/gaze`(任务 4 视线抽取,已合并一次,之后又有修复)、`th/rulebook`(任务 5 说明书)。
- 相关的其他分支:`feature/liars-tavern-mvp`(上游主线;`eadc745` 左轮改 5 膛 + 协议 v4 + 越肩镜头拉远 + 版本 0.6.0)、
  `feature/model-detail`(另一会话的 3D 模型重做,见规格 §9 的接口约定)。

## 状态(2026-10-08 15:40,已暂停;任务 6/7a 审查修复与 7b 开发都已合并到 feature/texas-holdem 与 main)

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
| 6 网络会话 | ✅ 已写完、已独立审查修复(th/net-fix,已合并) | GameSession 接口 + LiarsSession(骗子酒馆零变化)+ PokerSession + PokerViews;NetworkManager 游戏部分改走会话(规格 §4.2 计时、`_hand_timer`、`rpc_poker_intent` 校验、中途加入顺序、视线成员 = 等待厅名单);`PokerPacing.BUST_DECISION`;`request_sit_in()`。审查修复见下节「任务 6 审查修复」 |
| 7a HUD 控件 | ✅ 已写完、已审查修复(th/hud-fix),展台截图收尾完成 | BetControls(预设/夹取/文案/禁用原因/快捷键/F 免费过牌保护;新回合按 hand/street/current_pid 或合法动作变化判定,牌桌要对每个公共视图都调 `update`)、PokerHud、CardStrip、PokerNameplate(两行各自按文字宽度给足)、PokerPrompts、ShowdownStrip、PokerSettlement、ChipText、音效 chips/chips_push/fold,各有单测;主题给 HSlider 铜色轨道。`tools/poker_showcase.gd` + `tools/shot.gd` 已能摆出全部 8 种底部状态(bet/wait/showdown/bust/spectate/waiting/away/settlement)与观战机位,1280×720 与 1280×960 都核对过规格 §6.1 预算、铭牌不相撞 |
| 7b 控制器与演出 | ✅ 已写完并合并(th/screen),**独立审查没做完** | PokerScreen(445 行)+ PokerDirector(446 行)+ PokerScreenState(337 行);main.gd 选屏与拆台接线、说明书牌面刷新、SeatGaze 接法、迟到者第一帧、机位规则、底部区域状态、结算;bot/快捷键入口与按钮同路径(`is_my_turn / legal / submit / my_status / choose_rebuy / choose_spectate / choose_sit_in`)。测试:test_poker_screen_state、test_poker_screen、test_poker_director_pacing(实际时长 ≤ PokerPacing 预算)、test_poker_screen_flow(无头整局:发牌→行动→全下亮牌→输光→观战→再领→中途加入/离开→散局→结算→拆台,91 断言)。暂停时审查阶段刚开始,审查员只来得及加流程测试;接手时按计划任务 7 的审查要点(规格 §4.3–4.6、§5.5、§6.2–6.5、§7)再过一遍 |
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

1. 当前合并后的状态:869 个测试全过,`tools/lan_smoke.sh` 通过;`origin/main` = `origin/feature/texas-holdem`。
2. 先补任务 7b 的独立审查(对照规格 §4.3–4.6、§5.5、§6.2–6.5、§7 与计划任务 7 的测试清单),修掉问题;顺手跑一次 `tools/shot.gd --poker-showcase` 看合并后镜头与 HUD 是否还对。
3. 然后任务 8:DebugFlags 加德州 bot(`--mode=holdem|short_deck`、`--hands=N`、日志标记 HAND_STARTED / DEALT / SESSION_OVER / net_sum),`tools/poker_smoke.sh`(1 房主 + 若干 bot 跑完 N 手、盈亏总和为 0、无脚本错误),README 写德州玩法;任务 9 联调与 8 人截图验收;任务 10 多视角审查。
4. 每一步:全量测试 + `tools/lan_smoke.sh` 回归,提交,`git push origin feature/texas-holdem feature/texas-holdem:main`,更新本文。
5. 已知债务:`network_manager.gd` 749 行(上限 800),任务 8 若再长就把视线转发或德州意图入口抽成 RefCounted;7a 展台截图(窗口模式;不写 `--hud` 时座位机位默认 bet、观战机位默认 spectate):
   `$GODOT --path . -s tools/shot.gd -- --out=<目录> --views=poker_seat,poker_seat,poker_seat,poker_seat,poker_seat,poker_seat,poker_seat,poker_seat,poker_overview --hud=bet,wait,showdown,bust,spectate,waiting,away,settlement,spectate --poker-showcase`;4:3 在 `-s` 前加引擎参数 `--resolution 1280x960`。
6. 旧的子任务分支 `th/*`(含 th/net-fix、th/hud-fix、th/screen)都已合并,只留作记录;worktree 可以 `git worktree remove` 清掉。

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
