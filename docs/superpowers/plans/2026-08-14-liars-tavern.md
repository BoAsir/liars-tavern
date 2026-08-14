# 骗子酒馆实现计划(总纲)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现局域网 2–4 人《骗子酒馆》桌面游戏(骗子牌模式),Godot 4 + GDScript,房主权威架构。

**Architecture:** 纯逻辑核心(`src/core/`,可 GUT 单测)与表现层完全分离;房主进程为唯一逻辑权威(listen-server),客户端只发意图、收视图;UDP 广播做房间发现,ENet 做游戏通信;UI 全部用 GDScript 代码构建(仅一个入口 .tscn)。

**Tech Stack:** Godot 4.7(brew cask 已装于 `/Applications/Godot.app`)、GDScript、GUT 9.x(单元测试)、ENetMultiplayerPeer、PacketPeerUDP。

**Spec:** `docs/superpowers/specs/2026-08-14-liars-tavern-design.md`(规则、协议、容错的唯一权威来源)

---

## 全局约定(所有子计划通用)

- 仓库根目录:`/Users/murphy/Desktop/dev/LiarsTavern`,所有命令默认在此执行。
- Godot 命令行:
  ```bash
  export GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
  ```
- 跑全部单元测试(后文简称"跑测试"):
  ```bash
  cd /Users/murphy/Desktop/dev/LiarsTavern
  $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
  ```
  成功标准:输出末尾各 script 全 pass、退出码 0。失败会打印具体断言。
- GDScript 文件一律使用 **Tab 缩进**(Godot 默认)。计划中代码块如显示为空格,写入文件时保持结构即可(同文件内一致即不报错)。
- 提交信息遵循 `<type>: <描述>` 中文约定式提交。

## 子计划索引(按顺序执行)

| # | 文件 | 交付物 | 完成标准 |
|---|------|--------|----------|
| M1a | `2026-08-14-liars-tavern-m1a-foundation.md` | 项目脚手架、GUT、牌/牌堆/左轮/规则判定 | 单测全绿 |
| M1b | `2026-08-14-liars-tavern-m1b-gamestate.md` | GameState 状态机(整局流程+断线淘汰) | 单测全绿 |
| M2 | `2026-08-14-liars-tavern-m2-net.md` | 协议常量、视图构建、ENet 网络层、UDP 房间发现 | 单测全绿+headless 冒烟 |
| M3 | `2026-08-14-liars-tavern-m3-shell.md` | 入口场景、主菜单、等待厅 | 双实例手动联通 |
| M4 | `2026-08-14-liars-tavern-m4-table.md` | 牌桌、演出、音效、结算、容错、README、验收清单 | 双实例完整对局 |

## 最终文件结构(全部计划完成后)

```text
LiarsTavern/
├── project.godot                  # M1a 创建;M2 加 autoload;M3 加 main_scene;M4 加 Sfx
├── .gitignore
├── addons/gut/                    # M1a 引入(vendored,随仓库提交)
├── src/
│   ├── core/
│   │   ├── card.gd                # 牌面常量与匹配(M1a)
│   │   ├── deck.gd                # 牌堆构建/洗牌/发牌/抽目标(M1a)
│   │   ├── revolver.gd            # 六膛左轮模型(M1a)
│   │   ├── rules.gd               # 出牌合法性/诚实判定(M1a)
│   │   └── game_state.gd          # 状态机:整局生命周期(M1b)
│   ├── net/
│   │   ├── protocol.gd            # 端口/版本/上限/错误码常量(M2)
│   │   ├── views.gd               # 公共/私有视图构建(M2)
│   │   ├── network_manager.gd     # autoload "Net":建房/加入/RPC(M2)
│   │   └── discovery.gd           # autoload "Discovery":UDP 广播发现(M2)
│   └── ui/
│       ├── main.tscn / main.gd    # 入口与屏幕切换(M3)
│       ├── main_menu/main_menu.gd # 主菜单(M3)
│       ├── lobby/lobby.gd         # 等待厅(M3)
│       ├── table/table.gd         # 牌桌+演出(M4)
│       ├── table/settlement.gd    # 结算遮罩(M4)
│       └── sfx.gd                 # autoload "Sfx":程序化音效(M4)
├── tests/                         # GUT 单测(core+views 全覆盖)
└── README.md                      # M4
```

## 关键设计决定(执行者必读)

1. **秘密信息只在房主内存里**:`GameState.hands` / `Revolver.bullet_chamber` 永不进入公共视图。`Views.public_state` 只含手牌张数、已扣扳机次数。
2. **事件驱动演出**:每次动作,房主端 `GameState` 返回 `events` 数组(`played`/`turn`/`reveal`/`gunshot`/`eliminated`/`round_started`/`match_over`),原样广播;牌桌 UI 按队列逐个播放动画。
3. **强制验证的无人开枪分支**:场上仅剩一人有手牌时其出牌被系统验证(challenger 为 null);若为真话则无人开枪、直接开新小局——这是规格 2.5 + 2.3 的组合边界,已在 M1b 单测覆盖。
4. **同机多开限制**:UDP 发现端口同机只能绑一个实例,同一台机器开多实例测试时用手输 `127.0.0.1` 直连(README 已注明);跨机器用自动发现。
5. **状态同步用全量推送**:每次动作后房主广播完整 `state_public` 并定向发 `state_private`,不做增量。
