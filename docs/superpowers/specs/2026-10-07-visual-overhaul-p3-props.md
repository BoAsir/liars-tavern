# 子项目③ 道具：左轮、卡牌、目标架、烛台、牌桌、吊灯、枪口焰与硝烟、吧台啤酒杯

> 子项目详细设计。总纲见 `2026-10-07-visual-overhaul-design.md`;冲突时以总纲第 3 节「已定决策」与第 4 节「裁定」为准。
> 状态:已确认(用户授权自审)。本文由设计 agent 起草、对抗性复核修正;文中「实测」数据来自 scratchpad 原型,未入库。

## 0. 范围、前置、红线

**范围**：左轮（模型，加上握持、举枪、静置、掉落）、卡牌（牌体和牌面美术）、目标架、烛台、牌桌、吊灯、枪口焰与硝烟、吧台啤酒杯。

**不在范围内**：
- 桌布刺绣（V5，归①）
- 酒瓶（F5，归①）
- 吧台本体（R5，归④）
- 牌背 6 孔改 5 孔（V4，归①）。③只抽出纯函数 `chamber_points` 并补测试。

**依赖①**。开工前逐项核对；缺哪项，就在 ③-0 补上并补单测：
- `MeshForge`（`src/world/mesh_forge.gd`）需要有：`cached/clear_cache`、`push/pop`、`color/ao/pbr`、`lathe`、`tube`、`loft`、`extrude`、`commit`。③另需几项扩展，见 §1.1。
- `SeatLayout.FELT_TOP`（= `TABLE_TOP + 0.004`，来自 V4），以及牌堆第一张被桌布吃掉的修复（`card_table.gd:195`）。
- F4：左轮已拆成 Body/Drum/Hammer 三个节点，4 把枪共享网格，`Chamber1..5` 已是空标记。③只换几何，不动节点结构。
- F2 的阴影层约定：层 2 = 大投影物；小于 8 cm 的件不投影；月光只让窗墙投影。
- F7：火焰共享材质（`instance uniform seed`）。
- V3：钢和胡桃木（`walnut` 木纹预设）的材质数值。
- V7：烛光 5 盏改 2 盏。若①没做 V7 或 F7，③在重做烛台时一并做掉。
- F0 已合入（`476630d`、`180cd28`），提供：
  - `tools/perf_probe.gd`：可见 / 阴影 draw call 拆分、`--assert-budget`，以及 `revolvers-off`（按 `Revolver3D` 类查找）。
  - `tools/scene_census.gd`：清点实例、材质、三角形。
  - `tools/perf_budget.gd`：`LIMITS` 目前是①完成后的数（seat 650、menu 700、其他 800、帧 9.7 ms、CPU 0.9 ms）。

**依赖②**：
- **持枪净空** `PatronParts.species(i)['gun_clearance']`：
  - 定义：从名义头心 C0（Head 局部 (0, 0.12, 0)，`patron_3d.gd:279-280`）出发，沿举枪接近方向 `Patron.GUN_APPROACH := Vector3(1, 0.25, -0.1).normalized()`（Head 局部），到头部子树最外表面的距离。
  - 要算进毛、耳朵（含抖耳 −0.3 rad，`patron_3d.gd:230-235`）和帽子。
  - 取值范围 0.14–0.22。②没给时取 0.17（现在的头球半径，`patron_3d.gd:149`）。
- **握枪拳头（C4）**：
  - 按 §2.4 的 `HOLD_OFFSET` 对齐：爪心 = 枪原点，枪管沿手局部 −Z。
  - 举枪时手相对手臂要转约 135°（§2.4）。拳头的腕口必须被袖口或毛圈盖住，任何转角都不能露缝。
- **躯干外廓**：8 个物种在 `SEATED_LEAN + TURN_LEAN`（`patron_3d.gd:24-25`）下，离新桌沿都 ≥ 1.5 cm（§6 有测试）。
- **预算上限**：`tools/perf_budget.gd` 的 `LIMITS` 已改成全部完成后的上限（seat 700、menu 800、其他 900、帧 10.0 ms、CPU 1.0 ms），`tests/test_perf_budget.gd:21-25` 同步。
  - ②没改就由 ③-6 改，并按「保留原意」规则在计划里标出。原意是预算表跟着设计文档当前阶段走。
- 协议保持 v5，③不碰网络。

**红线**：
1. 五个弹膛外观完全一样，转轮网格 5 重旋转对称。模型从不读 `GameState`。
2. 左轮的几何约定不变：
   - 原点 = 握持点，枪管沿 −Z（`fx.gd:57`，`patron_3d.gd:403`）。
   - `drum` 绕本地 Z 转，每扳一次正好 `TAU/5`（`test_revolver_3d.gd:12-17`）。
   - `muzzle` / `muzzle_transform()` 保留（`table_director.gd:178,206-207`）。
3. 卡牌和目标架的接口不变：
   - `STAND_HEIGHT` 和 `stand_position()` 不变（`card_table.gd:20,82-83,163,293,304`）。
   - `Card3D.WIDTH/HEIGHT` 不变（`test_hand_visibility.gd:62`、`test_patron_arms.gd:146`）。
   - `ray_hit_distance` 仍按 y=0 平面求交（`card_3d.gd:112-125`）。
4. `TABLE_TOP`、`TABLE_RADIUS` 不变（`seat_layout.gd:6-7`；现在的台面半径就是 `TABLE_RADIUS` = 0.95）。桌面在 r ≤ 0.98 内必须平整，原因有两个：
   - 爪底贴在 `TABLE_TOP`（`patron_3d.gd:319`）。
   - 爪心落在 r≈0.92±0.058（`test_patron_arms.gd:132-138`）。
5. 牌桌台面必须是**封闭圆盘**。桌布不投影（`tavern.gd:170`），吊灯聚光（`tavern.gd:194-205`，投影）照向桌下的光只能靠台面挡住。
6. 吊灯全部部件挂在 `_lamp_pivot` 下（`tavern.gd:179`）。各机位看对面座位的视线要从灯罩下方过（`table_world.gd:154-189`）。
7. 灯的**直接父节点**名前缀 `Candles` / `LampPivot` 不变（`perf_probe.gd` 的 `_lights_under`，145-147 行）。
   - 两个烛台枢轴起唯一名字 `Candles1`、`Candles2`。现在第二个同名枢轴会被引擎改名为 `@Node3D@74`（评审无头复测），`candle-lights-off` 只关掉了第一个烛台的灯。
   - `_flickers` 改为引用新灯（`tavern.gd:31,245`）。
8. 新的静态缓存都在 `main.gd:82-88` 释放。网格和贴图构建必须能无头运行：
   - 测试用 `TableWorld.new(null)`。
   - `Tavern.new()` 无头构建实测 20 ms，测试可以直接用。
9. `test_fx.gd:37-43`：
   - `muzzle_flash` 下第一个 `GPUParticles3D` 仍是火花，1 s 内释放。
   - `parent.get_child(0)` 比火花活得久。
   - 硝烟寿命 ≤ 3.2 s。
10. 着色器：
    - ③只新增 `prop.gdshader` 一个 spatial shader 文件。总规格 §4.1 规定新增自定义 spatial shader ≤ 4，①②已用掉 `patron`、`patron_eye` 和酒瓶假玻璃。
    - 共享的 `soft_particle.gdshaderinc` 不得引入 `hint_depth_texture`。壁炉火星一直可见，用的就是它；静态引用深度纹理会让每帧多一次深度拷贝。

**实验依据**。只读实验，都在私有仓库副本里跑：
- 设计稿实验在 `scratchpad/design_lab/props_repo/lab_props/`：
  - `proto_props.gd`：用迷你 forge 搭出全部道具。
  - `measure.gd`：三角形数和构建耗时。
  - `geometry*.gd`：在真 `Patron` / `TableWorld` 上验证举枪、静置、掉枪、牌堆、牌扇。
  - `render.gd`：快照输出到 `props_shots/*.png`。
  - 下文标「实测」的数字出自这些实验。
- 评审复测在 `scratchpad/design_lab/review3/repo/lab/`：
  - `dead_paw.gd`：按导演流程先看自己的头再举枪（见 §2.4）；出局后右爪的位置。
  - `tavern_headless.gd`：Tavern 无头构建耗时、烛台枢轴名字。

**子任务顺序**。同一次发版，每步一个可回退的提交：
- ③-0 基础
- ③-1 左轮与握持
- ③-2 卡牌（③-2b 手牌弯曲可选）
- ③-3 牌桌、目标架、烛台
- ③-4 吊灯、啤酒杯
- ③-5 枪口焰与硝烟
- ③-6 预算和截图验收，小版本号发版（走 release-update 流程）

## 1. 共用基础（③-0）

### 1.1 MeshForge 扩展（①已有的只补测试）
- **多 surface**：新增 `func surface(index:int) -> MeshForge`，之后的几何写进该 surface；`commit()` 为每个用到的 index 生成一个 surface。
  - 材质用 `mesh.surface_set_material(i, mat)` 设在共享网格上。
  - 所有实例共用同一份材质资源，才能触发自动实例化。
- **glow 通道**：新增 `var glow := Vector2.ZERO`，x 是自发光强度（0..1），y 是背光 / 透光（0..1）。
  - prop surface 的 UV 不当贴图坐标用，统一写 `glow`。
  - `paint_glow(fn)` 改写最近一次 `mark()` 之后的顶点，用于蜡烛顶端渐亮。
  - 木纹 surface 不读 UV（木纹在物体空间，`wood.gdshader:22-24`）。卡牌用 `raw()` 自己写 UV。
- **`raw(verts, normals, uvs, indices)`**：给卡牌的圆角牌体用。
- **`extrude(outline, depth, bevel)`**：
  - 用斜接内缩做倒角，凹角处限幅 0.35。
  - 两端各一圈倒角环，加侧墙。
  - 轮廓自动转成逆时针。
  - 不支持带洞轮廓；转轮弹膛孔的做法见 §2.1。
- **颜色空间**：`color` 写入的是线性色（总规格 §5.2），`prop.gdshader` 直接用 `ALBEDO = COLOR.rgb`。调色板存的是 sRGB，`PropModels` 写入前一律调 `srgb_to_linear()`。

### 1.2 `prop.gdshader` 与调色板
新增 `src/world/shaders/prop.gdshader`，一份材质服务所有道具的金属、蜡、珐琅、泡沫部分：
```glsl
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec3 emission_color : source_color = vec3(1.0, 0.78, 0.5);
uniform float emission_energy = 4.0;   // 灯泡 1.0×4(即 V1 的 9→4),蜡顶 0.06×4
uniform vec3 backlight_color : source_color = vec3(0.9, 0.55, 0.3);
void fragment() {
	ALBEDO = COLOR.rgb; AO = COLOR.a; AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = UV2.x; METALLIC = UV2.y;
	EMISSION = emission_color * emission_energy * UV.x;
	BACKLIGHT = backlight_color * UV.y;
}
```
- `WorldMaterials.prop()` 走 `_cached`（`materials.gd:161-165`）。
- 调色板 `WorldMaterials.PALETTE` 记录每种材料的 sRGB 色 / 粗糙度 / 金属度。albedo 封顶 0.8，自发光的灯泡除外。钢和黄铜直接用 V3 的常量。

| 名称 | 颜色（sRGB） | 粗糙度 | 金属度 | glow / 备注 |
|---|---|---|---|---|
| steel | (0.28,0.30,0.34) | 0.32 | 0.75 | |
| steel_dark | (0.05,0.05,0.055) | 0.8 | 0.3 | 膛口、槽底、弹膛孔 |
| brass | (0.78,0.56,0.24) | 0.28 | 1.0 | |
| iron | (0.12,0.12,0.13) | 0.55 | 0.8 | |
| wax | (0.78,0.72,0.60) | 0.55 | 0 | glow.y 0.35 |
| wick | (0.05,0.04,0.03) | 0.9 | 0 | |
| enamel_green | (0.17,0.32,0.22) | 0.35 | 0 | |
| enamel_cream | (0.80,0.75,0.62) | 0.6 | 0 | glow.x 0.12 |
| bulb | (1.0,0.9,0.7) | — | — | glow.x 1.0，自发光体，不受 0.8 封顶 |
| foam | (0.80,0.75,0.60) | 0.9 | 0 | |

①若改用 AgX，只需在这一张表里重调。

- 新增木纹预设 `turned`：深色、`grain_axis` 1、不分木板，用于桌柱和桌腿。
- 新增木纹预设 `mug`：`plank_width` 0.022、`grain_axis` 1。
- 握把沿用 V3 的 `walnut`。
- **预热**：
  - prop 和卡牌 shader 在启动建酒馆和牌桌时就会用到（`main.gd:31-36`），菜单阶段完成编译。左轮的胡桃木只是 wood shader 的另一组参数，不新增编译。
  - 枪口焰沿用 `soft_particle_add`。壁炉火星一直在用它，已经编译过。
  - 硝烟用的 `StandardMaterial3D` 变体同时用于酒客登场 / 离场的烟尘（`patron_3d.gd:506,510`），第一次在等待厅有人登场时编译，不会卡在开枪那一刻。

### 1.3 `PropModels` 缓存与构建时机
新增 `src/world/prop_models.gd`（`class_name PropModels`）。每个道具一个静态构建函数，全部经 `MeshForge.cached('prop:...')` 缓存：
- `revolver_body` / `revolver_drum` / `revolver_hammer`
- `card`
- `stand_base` / `stand_clip`
- `candle_holder(count, seed)`
- `table_top` / `table_felt`，另导出 `TABLE_PROFILE`（台面车削轮廓的 (r, y) 折线，供测试用）
- `lamp` / `chain_link`
- `mug`
- `prewarm()`：在工作线程里构建左轮三件和牌体的顶点数组

**构建时机**（只用这一种做法）：
- 牌桌、烛台、吊灯、啤酒杯在 `Tavern._ready` 里按需同步构建。Tavern 在 `main.gd:31-32` 就加入场景树，早于 `main.gd:51`。
- `main.gd` 在 `await CardFaces.build(self)`（`main.gd:51`）之前调 `PropModels.prewarm()`。
  - 左轮和牌体的数组在 `WorkerThreadPool` 里构建，正好与卡面构建的等帧并行。
  - `add_surface_from_arrays` 回主线程完成。
- `cached()` 遇到还在工作线程里的 key，先 `wait_for_task_completion`。所以测试里直接 `Revolver3D.new()` 也能同步拿到网格。
- 不预建的话，第一把左轮会在开局 `arrange`（`table_screen.gd:59` → `table_world.gd:90-95`）时现建，卡一帧。

**构建耗时**：
- 实测（M3，无头，原型分辨率）：全部合计 26.5 ms，最慢单项 9 ms（左轮）。
- 最终分辨率预计：主线程同步部分（牌桌、烛台、吊灯、杯子）≤ 25 ms；左轮在工作线程里，不占主线程。

## 2. 左轮（③-1）

### 2.1 外形规格
枪本地坐标，单位米：原点 = 爪心，−Z 为枪管，+Y 向上。截面整体加粗约 1.24 倍，长度基本不变。

| 部件 | 新规格 | 现状 |
|---|---|---|
| 枪管 | 轴线高度 `BARREL_Y` 0.073；z 从 −0.067 到枪口冠 −0.255；根部加粗段 r 0.0125、长 18 mm；主管 r 0.0105；冠部 1.5 mm 圆角；膛口 r 0.0045、深 8 mm，用 steel_dark；车削 32 段 | r 0.0085 圆柱（`revolver_3d.gd:27`） |
| 转轮 | `DRUM_POS` (0, 0.055, −0.042)；r 0.031，长 0.050；弹膛之间 5 道弧形凹槽（深 4.5 mm、半宽 0.22 rad）；前端倒角 2 mm、后端 1.5 mm；轮廓 128 点挤出 | r 0.025 圆柱加方块「槽」（`:37-46`） |
| 弹膛 | `CHAMBER_RADIUS` 0.018（= `BARREL_Y − DRUM_POS.y`）；5 个前端面内凹 4 mm 的暗孔，孔 r 0.0065，完全相同；后端被防退护板挡住，不显示弹壳 | 从 +X 起排，没有一个对准枪管 |
| 机匣 | 后块（防退护板、击锤座、背带顶）为 10 点侧轮廓，宽 0.030，倒角 2 mm；前块宽 0.028；顶梁 y 0.088–0.095；底梁 y 0.016–0.023 | 两个方盒（`:24-25`） |
| 退壳杆护套 | 右侧 (0.0085, 0.0595)，z −0.08…−0.196，r 0.005，带杆头 | 下护套是方条（`:29`） |
| 准星 | 半月刀片，z −0.242，高 8.5 mm、厚 3.5 mm | 方块（`:30`） |
| 护圈 / 背带 | 黄铜 tube，r 3.5 mm / 3 mm | 圆环（`:33`） |
| 扳机 | 新月形挤出，厚 4 mm | 方块（`:35`） |
| 握把 | 胡桃木犁柄 loft：y 0.022→−0.074，向后倾，半宽 0.013→0.017；截面 24 点 × 10 环；黄铜底帽 | 直胶囊（`:21-22`） |
| 击锤 | `HAMMER_PIVOT` (0, 0.086, 0.010)；带防滑槽的扳刺，厚 9 mm；扳动仍是 +38°（`:65`） | 两个方块（`:48-50`） |
| 枪口标记 | `MUZZLE_POS` (0, 0.073, −0.259) | (0, 0.058, −0.235) |

- **弹膛孔的建法**：
  - 前端面按 10 个 36° 半扇区拼。每块都沿过弹膛中心的径向线切开，弹膛的半圆就成了它边界上的缺口。
  - 这样每块都是简单多边形，可以直接用 `Geometry2D.triangulate_polygon`。
  - 孔壁和孔底用 `lathe` 车一个 4 mm 深的小杯（steel_dark）。
  - 不需要给 `extrude` 加洞，五重对称自然成立。
- 枪口离原点 0.259，不超过 0.27。
- 外廓：x ±0.031（由转轮决定），y −0.082…0.110。
- 三角形：原型实测 2.4k（Body 1160 + Drum 1216 + Hammer 60）；按上表的分段数，最终在 4–6k，硬上限 8k。
- 外观快照：`props_shots/gun_side.png`、`gun_front34.png`。

### 2.2 节点与材质
```
Revolver3D
└ Body   MeshInstance3D  s0=prop(钢/黄铜/暗膛)  s1=wood:walnut(握把,木纹沿枪本地 Y)
   ├ Drum   @DRUM_POS  s0=prop
   │   └ Chamber1..5  Marker3D,位置 (cos a, sin a, 0)·0.018 + (0,0,−0.025),a = PI/2 + i·TAU/5
   └ Hammer @HAMMER_PIVOT  s0=prop
└ Muzzle  Marker3D @MUZZLE_POS(成员变量仍叫 muzzle)
```
- 4 把枪共享同一套网格和材质，触发 Forward+ 自动实例化。
- 节点不起额外名字：探针的 `revolvers-off` 已按类查找。
- Body 和 Drum 投影；Hammer 按 F2 的小件规则自动不投影。
- 改完后左轮不再引用 `gunmetal()` 和 `iron()`。

### 2.3 转轮对准（`revolver_3d.gd:56-67`）
```gdscript
const CHAMBER_STEP := TAU / Revolver.CHAMBERS
static func aligned_angle(a: float) -> float: return roundf(a / CHAMBER_STEP) * CHAMBER_STEP
# spin_drum:   目标 = aligned_angle(drum.rotation.z + TAU * turns)
# cock_hammer: 目标 = aligned_angle(drum.rotation.z + CHAMBER_STEP)
```
- 弹膛角从 PI/2 开始排，所以只要 `rotation.z` 是整格，就恰好有一个弹膛在 12 点，与枪管同轴。
- `table_director.gd:195` 不用改。
- 五个弹膛和五道凹槽完全一样，停在哪一格都不泄露子弹位置。
- 现有两条测试原样通过：初始角 0 本身已对齐，扳一次正好加一格，误差小于 1e-6。

### 2.4 握持与举枪贴太阳穴

**握持偏移**：`Revolver3D.HOLD_OFFSET := Transform3D(Basis(), Vector3(0,0,-0.004))`。在现在的球形爪上实测，埋进爪里的顶点比例：
- 转轮 12%
- 机匣和护圈 19%
- 击锤 0%
- 握把 66%，底帽露在爪下

旧枪的机匣中心整个在爪里，这就是 `gun.png` 里只剩「两根黑棍」的原因。

**`pick_up`**（`patron_3d.gd:387-395`）：
- 把 `:394` 的吸附目标换成 `HOLD_OFFSET`。
- 开头就设 `_has_look = false`。导演层刚让开枪者看自己的头（`table_director.gd:164`），俯仰被夹到 0.35 rad（`patron_3d.gd:205`）；提前清掉，头在举枪前就有 0.82 s 回正。
- 评审复测：如果只在举枪开始时清，瞄准那一刻俯仰还有 0.090 rad，之后 1.5 s 头心漂移 11.6 mm；提前到 `pick_up` 后，残余约 0.02 rad（约 3 mm）。

**手位求解**。`HAND_GUN_HEAD`（`:34`，身体局部）改为由纯函数求出，常量保留为默认净空下的解：
```gdscript
const GUN_CLEARANCE := 0.008
const DEFAULT_GUN_CLEARANCE := 0.17
const GUN_APPROACH := Vector3(1, 0.25, -0.1).normalized()   # Head 局部:举枪的接近方向
const HAND_GUN_HEAD := Vector3(0.429, 0.852, -0.061)       # = gun_hand_target(0.17)
static func gun_aim(origin: Vector3, center: Vector3) -> Basis   # 让枪管轴线(比原点高 BARREL_Y)穿过头心,定点迭代 3 次
static func gun_hand_target(clearance: float) -> Vector3
	# 名义头心 C0 = HEAD_PIVOT + (0,0.12,0)。手在以 SHOULDER 为心、半径 ARM_LENGTH 的球面上;
	# 沿 GUN_APPROACH 这一族方向二分,使 gun_aim 之后 |枪口 − C0| = clearance + GUN_CLEARANCE
```
- 纯函数，每次举枪现算（几十次浮点迭代），不加静态缓存。
- clearance 在 0.14–0.22 内都有解，手都高于肩。

实测解：

| 净空 R | 手位（身体局部） | 手臂仰角 |
|---|---|---|
| 0.15 | (0.406, 0.867, −0.060) | 61° |
| 0.17 | (0.429, 0.852, −0.061) | 57° |
| 0.19 | (0.452, 0.836, −0.062) | 53° |

现在的仰角是 69°（手臂朝 (0.33,0.85,−0.05) 伸满 0.4）。新手位更往外，读起来是「枪抵太阳穴」。

**`raise_gun_to_head`**（`:398-407`）新流程：
1. 设 `_sitting_up = true`（`_has_look` 已在 `pick_up` 里清掉）。
2. 调用 `pose_right(gun_hand_target(_gun_clearance()), duration, TRANS_BACK)`。`_gun_clearance()` 读物种表的 `gun_clearance`，没有时取 0.17。
3. 用实际的 `head_position()` 迭代 `gun_aim` 两次，得到瞄准基 A。枪原点 = 手位 + 手基 × `HOLD_OFFSET.origin`。
4. **转手不转枪**：在 0.18 s 内把 `right_hand.quaternion` 补间到 `(手臂全局基⁻¹ · A · HOLD_OFFSET.basis⁻¹)`。
   - 各个基先 `orthonormalized()`，因为身体呼吸是非均匀缩放（`patron_3d.gd:196`）。
   - 枪相对手始终保持 `HOLD_OFFSET`，②的握枪拳头自然包住握把。
   - Hand 只转不移。`_right_arm_points_at`（`test_table_world.gd:36-39`）只看位置，不受影响。
   - 代价：枪管要指向头心，而手臂朝外上方，手相对手臂约转 135°。按默认解：手臂方向 (0.55, 0.83, −0.10)，枪管方向 (−0.98, −0.19, 0.09)。现在的球形爪看不出来；②的拳头必须盖住腕口（见依赖②）。
5. `lower_gun` 与 `pose_right` 并行，把手的旋转补间回单位；`die`、`reset_pose`（`:431,:488`）直接复位。

实测（真 `Patron` 加原型枪尺寸；设计稿实验没走导演层的 `look_at_point`，按导演流程的复测见上）：

| 指标 | 新方案 | 旧方案 |
|---|---|---|
| 枪口到头心 | 0.1838（离表面 13.8 mm） | 0.154（插进头 1.6 cm） |
| 枪管轴线到头心 | 2.2 mm | — |

准星只比枪管轴线高 19 mm，帽檐在头心上方约 0.135，不会再插进帽檐。②的帽子和耳朵由穿模测试兜底（§11）。

### 2.5 静置与掉落

**桌上静置**（`table_world.gd:144-151`）。两个着地点不在同一高度：
- 转轮着地线在 r 0.78–0.82，落在毡面（外沿 0.818）上。
- 握把底帽在 r≈0.88，落在木桌面上，比毡面低 `FELT_TOP − TABLE_TOP` = 4 mm。

所以桌上和地上用两组常量，四个常量都由测试按网格顶点校验（±0.5 mm）：
- 地上：`REST_ROLL` ≈ −5°，转轮与底帽同时着地；`REST_HALF_WIDTH` ≈ 0.026，是此时最低点到原点的高度。
- 桌上：`TABLE_REST_ROLL` ≈ −8°，此时转轮最低点比底帽最低点高 4 mm；`TABLE_REST_LIFT` 是这个姿态下转轮最低点到原点的高度。
- 基改为 `looking_at(aim) * Basis(BACK, PI/2 + Revolver3D.TABLE_REST_ROLL)`，高度改为 `FELT_TOP + Revolver3D.TABLE_REST_LIFT`。

实测（9 种座位组合）：
- 最低点 = `FELT_TOP`。
- 离烛台碟边至少 0.070（3 人局、240° 座位）。
- 离第 3 张翻牌至少 0.034。

**掉落 bug**：`die()` 的落点 `landing.lerp(global_position, 0.25)`（`patron_3d.gd:440-441`）把 y 也朝地面插值。实测枪停在 y=0.60，悬在椅子右侧半空中（座位局部 (0.27, 0.60, −0.03)）。改法：
- 落点改为 `global_transform * Vector3(0.42, 0, 0.05)`，`y = REST_HALF_WIDTH`。
- 旋转改为 `(0, rot.y+1.8, PI/2+REST_ROLL)`。
- x=0.42 离椅腿（x ±0.2）和②的腿脚都有 0.2 m 以上余量。
- 评审复测：出局后右爪在座位局部 (0.29, 0.47, 0.10)，离落点 0.465 m；头在 (0.42, 1.09, 0.32)，压不到枪。

## 3. 卡牌（③-2）

**牌体**。`card_3d.gd:39-53` 的两片 `PlaneMesh` 换成 1 个 `MeshInstance3D`，共享 `PropModels.card()`：
- 形状：
  - 圆角 `CORNER` 0.0087（= 26/360 × WIDTH，与贴图圆角一致，`card_faces.gd:8`）。
  - `THICKNESS` 0.0008，以 y=0 为中面。
  - 正反面沿高度切 10 条（给可选的弯曲留顶点），外加一圈侧边。
- UV：正面 u = x/W+0.5、v = z/H+0.5；背面 u 镜像，与现在背面绕 Z 转 π 一致（`card_3d.gd:50`）。
- 三角形：原型 80，最终 ≤ 160。
- 去掉 `discard`（`card.gdshader:14-16`），保持投影。

**`card.gdshader` v2**：
- 纹理：`sampler2DArray faces`（source_color，各向异性）和 `sampler2DArray foil`。
- 实例参数共 5 个：`face`、`both_faces`、`bend`、`glow`、`glow_color`（上限 16）。`face` 默认 0 = 牌背层，新建的牌不设也对。
- `vertex()`：按原法线的 y 求 `side`（+1 正面、−1 背面、0 侧边）。`bend` 为 0 时不位移；启用弯曲时做弯曲并修正法线。
- 正面取 `face` 层；背面取 `mix(back_layer, face, both_faces)`。
- `foil` 遮罩驱动金属度 0.5、粗糙度 0.8→0.3、高光 0.12→0.5。
- 侧边是烫金：metallic 0.7、粗糙度 0.35。
- 保留 `albedo_scale`、`ink_contrast`、辉光公式（`card.gdshader:5-23`）。

所有牌只有一份网格、一份材质，牌型差异全在实例参数里。20 张牌约 1 个实例化 draw/pass；②发版时是 40 个实例、5 个材质。

**`Card3D` 接口变化**：
- `set_kind` 改为写 `face`；`set_both_faces` 写 `both_faces=1`。
- `clear_materials` / `refresh_materials` 保留名字（`main.gd:52,84`、`showcase.gd:7` 在用），改为重绑数组纹理。
- 删除 `material_for` 和 `GAP`，仓库内没有其他引用。
- `CardFaces.clear()` 同时释放牌面数组和烫金数组。

**手牌弯曲（可选，③-2b）**。草稿测得视觉收益很小，所以先做 ③-2 的平牌体，看 fan 截图再决定。不做时 `fan_slot` 扇距保持 0.0016，也不进验收。决定做时：
- `Card3D.HAND_BEND := 0.0012`：沿牌高方向两端朝牌面翘起。实例参数 `bend` 是 0..1 的系数，振幅是材质参数 `HAND_BEND`。
- 只沿高度方向弯，因为横向弯 0.5 mm 就会和邻牌相交。
- 相邻两张牌之间的最小间隙（前一张正面到后一张背面），实测：

| 扇间距 | 弯 0.8 mm | 弯 1.2 mm | 弯 2.0 mm |
|---|---|---|---|
| 1.6 mm（现状） | 0.43 mm | 0.24 mm | −0.14 mm（相交） |
| 2.4 mm | — | 1.04 mm | — |

- 取 `CardTable.FAN_LAYER := 0.002`，替换 `card_table.gd:137` 的 0.0016，间隙约 0.64 mm。
- `_layout_mine` / `_layout_held`（`:113-127`）把 bend 设为 1；出牌、翻牌、收牌、断线收走时设为 0。

**落桌高度**。抽出纯函数 `pile_transform(i, seed)` 和 `reveal_transform(i, n)`：
- 牌堆 y = `FELT_TOP + THICKNESS/2 + 0.0003 + i·0.0011`（替换 `:195`）。
- 翻牌行 y = `FELT_TOP + THICKNESS/2 + 0.0003`（替换 `:254`）。

**美术**（`card_faces.gd`）：
- **尺寸**：保持 `SIZE` 360×520（`:6`）。3D 内部分辨率封顶 1080p（`render_budget.gd:7`），牌在画面上最高约 350 px，520 已是 1.5 倍采样。
- **牌面**：
  - 奶油外边加宽到 10 px，外沿加 1 px 深色切线。
  - 金色内框改成双线。
  - 构图保持不变（`:135-163`）。
  - 所有金色元素进烫金遮罩。
  - 不画宫廷肖像。
- **牌背**：
  - 12 px 奶油外边，解决在绿毡上对比度低的问题。
  - 深红底加金色斜格（`:236-244`）、双边框、四角卷草。
  - 中心转轮徽章：①的 V4 已改为 `Revolver.CHAMBERS` 个孔、第一个孔在 12 点。③只抽出纯函数 `CardFaces.chamber_points(center, radius)`，绘制和测试共用。
- **烫金遮罩**：
  - `CardPainter` 加 `foil` 开关，所有颜色经 `_ink(color, is_gold)`：遮罩模式下金色画白，其余画黑。
  - 与牌面同一帧再开 5 个 SubViewport 抓遮罩，转成 R8，缩到 180×260，生成 mipmap。
- **数组纹理**：
  - 图层顺序 `LAYERS = [BACK, QUEEN, KING, ACE, JOKER]`，提供 `layer(kind)`、`face_array()`、`foil_array()`。
  - 未构建或无头时返回 8×8 的替代数组（无头分支见 `card_faces.gd:50-54`）。实测无头下 `Texture2DArray.create_from_images` 和实例参数都能用。
  - 数组要求各层同尺寸，所以任意一张抓图为空时，整组改用替代图。
  - `texture(kind)` 不变（`table_hud.gd:62,220`、`rulebook_blocks.gd:88`、`make_icon.gd:18-19` 在用）。
- **显存与启动**：显存约 +5.3 MB（5×360×520×4×1.33 的数组副本 + 0.3 MB 遮罩）；启动约 +5–10 ms。

## 4. 目标架（③-3）
- `_stand`（`card_table.gd:55-64`）仍是 `TABLE_TOP` 处的固定根节点，但**不再转**。底座网格在内部抬高 4 mm 坐到毡面上，所以 `stand_position()` 不变。
- **底座**（s0 = wood:dark，s1 = prop）：
  - 车削 ogee 线脚，主体 r ≤ 0.030、高 0.017。
  - 外缘是 r 0.044 的裙边，高 ≤ 2 mm，带黄铜嵌线和轴承帽。
  - 裙边这么矮，是因为实测牌堆里 4.1% 的牌会伸进 r<0.045，1.0% 伸进 r<0.035。
- **夹子**：新增子节点 `_spinner`（名为 `Spinner`），`_process`（`:49-50`）改为只转它。
  - 网格：车削立轴，r 4.5 mm，带两道珠环。
  - 顶端叉形夹：两片 1 mm 黄铜叶片，在牌法线方向 ±1.2 mm，夹住牌底 6 mm。
  - 不投影。
- `_target_card` 改挂到 `_spinner` 下，位置不变（`:62`）。
- **翻面回弹**（`:74-77`）：
  - 翻面时压扁的是牌，夹子不受影响。
  - 回弹缩放 (1.25, 1, 1.25) 会让牌底下移 HEIGHT×0.125≈2.2 cm，插进立轴。所以回弹期间同步把牌上移 `HEIGHT × (s − 1) / 2`，牌底钉在夹口。
- 三角形：底座 784 + 夹子 352 ≈ 1.1k。实例 3 个 → 2 个。

## 5. 烛台（③-3）
两个烛台枢轴命名为 `Candles1`、`Candles2`（`tavern.gd:218-245`）。每个烛台由 3 部分组成：
- 1 个合并网格（prop），投影，走普通层，用于吊灯下桌面的烛影。
- 若干片火焰。
- 1 盏 OmniLight3D，作为枢轴的**直接子节点**。

角度 0.76π / 1.31π、半径 0.7 不变。
- **碟**：卷边，外沿 r 0.085（≤ 0.09）。
- **每支蜡烛**（偏移和高度沿用 `:226-227`）：
  - 黄铜烛杯带托盘，r 0.026、高 0.02。三支杯心间距 0.061，杯间留 8.7 mm。
  - 蜡烛身 r 0.0170→0.0165；顶端熔口外缘高出 2 mm、中心下凹 3 mm；半径按种子抖动 ±0.4 mm。
  - 烛芯：tube，r 1.2 mm、长 8 mm，微弯。
  - 两道蜡泪，末端带泪珠；一片溢过杯沿的蜡池。
- **蜡的材质**：wax，`glow.y` 0.35；顶端 2 cm 的 `glow.x` 从 0 渐亮到 0.06。它替代整支蜡烛的 `emissive 0.03`（`:232`），那是蜡烛 86% 像素削顶的原因之一。
- **火焰**：仍是每支一片 billboard，依赖 `MODEL_MATRIX`（`flame.gdshader:14-25`），不能合并。用 F7 的共享材质加 `seed`。
- **灯**：
  - 每个烛台 1 盏，放在该簇火焰的平均位置上方 0.02。
  - 能量 = 0.42 × 支数 × 0.8，范围 2.2，flicker 参数同现在。
  - 总数 5→2。
- 三角形：3 支的烛台 2.6k，2 支的 1.96k。实例：②发版时 2 碟 + 10 件 + 5 片火焰，改后 2 个网格 + 5 片火焰。

## 6. 牌桌（③-3）
- **台面** `TableTop`（s0 = wood:table）。车削轮廓从桌心 r=0 起，是**封闭圆盘**：
  - r 0–0.80 是毡面下的 `TABLE_TOP` 平面，一圈中心扇形加一个环，约 +96 tri，被毡面盖住，只为挡光。
  - r 0.80–0.98 严格平在 `TABLE_TOP`。
  - 之后是半径 22 mm 的圆鼻边，滚到 r 1.002，再竖直落到 −0.045，底切回 r 0.97；96 段。
- **外缘变化**：现在的台面半径就是 `TABLE_RADIUS` 0.95（`tavern.gd:163`），0.97 是低 5 cm 的裙板（`:164-165`），所以台面实际外扩约 5 cm。
  - 现有躯干在 `SEATED_LEAN` 下，腹部前沿在 r≈1.12、y≈0.58，低于桌面。
  - 手臂跨过桌沿时，离台面 4 cm 以上。
  - ②允许的胸前外廓（体坐标 z ≥ −0.24）在 `TURN_LEAN` 下，在 y≈0.81 处到 r≈1.02，离圆鼻边约 2.5 cm。
  - 由 8 物种的外廓测试兜底（≥ 1.5 cm）。不过就把圆鼻外沿收到 0.995。
  - `table_screen.gd:186-189` 的光标视线落点仍用 `TABLE_RADIUS`，不受影响。
- **裙板和桌柱**：
  - s1 = wood:dark：裙板，带串珠线脚。
  - s2 = wood:turned：瓶状桌柱 y 0.10–0.66（r 0.06–0.13，三道环），加四条 cabriole 弯腿。
  - 腿朝 45°+k·90°，落在座位之间，末端 r 0.42，全部 ≤ 0.5。
- **黄铜件**（s3 = prop）：
  - **齐平**嵌条，r 0.943–0.958，只高出台面 0.5 mm。现在的圆环凸起 3.5 mm，正好在爪底下（`:166-167`）。
  - 柱顶铜箍（`:172`）。
  - 四只爪球足。
- **桌布** `Felt`：独立网格，felt 材质，不投影（`:168-170`）。
  - 车削垫，顶面 = `FELT_TOP`，边缘 4 mm 圆角，外沿 r 0.818。
  - 网格放在桌根原点，所以 `obj_pos.xz`（`felt.gdshader:40-42`）仍以桌心为原点。
  - 新增常量 `SeatLayout.FELT_RADIUS := 0.82`。
- 三角形：台面 2.0k + 裙板柱腿 2.8k + 黄铜 2.2k + 毡 1.2k ≈ 8.2k（≤ 12k）。实例 7 个 → 2 个（4 + 1 个 surface）。
- 木纹都在桌本地空间计算：`table` 预设沿 X，`turned` 预设沿 Y，方向正确。整张桌放在 F2 的大投影物层。

## 7. 吊灯（③-4）
全部挂在 `_lamp_pivot` 下（`tavern.gd:178-213`）。
- **`LampMesh`**：prop 材质，不投影。
  - 黄铜吊顶碗，r 0.075。
  - 钟形罩：双层车削壳，颈部在枢轴局部 y −1.30，罩口 y −1.52、r 0.36。外壁 enamel_green；内壁 enamel_cream，`glow.x` 0.12。取代现在内外同色、金属度 0.6 的「黑斗笠」（`:185-189`）。
  - 罩口黄铜珠边 r 5 mm，最低点 −1.525（世界坐标 1.875）。
  - 颈箍。
  - 灯泡 `glow.x` 1.0，即能量 4。
- **`LampChain`**：`MultiMeshInstance3D`。
  - 椭圆链节约 64 tri，节距 0.03，相邻节转 90°，共 43 节。
  - 1 draw/pass，不投影。
  - 替代现在的铁杆（`:180-181`）。
- **灯**：位置不变。SpotLight 仍在 y −1.45，fill 仍在 −1.35（`:182,195,207`），两盏都是 `LampPivot` 的直接子节点，其余参数也不变。
  - Godot 的 `spot_angle` 是半角。罩口在聚光下方 0.07 处，锥半径约 0.07·tan52° ≈ 0.09，远小于罩口 0.36，罩子挡不到光。
- **净空**：罩半径 0.365（≤ 0.38），最低点比现在低约 2 cm。各机位看对面座位头部的视线，在灯轴处的高度：

| 机位 | 视线在灯轴处的高度 |
|---|---|
| 观战（`table_world.gd:182`） | ≈ 1.62 |
| 越肩 | ≈ 1.55 |
| 等待厅（`:188`） | ≈ 1.71–1.76，离灯轴 0.31 m，最紧，余量 ≥ 0.11 m |

  开枪踢灯摆幅 0.14 rad 时，罩口低侧最多再下沉约 0.05。
- 三角形约 6.5k。实例 4 个 → 1 个 + 1 个 MultiMesh。①的珐琅灯罩材质和灯泡自发光材质这两个材质取消。

## 8. 枪口焰与硝烟（③-5）
**设计前提**：枪口抵在太阳穴外 8–14 mm，向前喷的东西几乎全在头里，所以可见的火焰和火花都要往侧面或往后喷。另外，几何上就不让任何面片进头，因此不需要深度淡出。

- **星形火核**：
  - billboard，0.16 m，`shape=STAR`（6 道带噪声的尖刺）。
  - 实例参数 `spin`：每枪随机旋转。
  - 顶点沿视线朝相机推 `view_offset` 0.06。焦点机位里，枪口正好在头的轮廓边上，推近后火核盖在轮廓外侧；与头的交线落在轮廓上，看不出硬切。
- **沿枪管的十字面片**：
  - 两片互相垂直、平面都包含枪管轴线的四边形，以枪口为中心。
  - 轴向范围：往后（枪口局部 +Z）0.06，朝头（−Z）最多 `GUN_CLEARANCE` 0.008；径向 ±0.07。
  - 枪口离头表面正好是 `gun_clearance + 0.008`，所以面片上每一点离头心都不小于物种净空，几何上插不进头。
  - `shape=CROWN`：枪口点最亮，沿**垂直于枪管**的方向冠状喷开，对应接触射击时气体从枪口四周径向喷出。
  - 不做 billboard，双面（`soft_particle_add` 已是 `cull_disabled`）。
- **火花**：
  - 方向改为枪口局部 `Vector3(0, 0, 1)`：沿枪身往后，远离头。spread 70°，其余不变。
  - 现在 `fx.gd:57` 把全局方向 `-xform.basis.z` 传给 `ParticleProcessMaterial.direction`，而发射器挂在 `global_transform = xform` 的 root 下（`fx.gd:47`），初速度方向会被发射器变换再转一次。需要在 flash 截图里核实。
- **节点顺序**：root 下依次是 OmniLight、火核、十字面片、火花，满足 `test_fx.gd:37-43`。
- **硝烟**（`fx.gd:66-80`）：
  - 数量和寿命不变（22 个、2.8 s，`table_director.gd:207`）。
  - 旋转：`angle` ±180°，角速度 ±30°/s。
  - 材质仍是受光的 `StandardMaterial3D`（不新增 shader），设置如下：
    - `BILLBOARD_PARTICLES`：自动读粒子 angle。
    - `TRANSPARENCY_ALPHA`，顶点色作 albedo，`CULL_DISABLED`。
    - `proximity_fade_enabled = true`，`proximity_fade_distance = 0.08`，与头和桌面相交处软过渡。
    - `albedo_texture` 用 `Fx._smoke_texture()`：代码生成的 64×64 絮团图（`FastNoiseLite` fbm × 径向衰减），缓存一份。
  - 随年龄淡出仍用现有的 `color_ramp` 和 `scale_curve`。
  - 登场 / 离场烟尘（`patron_3d.gd:506,510`）共用这套材质，外观一起变成絮状。
- **`soft_particle.gdshaderinc`**（`:1-21`）只新增以下参数，**不引入深度纹理**：
  - uniform：`shape`（int，0 = 现在的圆点）、`billboard`（bool，默认 true）、`view_offset`（默认 0）。
  - 实例参数：`instance uniform float spin`（默认 0）。
  - 默认值下，火星的代码路径和输出逐像素不变。
  - `test_fx.gd:54-58` 检查的是 `.code`，不展开 include，所以不受影响。
- **缓存**：`Fx` 新增 `_materials`、`_meshes`、`_smoke_texture` 三个缓存，替代每次调用都新建（`fx.gd:129-150`），由 `clear_cache` 一并清空。
- **成本**：稳态 0。开枪时多 1 次 draw（十字面片），持续 0.17 s。硝烟存在的 2.8 s 内，渲染器为 proximity fade 多拷一次深度。
- 可选，不进验收：转轮前缝的小火星、命中后的枪口余烟。

## 9. 吧台啤酒杯（③-4）
- `PropModels.mug()` 有两个 surface：
  - wood:mug：微鼓杯身，高 0.12。
  - prop：铁箍、C 形把手、泡沫穹顶带溢流。泡沫**不自发光**（`tavern.gd:328`，①V4 已改）。
- 三角形 824 / 个。
- 4 个杯子合成 `Bar/Mugs` 一个 `MultiMeshInstance3D`（不投影），替代 12 个实例（`:306-307,326-331`）。
- 位置沿用同一条 rng 序列（种子 2026，`:293-294`）。每杯的随机偏航放在 4 个位置都取完之后再取，位置因此不变。
- 台面高度写成常量 `MUG_Y` = 1.11，④改吧台时只改这一个数。
- 桌上不放每座一杯。

## 10. 预算
基准是②发版时的状态（①已做 F1/F2/F4/F7/F8/V7）。dc 是 seat 视角可见 + 阴影的估算，以探针实测为准。

| 道具 | ②发版时 | ③后实例（surface） | ③后 tri | seat dc 增量（估） | 材质增量 |
|---|---|---|---|---|---|
| 左轮 ×4 | 每把 3 实例、共享，约 2.7k/把 | 每把 3 个（Body 2 + Drum 1 + Hammer 1），共享 | 4–6k/把（≤ 8k） | +2~+5（Body 多一个木纹 surface） | −1（gunmetal） |
| 卡牌 ×20 | 40 实例，共享 2 个四边形、5 材质 | 20 个（1），1 网格 1 材质 | ≤ 160/张 | −8~−20 | −4 |
| 目标架 | 3 实例 | 2 个（底座 2 + 夹子 1） | 1.1k | 0~+1 | 0 |
| 烛台 | 2 碟 + 10 件 + 5 火焰，2 灯 | 2 个 + 5 片火焰，2 灯 | 4.6k | −5~−8 | −1（蜡的自发光） |
| 牌桌 | 7 实例 | 2 个（4 + 1） | 8.2k | −4~−8 | +1（turned） |
| 吊灯 | 4 实例 | 1 个 + 1 MultiMesh，不投影 | 6.5k | −5~−11 | −2（珐琅灯罩、灯泡自发光） |
| 啤酒杯 | 12 实例（共享 3 种网格） | 1 MultiMesh（2），不投影 | 3.3k | −2~−3 | 0（+mug −泡沫） |
| FX | 每次新建 | 缓存 | — | 稳态 0；开枪时 +1，持续 0.17 s | 0 |
| prop 材质 | — | — | — | — | +1 |

**合计**：
- draw call：seat 约 −20~−45。
- 道具 MeshInstance3D：约 97 个 → 约 45 个 + 2 个 MultiMesh。
- 三角形：可见约 +25~+33k，阴影约 +25~+45k；seat 渲染图元仍远低于 400k。
- 唯一材质：净 −5~−6。
- 新 shader 文件：1 个（prop）。
- 灯：不变（烛光 5→2 归①的 V7）。
- 帧时间：估计在 ±0.1 ms 以内；去掉 `discard` 为负，三角形为正。
- 启动：约 +30–40 ms（主线程同步建道具 ≤ 25 ms，另加 5 个烫金视口和数组），③份额上限 60 ms。
- 显存：+5.3 MB。

## 11. 测试
新增和扩展的测试见 tests 字段。

现有测试只有一处可能要改：`tests/test_perf_budget.gd:21-25`，前提是②没把 LIMITS 改成最终上限，处理办法见依赖②。下面这些原样通过：
- `test_revolver_3d` 两条
- `test_patron_arms.gd:94-109`：用普通 Node3D 当枪，新流程只读 `Revolver3D` 的常量
- `test_hand_visibility`
- `test_table_world`
- `test_fx` 四条
- `test_seat_layout`
- `test_scene_census`

如果实现中发现别的测试必须改，按「保留原意」规则逐条列出并说明。

预算类测试用 `tools/scene_census.gd` 计数。需要整间酒馆的测试直接 `Tavern.new()`，无头可建，实测 20 ms。

## 12. 截图核对
- 用 `tools/shot.gd --showcase` 拍 gun、selfshot、closeup、opponent、seat、overhead、menu、bar，与 `shots-before` 和②发版截图对比。
- 新增开发机位放进 `tools/camera_views.gd` 的 `place()`，但不加入 `NAMES`，免得探针多跑：
  - `gunrest`：静置左轮特写
  - `fan`：自己的手牌
  - `candles`
  - `stand`
  - `lamp`
  - `reveal`
  - `flash`
- `flash` 在 `shot.gd` 里特殊处理：
  1. 摆好机位，预热 45 帧（`shot.gd:8,34`）。
  2. 调 `showcase.fire()`：对第 4 位手里的枪调 `Fx.muzzle_flash` 和 `Fx.smoke_puff`，参数同 `table_director.gd:206-207`。
  3. 等 2 帧，截 `flash.png`。
  4. 再等 0.6 s，截 `smoke.png`。
- 用 `--stats` 看蜡身、灯罩内壁和脸部的削顶比例。

## 涉及文件
src/world/mesh_forge.gd(多 surface、glow 通道、raw、extrude 倒角;①已有的只补测试)
src/world/prop_models.gd(新:左轮/卡牌/目标架/烛台/牌桌/吊灯/链节/啤酒杯网格,缓存,TABLE_PROFILE,prewarm)
src/world/shaders/prop.gdshader(新,③唯一新增的 shader 文件)
src/world/shaders/soft_particle.gdshaderinc(shape/billboard/view_offset/instance spin,不引入深度纹理)
src/world/shaders/card.gdshader
src/world/materials.gd(prop()、PALETTE、wood 预设 turned/mug)
src/world/revolver_3d.gd(新几何、HOLD_OFFSET、REST_ROLL/REST_HALF_WIDTH、TABLE_REST_ROLL/TABLE_REST_LIFT、aligned_angle)
src/world/card_3d.gd
src/world/card_faces.gd(烫金遮罩、数组纹理、chamber_points、clear 释放数组)
src/world/card_table.gd(Spinner、回弹补偿、pile_transform/reveal_transform;可选 FAN_LAYER 与 bend)
src/world/seat_layout.gd(FELT_RADIUS;FELT_TOP 若①未加)
src/world/tavern.gd(_build_table/_build_lamp/_build_candles/_candle/_build_bar/_mug;烛台枢轴 Candles1/Candles2)
src/world/fx.gd(火花方向、十字面片、星形核、StandardMaterial3D 硝烟、缓存)
src/world/patron_3d.gd(GUN_APPROACH、gun_hand_target、gun_aim、pick_up 清视线、raise_gun_to_head、lower_gun、die、reset_pose)
src/world/patron_parts.gd(gun_clearance 字段,若②未加)
src/world/table_world.gd(revolver_rest 用 TABLE_REST_*)
src/ui/main.gd(main.gd:51 前调 PropModels.prewarm;_exit_tree 清 MeshForge/PropModels 缓存,若①未覆盖)
tools/camera_views.gd(开发机位 gunrest/fan/candles/stand/lamp/reveal/flash,不进 NAMES)
tools/shot.gd(flash 机位的开枪与两次截图)
tools/showcase.gd(fire())
tools/perf_budget.gd(LIMITS 改为全部完成后的上限,若②未改)
tests/test_perf_budget.gd(21-25 行同步新上限,若②未改;保留原意)
tests/test_revolver_3d.gd
tests/test_gun_hold.gd(新)
tests/test_table_props.gd(新)
tests/test_card_3d.gd(新)
tests/test_card_faces.gd(新)
tests/test_prop_models.gd(新)
tests/test_fx.gd
tests/test_mesh_forge.gd(补)
build.json(版本号)

## 测试
tests/test_revolver_3d.gd 保留两条，新增 test_a_chamber_lines_up_with_the_barrel_after_cocking_and_spinning：cock_hammer(0.05) 结束后、spin_drum(0.05, 2.37) 结束后，都各有一个 Chamber 标记在枪本地满足 |x|<0.5mm 且 |y−BARREL_Y|<0.5mm
test_drum_mesh_is_five_fold_symmetric：Drum 网格每个顶点绕 Z 转 TAU/5 后，都能在 0.1mm 内找到原有顶点（用空间哈希）；Drum 下除 5 个 Marker3D 外没有别的节点
test_guns_share_meshes_and_stay_in_budget：两把 Revolver3D 的 Body/Drum/Hammer 是同一网格资源；用 SceneCensus 数，每把 3 个 MeshInstance3D、合计 4 个 surface、三角形 ≤8000
test_rest_constants_match_the_mesh，按网格顶点求：REST_ROLL 下转轮最低点与底帽最低点高差 ≤0.5mm，最低点高度等于 REST_HALF_WIDTH（±0.5mm）；TABLE_REST_ROLL 下转轮最低点比底帽最低点高 FELT_TOP−TABLE_TOP（±0.5mm），转轮最低点高度等于 TABLE_REST_LIFT（±0.5mm）；MUZZLE_POS 在枪口冠前方且 |z|≤0.27
tests/test_gun_hold.gd test_muzzle_rests_on_the_temple_for_every_species：对 PatronParts 的 8 个物种，用 Patron.new(i) 加真 Revolver3D，按导演流程先 look_at_point(head_position())，再 pick_up→raise_gun_to_head，等 0.5s。断言 R+0.002 ≤ |枪口−head_position()| ≤ R+0.025（R = gun_clearance，缺省 0.17），枪管轴线离头心 ≤0.01；之后 1.5s 内头心漂移 ≤5mm
test_gun_never_enters_the_head：同样的设置下，取枪口冠中心、准星顶点、枪管上沿每 1cm 一个采样点。把点变换到头部子树每个 MeshInstance3D 的局部，沿 +X 发射线，与 mesh.get_faces() 的交点数为偶数（在网格外）。8 个物种都测；耳朵 rotation.x 减 0.3 后再测一遍
test_gun_hand_target_reaches_the_wanted_distance（纯函数）：clearance 取 0.14–0.22 时，解都在离 SHOULDER 0.4 的球面上（±1e-4）；按名义头心 C0 算出的枪口距离误差 ≤1mm；手高于肩
test_hand_rotation_resets_after_lowering_and_dying：lower_gun 后、die 后，right_hand.quaternion 都约等于单位四元数，right_hand.position 仍为 (0,0,-0.4)
tests/test_table_props.gd test_resting_guns_lie_on_felt_and_table：2/3/4 人局，每把静置枪的转轮顶点最低点 = FELT_TOP（±0.001），握把底帽顶点最低点 = TABLE_TOP（±0.001），由网格顶点精确计算
test_dropped_gun_lands_on_the_floor：die(gun, world) 后 1s，最低顶点 ∈ [−0.001, 0.004]，离座位原点的水平距离 ≥0.3（回归 y=0.60 悬空的 bug）
test_resting_guns_clear_candles_and_reveal_row：2/3/4 人局，静置枪的顶点在 XZ 平面上离两个烛台中心 ≥0.11，离 3 张翻牌的矩形 ≥0.02
test_pile_and_reveal_cards_sit_above_the_felt（纯函数）：pile_transform(i<30, seed<20) 与 reveal_transform 得到的牌底（origin.y−THICKNESS/2）≥ FELT_TOP+0.0002，且相邻两层不相交
tests/test_card_3d.gd test_card_is_one_shared_slab：每张牌 1 个 MeshInstance3D；两张牌共享网格和材质；AABB = WIDTH×THICKNESS×HEIGHT（±0.1mm），厚度 ≤0.9mm
test_kind_and_both_faces_are_instance_params：set_kind 写 face 实例参数，set_both_faces 写 face 和 both_faces；新牌不设参数时 face 为牌背层；ray_hit_distance 中心射线命中、牌边外不命中
（仅在做 ③-2b 手牌弯曲时）test_fan_neighbours_never_intersect（纯数学）：手牌数 2..8，按 CardTable.fan_slot 与 Card3D.bend_offset(HAND_BEND) 采样，前一张的正面始终在后一张背面之后 ≥0.2mm；test_cards_leaving_the_hand_are_flat：play、gather_for_reveal、sweep、drop_held 之后 bend 都是 0
tests/test_card_faces.gd test_back_has_one_hole_per_chamber：chamber_points().size() == Revolver.CHAMBERS，且第一个点在正上方
test_headless_build_binds_arrays：无头 build 后 face_array()/foil_array() 都是 5 层，并已绑定到 Card3D 的共享材质；texture(kind) 仍返回 Texture2D；test_clear_releases_the_arrays：CardFaces.clear() 后两个数组都换回替代图
test_only_the_clip_spins：CardTable 跑若干帧后，TargetStand 的旋转不变、Spinner 的旋转改变；stand_position() == TABLE_TOP+STAND_HEIGHT；目标牌是 Spinner 的子孙节点；set_target 回弹期间牌底不低于夹子叶片底端
tests/test_prop_models.gd test_table_top_is_closed_and_flat：在 r∈[0,0.98] 内每 1cm、每 5° 向下发竖直射线，都击中牌桌网格朝上的三角形；r≤0.98 处高度为 TABLE_TOP（±0.0006，毡面下的部分可再低 2mm）；桌布顶面 = FELT_TOP（±0.0003）；桌腿顶点 r≤0.5
test_table_clears_every_torso：8 个物种分别 Patron.new(i)，set_active(true) 后等 1.2s，Body 子树（不含手臂、头、牌扇）顶点到 PropModels.TABLE_PROFILE 的 (r, y) 距离都 ≥0.015
test_candle_holders：无头 Tavern.new() 后，恰有 Candles1、Candles2 两个枢轴，各恰有 1 盏 OmniLight3D 作为直接子节点；_flickers 里的烛光正是这两盏；火焰共 5 片；网格 xz 半宽 ≤0.09；角度为 0.76π 和 1.31π
test_lamp_parts_hang_under_the_pivot：灯罩、链条 MultiMesh 是 LampPivot 的子孙，两盏灯的直接父节点是 LampPivot；链节实例数 ≥40；灯罩和链条都不投影
test_cameras_see_under_the_shade（纯数学）：overview/third_person/lobby 三个机位到 2/3/4 人局各座位默认头部位置的线段，凡在灯罩半径加摆幅余量范围内的部分，高度都比罩最低点低 ≥0.05m
test_bar_mugs_are_one_multimesh：Bar 下有 1 个 MultiMeshInstance3D，4 个实例，不再有啤酒杯 MeshInstance3D
test_prop_budgets（用 SceneCensus）：各道具的实例数和三角形数不超上限：枪 8k、牌 160、桌 12k、单个烛台 3k、目标架 3k、灯 7k、杯 1.5k
tests/test_fx.gd 保留四条，并新增：test_flash_and_smoke_materials_are_cached（两次 muzzle_flash/smoke_puff 用同一份材质和网格）；test_smoke_rotates_and_fades_softly（硝烟材质是 StandardMaterial3D，BILLBOARD_PARTICLES，proximity_fade_enabled 且距离为 0.08，angle 范围 ≥180°）；test_flash_stays_outside_the_head（十字面片网格所有顶点在枪口局部 z ≥ −0.008；火花 ParticleProcessMaterial.direction == Vector3(0,0,1)）；test_shared_particle_include_has_no_depth_texture（用 FileAccess 读 soft_particle.gdshaderinc 原文，不含 hint_depth_texture）
tests/test_mesh_forge.gd 补充：多 surface 数量正确；glow 写入 UV；color 按线性色写入；extrude 带倒角后法线为单位长度，AABB = 轮廓外框 × 深度

## 预算影响
以②发版为基准（①已做 F1/F2/F4/F7/F8/V7），全部为估算，验收以 perf_probe 实测为准。
- draw call：seat 约 −20~−45。主要来自卡牌 5 个材质合成 1 个、吊灯和啤酒杯不投影、烛台和牌桌合并；左轮因为 Body 多一个木纹 surface，反而 +2~+5。
- 道具 MeshInstance3D：约 97 个 → 约 45 个 + 2 个 MultiMesh。
- 三角形：可见约 +25~+33k，阴影约 +25~+45k，seat 渲染图元仍远低于 400k。单把左轮 3 个实例、4–6k 三角形（上限 8k）。
- 唯一材质：净 −5~−6。减少的有卡牌 5→1、gunmetal、珐琅灯罩、灯泡自发光、蜡的自发光；新增 prop、turned、mug。
- 新 shader 文件：只有 1 个（prop.gdshader），满足总规格「新增 spatial shader ≤ 4」。
- 灯：不变；烛光 5→2 归①的 V7，若①未做由③补做。投影灯数不变。
- 帧时间：估计变化在 ±0.1 ms 以内，需 ≤10.0 ms。共享粒子 include 不引入深度纹理，FX 稳态 0；开枪时 +1 draw，持续 0.17 s；硝烟存在的 2.8 s 内多一次深度拷贝。
- CPU 渲染线程：略降。
- 启动：约 +30–40 ms，③份额上限 60 ms。其中主线程同步构建牌桌、烛台、吊灯、杯子 ≤25 ms；另有 5 个烫金遮罩视口和数组；左轮在 WorkerThreadPool 里与卡面构建并行。
- 显存：约 +5.3 MB。

## 验收
无头全量 GUT 通过，并核对测试脚本数等于 tests/ 下的文件数，防止解析失败的脚本被静默跳过；③新增的测试全部在内
perf_probe --cases=budget --assert-budget（M3、1080p、300 帧×3 次取中位，LIMITS 已是全部完成后的上限）：帧时间 ≤10.0 ms；seat draw call ≤700（硬上限 900），且不超过②发版实测 +10；menu ≤800；closeup/gun/opponent 不高于②发版；CPU 渲染线程 ≤1.0 ms
SceneCensus 清单：每把左轮 3 个实例、≤8k 三角形；唯一材质 ≤40；灯 ≤16 盏，其中投影 ≤3 盏；四把枪和全部卡牌各自共享同一网格资源；③只新增 prop.gdshader 一个 shader 文件
启动时间相对②发版增加 ≤60 ms（③份额），整个美化累计 ≤+200 ms；预建后 Revolver3D.new() ≤1 ms、Card3D.new() ≤0.2 ms（无头计时脚本，20 次取中位）；已缓存物种的生成 ≤16 ms 不受影响
gun 截图，8 个物种各一张目检：枪口贴在太阳穴外，不插进头、耳朵或帽檐；转轮、击锤、护圈、胡桃木握把都能辨认；握枪拳头的腕口不露缝
seat/gunrest 截图：4 把静置左轮读得出是左轮，转轮压在毡面上、底帽落在木桌面上，不悬空也不陷桌；手牌有厚度和烫金边，牌扇内没有 z-fighting 或穿插
closeup/stand/candles 截图：目标架只有夹子在转，翻面回弹时牌不插进立轴；烛台有烛杯、熔口、烛芯、蜡泪；--stats 显示蜡身削顶 ≤5%，脸部削顶 ≤5% 且不高于②发版
menu/overhead 截图：牌桌有圆鼻边、瓶状柱、爪足；桌下地板是暗的，吊灯光没有穿过台面；椅子和②的腿脚不与桌沿穿插。lamp 截图：灯罩为绿/奶油双色，内壁削顶 ≤5%，灯泡是有高光的球而不是平白盘，链条可见；等待厅和观战机位都能看到对面玩家的脸。bar 截图：啤酒杯可辨
flash/smoke 截图：星形火核和冠状火焰出现在太阳穴外侧，火花沿枪身往后喷，不钻进头；头上没有硬切线；硝烟呈絮状、会旋转，与头和桌面相交处是软过渡
游戏红线：五个弹膛外观一致（对称测试通过），每次转动和扳击后都有一个弹膛对准枪管；协议版本仍为 v5，没有新增网络消息
退出游戏时没有 ObjectDB 泄漏告警；无头的 TableWorld.new(null) 和 Tavern.new() 测试不报渲染接口错误
fireplace 视角像素对比：火星外观不变，验证 soft_particle include 的默认参数兼容；浮尘本来就不走这个 include

## 决策(均按推荐默认采纳)
左轮截面加粗约 1.24 倍、长度不变，并重调举枪手位（设计默认，尚未确认）。推荐：同意。枪口离握持点 0.259，静置时离翻牌行仍有 3.4 cm
牌面美术只做奶油边、烫金和 5 孔牌背，不画动物宫廷肖像（设计默认，尚未确认）。推荐：同意
桌上不放每座一杯啤酒和筹码，啤酒杯只放在吧台（设计默认，尚未确认）。推荐：同意
运行时用 SubViewport 绘制的贴图（牌面和烫金遮罩）算作程序化美术（设计默认，尚未确认）。推荐：允许，现有卡面已经这样做
保留 ACES 暖色调、靠降曝光压过曝（设计默认，尚未确认）。③的调色板按 ACES 调；改用 AgX 时要重调 PALETTE 这一张表。推荐：保留 ACES
弹巢后端不显示弹壳，前端只显示 5 个一模一样的暗孔。推荐：不显示，显示 5 个弹壳会让玩家误以为满膛
中弹后左轮掉在椅子右侧地上，还是落回桌面（现在是悬在 0.6 m 半空的 bug）。推荐：掉在地上，和人往后瘫的动作一致，观战俯视时也看得到

## 风险
①的 MeshForge 若缺 lathe/extrude/tube/loft 或多 surface，③-0 要补上（约 +1–2 天）；与②并行时接口可能冲突，应先合入 ③-0 再开 ③-1
②必须给 8 个物种提供 gun_clearance（含耳朵和帽子）。缺了就用 0.17，猴子的侧耳、羊驼的长耳或②新做的宽帽檐可能被枪管穿过；穿模测试会拦住，但需要②配合调数据
「转手不转枪」时手相对手臂约转 135°，②的握枪拳头若与 HOLD_OFFSET 不匹配或腕口外露，会显得像折腕；要在 gun 特写里目检，可能要把 HOLD_OFFSET 微调 ±5 mm / ±5°，或加大袖口毛圈
牌桌台面外扩约 5 cm 到 r 1.002；②的胸前外廓在 TURN_LEAN 下离圆鼻边只有约 2.5 cm。外廓测试不过时，把圆鼻外沿收到 0.995
Forward+ 自动实例化依赖渲染排序，4 把枪或 20 张牌不一定各合成一个 draw，以探针实测为准。卡牌如未达标可改 MultiMesh，但手牌各有动画，要付出逻辑改动的代价
火花方向依赖 ParticleProcessMaterial 的方向在发射器局部这一行为，需用 flash 截图核实；如果实际是全局方向，就改传 xform.basis.z
星形火核不用深度淡出，靠 view_offset 和枪口位于头轮廓边上来避免硬切；②若明显改变头形，可能要把 view_offset 调到 0.05–0.08
修改 soft_particle.gdshaderinc 会影响壁炉火星；默认 uniform 必须保持旧输出，用 fireplace 视角像素对比验证
硝烟改为絮状后，登场 / 离场烟尘也一起变样；需要在等待厅截图确认观感
吊灯最低点下降约 2 cm；等待厅机位余量最紧（≥0.11 m），需截图确认踢灯摆动时也不挡脸
蜡烛的透光 BACKLIGHT 与①的曝光叠加可能重新削顶，需用 --stats 校验 ≤5%
卡面数组纹理多约 5 MB 显存，启动多 5 个视口；低端机启动若明显变慢，可把烫金遮罩降到 90×130
④改吧台台面高度时必须同步改 MUG_Y；③在 tavern.gd 里重做吧台相关代码，可能与④的 R5 冲突，应按发版顺序合并
WorkerThreadPool 预建左轮与 cached() 的等待逻辑要处理测试里同步取用、退出时任务未完成两种情况；退出前先等任务完成再 clear_cache，避免 ObjectDB 泄漏
