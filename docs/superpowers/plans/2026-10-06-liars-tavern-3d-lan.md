# 骗子酒馆:局域网联机 + 3D 牌桌实现计划

> 取代 `m2-net` / `m3-shell` / `m4-table` 三份子计划中与表现层冲突的部分(2D 牌桌)。
> 网络层沿用 M2 计划的接口与信号命名,并按规格 4.x 节补强。规格见
> `docs/superpowers/specs/2026-08-14-liars-tavern-design.md`(2026-10-06 修订版)。

**约定**:命令、测试方式、提交格式同总纲 `2026-08-14-liars-tavern.md`。纯逻辑一律 TDD(先写 GUT 测试看它失败,再实现)。

## M2 网络层

| # | 交付物 | 测试 |
|---|---|---|
| 2.1 | `net/protocol.gd`:常量、错误文案、`parse_address("ip[:port]")` | `test_protocol.gd` |
| 2.2 | `net/views.gd`:公共/私有视图(私有视图带小局号) | `test_views.gd` |
| 2.3 | `net/lobby_model.gd`:加入校验(版本/满员/已开局)、准备、可开局、视图 | `test_lobby_model.gd` |
| 2.4 | `net/room_list.gd`:发现报文编解码、按房间 id 去重、回环降级、过期移除 | `test_room_list.gd` |
| 2.5 | `net/lan.gd`:私网 IPv4 过滤、`/24` 定向广播地址推导 | `test_lan.gd` |
| 2.6 | `net/pacing.gd`:事件批演出时长估算 | `test_pacing.gd` |
| 2.7 | `net/discovery.gd` + `net/network_manager.gd` + autoload 注册 | headless 启动无报错 |

Net 相对 M2 计划的补强:端口回退、加入超时、`kicked` 定向消息、整局开始时快照昵称、回合计时加演出宽限、`match_names`。

## M3 酒馆与外壳

| # | 交付物 |
|---|---|
| 3.1 | `ui/theme.gd`(配色/字体令牌、按钮/面板样式)、`ui/sfx.gd`(程序化音效 autoload) |
| 3.2 | `world/materials.gd` + `world/shaders/*.gdshader`(木纹、桌布、灰泥、火焰、暗角后处理) |
| 3.3 | `world/tavern.gd`:房间、圆桌、吊灯体积光、烛台、壁炉、吧台、浮尘;座位锚点 API;`world/camera_rig.gd` |
| 3.4 | `world/seat_layout.gd`(TDD:`test_seat_layout.gd`) |
| 3.5 | `world/patron_3d.gd`:酒客模型与待机/前倾/拍桌/中弹倒下动画 |
| 3.6 | `ui/main.gd` + `main.tscn`:常驻酒馆 + 屏幕切换;`main_menu`、`lobby`(落座表现) |

验收:窗口运行可见环绕酒馆的主菜单;同机两实例互相发现并进入同一等待厅。

## M4 3D 牌桌

| # | 交付物 |
|---|---|
| 4.1 | `world/card_faces.gd`(离屏绘制牌面,headless 退化纯色)、`world/card_3d.gd`(翻面/悬停/选中/弧线飞行) |
| 4.2 | `world/revolver_3d.gd`(建模 + 举枪/转轮/扳机/后坐)、`world/fx.gd`(枪口焰/硝烟) |
| 4.3 | `ui/table/table_hud.gd`(目标牌、横幅、环形倒计时、按钮、日志)、`ui/table/settlement.gd` |
| 4.4 | `ui/table/table_screen.gd`(信号→事件队列→导演;手牌拾取与快捷键) |
| 4.5 | `ui/table/table_director.gd`(各事件的演出序列) |

## M5 验证与收尾

| # | 交付物 |
|---|---|
| 5.1 | `ui/debug_flags.gd`:`--bot` / `--autohost` / `--autojoin=ip` / `--name=` / `--shots` 命令行开关 |
| 5.2 | `tools/lan_smoke.sh`:无头 1 房主 + 2 bot 客户端跑完整局,断言全部实例 match_over |
| 5.3 | 截图检查关键画面(菜单/等待厅/牌桌/翻牌/开枪) |
| 5.4 | README、代码审查、最终回归 |
