# 第一 / 第三人称视角切换设计(2026-10-08 用户追加)

> 用户原话:「再加个可以切换第一/三视角的功能吧,有的时候经常牌被挡住」。
> 动森式大头之后,越肩镜头里自己的大头常挡住手牌和桌面。决定由协调方给出,本文记录决定与实现。

## 1. 决定

### 1.1 切换
- **V 键**在「越肩」(原来的第三人称)与「第一人称」之间切换。V 之前没人用(已用:1–5、Enter、C、空格、F、R、↑↓、WASD、F1、Esc,番茄与快捷语分支加 T / 右键 / Q)。
- 选择存进设置 `Settings.KEY_CAMERA_MODE`(`"third"` / `"first"`,同 `KEY_SPECIES` 的写法),默认越肩;下次进牌桌沿用。
- 切换时弹 toast:「第一人称视角」/「越肩视角」;镜头不在座位上(拍特写、观战)时后缀「(回到座位后生效)」。
- 牌桌提示行与两本说明书的「操作」页加「V 切换视角」;README 操作表加一行。
- 骗子酒馆与德州都用;只在自己坐着、活着、镜头在座位上时马上切过去。
- 出局观战、迟到者、观战者:常驻机位规则不变(`uses_overview` / 观战流程),按 V 只改设置,回到座位才看得到。

### 1.2 第一人称镜头
- 眼睛在自己的头上:头心(头枢轴上方 0.12 m,不含转头)+ `Patron.FP_EYE_OFFSET`(座位坐标,往上 0.07、往桌心 0.12),落在大头里面靠前的地方。
- 看向桌心再往对面挪 0.15 m、高出桌面 0.08 m(`TableWorld.FIRST_PERSON_TARGET`):对面的脸在画面上半,桌面、出牌区在中间。
- 朝向按「坐好、没探头」的静止眼睛定(`first_person_rest_view`),位置每帧跟着真实的眼睛走(`first_person_view`):
  WASD 探头、轮到自己时前倾、呼吸、被吓一跳都会平移镜头,但镜头**不跟转头**(光标看哪儿镜头不跟着转,不会和光标打架)。
  朝光标的那一点偏转由 `CameraRig` 原有的鼠标视差提供(±0.05 弧度)。
- 平滑:脖子本身是临界阻尼弹簧、前倾按插值,镜头到位后直接贴着眼睛走,不再叠一层平滑(叠了会拖影)。
- 视角 72°(越肩 66°);补光 0.4(越肩 0.9:补光跟着镜头,第一人称时离手里的牌只有半米)。

### 1.3 藏起自己的头
- 只在本机:头、眼、眉、耳、帽、脖子,以及挂在头上的表演件(汗珠、舌头)和之后挂上去的东西(番茄泥等)。
- 本来投影的件改 `SHADOWS_ONLY`:不渲染但照样投影,自己的影子还在桌上。
- 本来就不投影的件(眼睛、眉、汗珠……)挪到 `MeshKit.LAYER_LOCAL_HIDDEN`(编辑器第 20 层),游戏镜头的 `cull_mask` 不含这一层。
  (最初设成 `layers = 0`,Godot 会报 “indexing did not unpair geometries from light”,改成单独一层。)
- 藏着期间监听 `SceneTree.node_added`,头 / 脖子下新进树的几何体延后一帧处理(挂件常在 `add_child` 之后才设 `cast_shadow`)。
- 记下每件的原 `cast_shadow` 与 `layers`,恢复时原样放回(帽子被打飞挂到别处也一样)。
- 什么时候藏:`SeatCamera` 每帧判断——第一人称、坐在座位上(`enter` 之后 `leave` 之前)、镜头正在跟随自己的眼睛、且离眼睛不到 `HEAD_CLEAR`(0.45 m)、自己活着。
  其余一律露出:拍翻牌、开枪特写(包括自己开枪)、胜者环绕、观战、换屏都看得到自己的头。回座过渡刚开始镜头还远,头也照常显示。
- 酒客被重建(复活、换形象)时按每帧判断重新处理;`Patron.reset_pose` 与 `_exit_tree` 也会恢复。
- 身体、手臂、牌扇照常显示;别人看到的一切不变。

### 1.4 手里的牌
- 第一人称时牌扇按镜头坐标拿在画面右下(`Patron.FP_FAN_CAM = (0.22, −0.12, −0.55)`,放大 `FP_FAN_SCALE = 1.0`),
  牌面法线指向眼睛、牌顶朝画面上方。1080p 下每张牌约 260 px 高,让开底部的出牌按钮。
- 牌扇每帧跟着眼睛平移(座位坐标里平移,再换到身体局部、抵消前倾与呼吸):探头、前倾时牌在画面里不动。
- 德州:`PokerLayout.FP_FAN_CAM = (0.4, −0.1, −0.6)`、`FP_FAN_SCALE = 0.95`,比骗子酒馆更靠右,让开下注面板、右下角的记录与公共牌。
- 切换视角时重摆:骗子酒馆由 `TableWorld.present_my_hand` 摆,德州由 `PokerCards` 收到 `TableWorld.first_person_changed` 后摆。
- 出局了不动(牌扇扣在大腿上)。
- 点牌照旧:`TableScreen._pick` 用的就是当前镜头的射线,第一人称下同样能点。

### 1.5 导演与常驻机位
- 新增 `SeatCamera`(`src/ui/table/seat_camera.gd`,骗子酒馆与德州共用):`enter(duration)` 回座(越肩 = `move_to(third_person_view)`;
  第一人称 = `CameraRig.follow` 跟着眼睛,带视角、补光),`leave()` 离座(视角、补光还原),`toggle()` 切换并存设置。
- `TableDirector` 的开场运镜、`back_to_seat` 改走 `seat_camera.enter`,`_leave_seat` 走 `seat_camera.leave`;翻牌、开枪特写、胜者环绕、观战机位都不变。
- 回座运镜还在走时按 V:等它走完再切(否则导演 await 的补间被打断,演出会卡住)。
- `TableWorld.seat_view(pid)` 按本机视角给越肩或第一人称;`rest_view` 改为按 `seat_view` 给(观战机位不变);`third_person_view` 保留给原来的调用方与测试。
- `CameraRig.follow(source, duration)`:每帧调用 `source` 取目标,先在 `duration` 内过渡过去;`move_to` / `snap` / `orbit` 会停止跟随。

### 1.6 约束
- 不改规则、协议、网络;藏头与牌扇位置都只在本机。
- 性能预算照过;性能探针加了 `fp` 机位(预算同越肩 `seat`)。

## 2. 实现记录

| 常量 | 值 | 位置 |
|---|---|---|
| `Settings.KEY_CAMERA_MODE` | `"camera_mode"`,值 `"third"` / `"first"` | settings.gd |
| `Patron.FP_EYE_OFFSET` | (0, 0.07, −0.12) | patron_3d.gd |
| `Patron.FP_FAN_CAM` / `FP_FAN_SCALE` | (0.22, −0.12, −0.55) / 1.0 | patron_3d.gd |
| `PokerLayout.FP_FAN_CAM` / `FP_FAN_SCALE` | (0.4, −0.1, −0.6) / 0.95 | poker_layout.gd |
| `TableWorld.FIRST_PERSON_FOV` | 72° | table_world.gd |
| `TableWorld.FIRST_PERSON_TARGET` | (越过桌心 0.15, 高出桌面 0.08) | table_world.gd |
| `TableWorld.FIRST_PERSON_FILL` | 0.4 | table_world.gd |
| `SeatCamera.HEAD_CLEAR` | 0.45 m | seat_camera.gd |
| `SeatCamera.TOGGLE_MOVE` | 0.35 s | seat_camera.gd |
| `MeshKit.LAYER_LOCAL_HIDDEN` | 1 << 19(编辑器第 20 层) | mesh_kit.gd |
| `CameraRig.DEFAULT_FOV` | 66°(原来写死在 `_ready`) | camera_rig.gd |

与协调方方案的出入:
- **脖子也藏**:往下看时拉长的脖子会进画面,和头一起处理。
- **牌扇跟眼睛平移,不只跟脖子偏移**:只跟脖子时,轮到自己前倾会让牌在画面里下沉 8–9 cm(4:3 下出画),改为跟整个眼睛的位移。
- **不叠额外平滑**:眼睛本身已平滑;`CameraRig.follow` 到位后直接贴着走。
- **德州没有接 V 键**:德州的牌桌控制器(规划里的 `poker_screen` / `poker_director`,任务 7b)在这个分支上还不存在。
  已经做好的部分:`PokerCards` 的第一人称底牌、`TableWorld.seat_view` / `rest_view` 按视角给机位、共用的 `SeatCamera`、说明书德州页的操作行。
  德州控制器接入时:导演里建 `SeatCamera`,回座用 `enter`、离座用 `leave`,按键处理里 V 调 `toggle` 并弹 toast(同 `TableDirector.toggle_camera_mode`)。

## 3. 测试与截图

- `tests/test_first_person.gd`:设置持久化与坏值回退;眼睛在头上、跟着探头走、朝向不跟转头;藏头只投影、身体手臂不受影响、
  换回越肩 / 复位 / 换屏恢复、后挂的件也藏、只在镜头到了眼睛附近才藏、出局露头与复活后重新藏;
  骗子酒馆与德州每个物种、轮到自己前倾、5 种探头下牌在视锥里(16:9 与 4:3)、离眼睛 ≥ 0.15 m、不被自己挡住;
  选中抬起也在画面里;第一人称镜头的射线点得到每张牌;导演拍完翻牌回到第一人称 / 越肩座位;回座途中按 V 不卡导演;
  出局按 V 只改设置、镜头不动。
- 截图:`tools/shot.gd --showcase` 的 `fp` / `fp_peek` / `fp_lean`,`--poker-showcase` 的 `poker_fp` / `poker_fp_peek`(`CameraViews.FIRST_PERSON`)。
- 性能探针:`--view=fp`(骗子酒馆展台)。
- 实机:调试开关 `--camera=first|third` 只覆盖本次、不写设置(配合 `--shots` 拍整局第一人称:发牌、翻牌、自己开枪的特写里头照常露出)。

## 4. 待定

- 第一人称时左右邻座离得近,德州 8 人桌两侧邻座的铭牌在画面外(越肩时看得到)。
- 往前探到很深时,手里的牌会和桌心的目标牌立牌、别人的头穿插(牌扇是普通的 3D 物体)。
- 自己头顶的气泡(番茄 / 快捷语分支)在第一人称里看不到,需要那边决定是否改走 HUD(骗子酒馆原来就让自己的气泡走 HUD)。
