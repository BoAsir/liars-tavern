# 共享技术架构 + 子项目① 地基与观感修正

> 子项目详细设计。总纲见 `2026-10-07-visual-overhaul-design.md`;冲突时以总纲第 3 节「已定决策」与第 4 节「裁定」为准。
> 状态:已确认(用户授权自审)。本文由设计 agent 起草、对抗性复核修正;文中「实测」数据来自 scratchpad 原型,未入库。

## 0. 依据:design_lab 实测

所有实验都在仓库副本上跑(`scratchpad/design_lab/repo/lab/*.gd`,日志在 `design_lab/*.log`),仓库本身没有改动。

环境:Apple M3 / Metal / SubViewport 1920×1080 / `RenderBudget.apply`,场景是 showcase(4 名酒客、手牌、左轮,第 4 位举枪)。draw call 都在**正常推进的帧**里读:酒客在呼吸、吊灯在摆,阴影每帧重画,和游戏一致。

下文凡是写**预计**的数字都是推算,由对应批次的清单或工具确认;只有写**实测**的才有日志。

**表 0-1 逐级改造后的 draw call(可见 + 阴影),来自 stage_probe**

| 视角 | 基线 | B1(网格缓存 + 小件/墙地不投影) | B1 + 月光 caster mask | B2(酒客按枢轴合并、共享椅子、左轮三件、酒瓶 MultiMesh) |
|---|---|---|---|---|
| seat | **1798**(585+1213) | 825 | 665 | **387**(155+232) |
| menu(showcase) | 1940 | 892 | 738 | **401** |
| opponent | 594 | 314 | 246 | 189 |
| overhead | 1531 | 674 | 523 | 337 |
| closeup | 711 | 388 | 291 | 232 |
| bar | 1255 | 617 | 467 | 230 |
| gun | 570 | 337 | 273 | 195 |
| selfshot | 729 | 352 | 289 | 184 |
| window | 1494 | 676 | 524 | 358 |
| fireplace | 238 | 164 | 122 | 109 |

**B2 原型的清单(实测)**

- 可见 MeshInstance3D 从 733 降到 490。
- 每名酒客 19 个实例(含椅子)。材质 "4mat":含椅子木纹,原型没共享火焰和粒子材质。
- 投影物从 730 降到 266;场景唯一材质 90 → 55。
- seat 视角 CPU 渲染线程从 0.81 ms 降到 0.41 ms。
- 原型和本设计的差别:原型的瓶子是 1 个 MultiMesh,本设计按瓶型分 6 个(+≤5 dc);原型没做火焰和粒子材质共享(本设计 −18 个材质);原型的高光保持自发光。

**帧时间(实测)**:seat 视角,强制阴影重画,取中位数。

- 基线:9.53 / 9.61 / 9.62 ms。
- ①终态(B2 + 烛光 5→2 + `ssao_light_affect` 0.35):9.06 / 9.09 / 9.12 ms,约 −0.5 ms。
- 测量时没有其他 Godot 进程在跑。

**表 0-2 其他实验**

| 实验 | 结果 | 设计结论 |
|---|---|---|
| merge_diff:冻结画面,酒客按枢轴合并,用原型 `patron.gdshader`,木纹走 `use_part_space` | 5 个视角里,平均差 ≤ 0.29/255;差值 >2/255 的像素 ≤ 0.013%,>8/255 的 ≤ 0.004% | 合并能做到像素一致,顶点布局和着色器写法经过验证(A2、A3) |
| chair_diff | 用 `ShaderMaterial.duplicate()` 做木纹变体,平均差 1.46/255,15% 的像素差值 >2;改成新建材质加 `use_part_space`,平均差 0.09/255 | **严禁用 duplicate() 复制 ShaderMaterial 来做变体** |
| arrays_time(窗口模式,Metal) | `PrimitiveMesh.get_mesh_arrays()` / `surface_get_arrays()` 每次约 1.2–1.3 ms(从 GPU 回读);GDScript 复刻 SphereMesh 每次 0.1 ms,顶点误差为 0 | 游戏代码**不能在运行时读网格数组**。MeshForge 自己复刻 Godot 的基础体算法 |
| worker_test(无头) | 工作线程里新建 `CylinderMesh` 报 "Initializing already initialized RID";主线程用 `wait_for_group_task_completion` 阻塞时,工作线程碰网格会死锁;只算 Packed 数组时 60 个用 6.5 ms,正常 | 工作线程**只做纯数组运算**,网格资源一律在主线程创建 |
| forge_time(无头) | 4 个物种按枢轴合并,每人 19 组;合并 2.3–5.7 ms/物种,commit 0.3–0.7 ms;`ARRAY_CUSTOM_RGBA_FLOAT` 在无头下可用 | 启动预建的成本很小 |
| det_shot | `--fixed-fps 60` + `seed()` + 粒子固定种子 + 搭好后冻结,两个进程截的图**逐像素相同** | 可以跨提交做像素对比。体积雾的时间重投影要 ≥ 45 帧才收敛 |
| shadow_diff(冻结画面,各步单独对比) | 网格缓存:>2/255 ≤ 0.013%(噪声底)。小件 + **7 个房间壳件**(地板、三面墙的护墙板和灰泥,压条照常投影)不投影:>2/255 ≤ 0.94%,>8/255 ≤ 0.26%(最大在 fireplace 视角)。月光 mask:>2/255 ≤ 0.16% | 两档像素门槛的依据(见 B1)。B1.2 必须和这次实测的配置一致 |
| look_probe / stats_probe | 基线脸部"发白"(Rec.709 亮度 ≥ 0.85,ID 掩码):猪 63–77%,狐狸 29%。v9 方案:保持 ACES 1.32;**所有酒客材质,包括眼白**,按最大通道等比压到 ≤ 0.65;烛光 5→2;ssao 0.35。v9 下猪脸发白 ≤ 1%(圆形区域测法),整帧平均亮度不变(opponent 0.395→0.398)。把曝光降到 1.0–1.1 会让整间屋子暗 14–16%。灰泥 32px 小块的亮度标准差中位数 3.6–5.4,整片 24–30 | B3.1 调色方案的依据 |
| **review_look(评审补测,同一套测量)** | 眼白恢复成 0.80、其余照 v9:猪脸发白升到 5–6%(opponent 6%、seat 5%、closeup 6%)。爪子在 v9 下仍过曝:猪爪发白 10–33%(v9 原日志为 34–44%)。爪子颜色 ×0.8 后:猪爪 0/0/0%。只把吊灯 spot 降到 2.8:猪爪仍有 22–30% | **眼白用 0.65 档**;爪子加 `PAW_SHADE` 0.8;去过曝的验收必须同时看脸和爪(B3.1) |
| handvis_merged | 4 个物种头部按枢轴合并后,包围盒并集挡住手牌的比例都是 0% | 合并不会让 `test_hand_visibility` 失败 |
| gun_check(无头) | 平放的枪陷进桌面 13 mm;举枪时枪口在头球里 2–7 mm;倒地时枪掉在 y=0.600、离桌心 1.224 m,即桌外半空;扳击加转动后停位离整格差 1.068 rad;Chamber1 在 (0.0145, 0),位于枪管右侧 | B3.6 的 bug 合集 |
| **review_check(评审补测,无头)** | `Tavern.new()` 在无头下能建,灯 18 盏、投影 3 盏。平放时转轮中心离桌心 **0.807 m**,在毡面半径 0.82 以内:按 TABLE_TOP+0.026 摆放,转轮最低点 = TABLE_TOP,比毡面顶低 4 mm。手位 x=0.355 时,枪口到头心 0.182–0.187 m。草案的倒地落点离桌心 0.864 m | 平放和倒地的高度都改用 FELT_TOP 为基准(B3.6) |

---

## A. 共享技术架构(四个子项目共用)

### A1. MeshKit 网格缓存(B1 落地)

现在每调用一次就新建一个 PrimitiveMesh(`src/world/mesh_kit.gd:26-91`):749 个实例对应 715 份网格,Forward+ 的自动实例化从来触发不了。

**改动(`src/world/mesh_kit.gd`)**

```gdscript
const CAPS_NONE := 0
const CAPS_TOP := 1
const CAPS_BOTTOM := 2
const CAPS_BOTH := 3
const SHADOW_AUTO := -1          # 最大边 < SMALL_CASTER 时不投影
const SHADOW_OFF := 0            # 与 GeometryInstance3D.SHADOW_CASTING_SETTING_* 取值一致
const SHADOW_ON := 1
const SMALL_CASTER := 0.08       # 米
const LAYER_WORLD := 1           # 位值 1 = 编辑器第 1 层:所有物体的默认层
const LAYER_MOON := 4            # 位值 4 = 编辑器第 3 层:只给窗框 + 窗墙,月光只让它们投影(A4)
static var _cache := {}          # key -> Mesh(只读,永不修改)

static func add(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scale := Vector3.ONE, shadow := SHADOW_AUTO) -> MeshInstance3D
static func box(size: Vector3) -> BoxMesh                        # 其余基础体签名不变
static func cylinder(top_radius: float, bottom_radius: float, height: float, segments := 32,
		caps := CAPS_BOTH) -> CylinderMesh                         # 新增 caps,代替 tavern.gd:184 的 cap_bottom 改写
static func hemisphere(radius: float, segments := 24) -> SphereMesh # 独立 key,直接建,不再改 sphere() 的结果
static func clear_cache() -> void
static func audit_cache() -> PackedStringArray                     # 按网格当前属性重算 key,和存的 key 对不上的列出来(检测改写)
```

**key 和量化**

- key 由类型和参数拼成,例如 `"box:1200,600,2200"`、`"cyl:70,360,2000,48,1"`。
- 浮点参数按 `roundi(x * 10000.0)` 量化到 0.1 mm;整数参数原样拼入。
- 工厂函数**用量化后的值**(`q / 10000.0`)建网格,结果与调用顺序无关。和现状的几何差最多 0.05 mm,实测像素差在噪声底。

**只读规则**

- 缓存里的网格永远不改。需要变体就加参数(caps、hemisphere 等)。
- 全仓只有两处改写:
  - `tavern.gd:183-184` 的 `cap_bottom = false`,改为 `MeshKit.cylinder(0.07, 0.36, 0.2, 48, MeshKit.CAPS_TOP)`。
  - `mesh_kit.gd:51-55` 的 hemisphere 会改 sphere() 的结果。改成直接新建 SphereMesh,用 key `"hemi:…"`,照抄原规则:`radius = r`、`height = r`、`radial_segments = segments`、`rings = maxi(segments / 2, 6)`(同 `mesh_kit.gd:47`)、`is_hemisphere = true`。少一项就破坏像素一致。
- 不准给缓存网格设 `mesh.material`。粒子用的 QuadMesh 由 `Fx` 自己建(`fx.gd:129-150`),不走 MeshKit。

**SHADOW_AUTO 怎么算**

- 投影尺寸 = `(Transform3D(Basis.from_euler(rot_deg 转弧度) * Basis.from_scale(scale)) * mesh.get_aabb()).size` 的最大分量。
- 只用节点**自身**的变换,不含父节点缩放;所以登场动画的 0.01 缩放(`patron_3d.gd:503`)不影响判断。
- `PrimitiveMesh` 和 `ArrayMesh` 的 `get_aabb()` 都在 CPU 上算,不回读 GPU。
- 显式传 `SHADOW_ON` / `SHADOW_OFF` 会覆盖自动判断。显式 `SHADOW_ON` 的小件同时 `set_meta(&"force_shadow", true)`,供预算测试豁免。

**适用范围与清理**

- 适用于单个、未合并的部件,以及 Card3D 的牌面(B1)。需要顶点色或合并的物体一律走 MeshForge。
- `MeshKit.clear_cache()` 放进 `src/ui/main.gd:82-88`。

### A2. MeshForge 合批构建器(B2 落地核心,②③④扩展原语)

**分层**

1. 配方 `recipe: func(f: MeshForge) -> void`,只用 MeshForge 的方法加数学运算。
2. `f.build()` 输出 `{surface_name: arrays}`,纯数据,**可以在工作线程跑**。
3. `MeshForge.commit(built, materials)` 生成 `ArrayMesh`,**只在主线程调用**。
4. `MeshForge.cached(key, recipe, materials)` 按 key 共享。

**新文件 `src/world/mesh_forge.gd`**

```gdscript
class_name MeshForge
extends RefCounted
# 合批构建器:把多个部件写进同一组顶点数组(纯 CPU,可在工作线程跑),主线程 commit 成共享 ArrayMesh。
# 布局:COLOR.rgb = sRGB albedo,COLOR.a = 烘焙 AO;UV2 = (roughness, metallic);CUSTOM0 = (部件局部坐标 xyz, 每件种子 w)。

# —— 绘制状态(作用于之后加入的部件)——
var color := Color.WHITE      # sRGB albedo,口径同 StandardMaterial3D.albedo_color
var ao := 1.0                 # → COLOR.a(①恒为 1)
var rough := 0.7              # → UV2.x
var metal := 0.0              # → UV2.y
var part_space := false       # true:CUSTOM0.xyz 写部件局部坐标(木纹等物体空间着色器)
var seed := 0.0               # → CUSTOM0.w;0 时与未合并的旧材质完全一致
func paint(c: Color, r: float, m := 0.0) -> MeshForge
func surface(name: StringName) -> MeshForge          # 切换/新建 surface(一个 surface 一个材质槽、一次 draw)
func push(t: Transform3D) -> MeshForge
func pop() -> MeshForge
static func xf(pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D
	# = Transform3D(Basis.from_euler(rot 弧度, YXZ) * Basis.from_scale(scale), pos):与 MeshKit.add / Node3D 同口径

# —— 旧基础体:逐顶点复刻 Godot PrimitiveMesh(primitive_meshes.cpp),参数与 MeshKit 同名函数一致 ——
# ①只实现合并用得到的 7 种
func sphere(radius: float, segments := 24, t := Transform3D.IDENTITY) -> MeshForge
func hemisphere(radius: float, segments := 24, t := Transform3D.IDENTITY) -> MeshForge
func cylinder(top_r: float, bottom_r: float, height: float, segments := 32, caps := MeshKit.CAPS_BOTH,
		t := Transform3D.IDENTITY) -> MeshForge
func capsule(radius: float, height: float, segments := 20, t := Transform3D.IDENTITY) -> MeshForge
func box(size: Vector3, t := Transform3D.IDENTITY) -> MeshForge
func torus(inner: float, outer: float, segments := 32, t := Transform3D.IDENTITY) -> MeshForge
func prism(size: Vector3, t := Transform3D.IDENTITY) -> MeshForge
# —— 新几何:①只实现 lathe(酒瓶用);rounded_box/loft/tube/extrude/blob/displace/bake_ao 由②③④按同一布局追加 ——
func lathe(profile: PackedVector2Array, segments := 24, creases := PackedInt32Array(),
		t := Transform3D.IDENTITY) -> MeshForge          # profile:(r, y) 自下而上;creases 处复制顶点做硬边
# —— 输出 ——
func vertex_count() -> int
func build() -> Dictionary                                # {StringName: Array(Mesh.ARRAY_MAX)},线程安全
static func commit(built: Dictionary, materials := {}) -> ArrayMesh   # 主线程;materials: {surface 名: Material}
# —— 缓存与预建 ——
static func cached(key: String, recipe: Callable, materials := {}) -> ArrayMesh
static func prebuild(host: Node, jobs: Array) -> void     # jobs: [[key, recipe, materials], …];不 await 调用即后台进行
static func wait_prebuilt(host: Node) -> void             # 协程:等所有预建 commit 完
static func clear_cache() -> void                          # 先等在途任务结束,再清空
```

**表 A2-1 顶点数据布局**

| 数组 | 格式 | 含义 | 读取方 |
|---|---|---|---|
| `ARRAY_VERTEX` / `ARRAY_NORMAL` | float3 | 合并后所在枢轴空间里的位置 / 法线 | 全部 |
| `ARRAY_COLOR` | RGBA8 unorm | rgb 存 **sRGB** albedo,a 存 AO | patron / prop。8 位存线性色会让暗色误差达 25%,所以 rgb 一律存 sRGB,在着色器里转线性 |
| `ARRAY_TEX_UV2` | float2 | (roughness, metallic) | patron / prop |
| `ARRAY_CUSTOM0` | `ARRAY_CUSTOM_RGBA_FLOAT << ARRAY_FORMAT_CUSTOM0_SHIFT` | xyz:部件原始局部坐标(即旧 VERTEX);w:种子 | wood(`use_part_space`)。只在该 surface 有部件开了 part_space 时才写,省 16 B/顶点 |
| `ARRAY_INDEX` | int32 | 三角形索引 | — |

不写 UV 和 TANGENT,合并件用到的着色器都不需要。

**变换与法线规则**

- 位置用 `t * v`。
- 法线用 `(t.basis.inverse().transposed() * n).normalized()`,因为项目里父子缩放普遍是非均匀的。
- `t.basis.determinant() < 0`(镜像)时**翻转三角形绕序**。
- 缩放退化(行列式绝对值 < 1e-9)的部件直接跳过。
- 旧基础体的法线照搬 Godot 的算法,保证像素一致。lathe 用轮廓切线算解析法线,creases 处复制顶点。

**为什么要复刻基础体**:在 Metal 上读 PrimitiveMesh 的数组每次约 1.2 ms(GPU 回读),B2 的合并原型因此在窗口模式下花了 137–252 ms,而无头下只要 20 ms。复刻版是纯 GDScript,每个球约 0.1 ms,并且线程安全。

**commit / shadow_mesh / 多 surface**

- `commit` 对每个 surface 调一次 `add_surface_from_arrays(PRIMITIVE_TRIANGLES, arrays, [], {}, flags)`,再调 `surface_set_material(i, materials[name])`。
- 材质挂在网格资源上,共享网格的实例材质也相同,自动实例化照常生效。
- 用了 MeshForge 网格的 MeshInstance3D 不设 `material_override`(传 `null`)。
- `shadow_mesh` ①不启用。将来要启用,只能是"位置完全相同的焊接副本"(Godot 的深度预通道也会用它),不能当 LOD。

**缓存 key**

- `"chair"`
- `"patron:<species id>:<part>"`,part 见 B2.4 的表。②扩到 8 个物种时 key 规则不变。
- `"revolver:body"`、`"revolver:drum"`、`"revolver:hammer"`
- `"bottle:<profile>"`
- 同一会话内配方不变,不需要加版本号。

**无头安全**

- MeshForge 除了 `ArrayMesh.add_surface_from_arrays` 和 `surface_set_material` 外,不调用任何渲染接口。实测这两个在无头哑渲染器下可用。
- 测试用 `TableWorld.new(null)` 时,第一次用到某个 key 就在主线程同步构建。
- MeshForge 不引用任何 autoload(Net / Discovery / Settings / Sfx)或 DebugFlags,否则用 -s 启动的工具无法编译(`debug_flags.gd:41-43`)。

**工作线程预建**:`src/ui/main.gd:51` 的 `await CardFaces.build(self)` 换成下面三行。

```gdscript
MeshForge.prebuild(self, PatronParts.forge_jobs() + Revolver3D.forge_jobs())   # 不 await:与卡面生成并行
await CardFaces.build(self)
await MeshForge.wait_prebuilt(self)
```

- `prebuild` 给每个 job 建一个 `Job`(RefCounted,字段 `key/recipe/materials/task_id/built`),用 `WorkerThreadPool.add_task(…, false)` 投递。
- 工作线程只把结果写进**自己那个 Job**,不改共享容器。材质在投递前由主线程建好。
- `wait_prebuilt` 每帧 `await host.get_tree().process_frame` 轮询 `is_task_completed`。完成一个就**先调 `wait_for_task_completion(task_id)`**(此时立即返回,用来回收任务;Godot 要求每个任务都被 wait 一次),再 commit 进缓存。
- 如果 `cached(key)` 在预建完成前被请求:任务在途就调 `wait_for_task_completion`(纯数学任务,不会死锁)再 commit;没有任务就同步构建。
- 游戏里这条回退走不到:`--autohost` 等调试开关由 DebugFlags 处理,它在 `_show_menu()` 之后才创建(`main.gd:56-57`)。回退只在 tools 和测试里会走到。
- **配方红线**:只读常量数据(如 `PatronParts.SPECIES`);不建 Node 或 Resource;不调用 MeshKit 和 WorldMaterials;不用全局 `randf()`,需要随机数时在配方里建自己的 RandomNumberGenerator 并固定种子。
- Tavern 和 TableWorld 在 `main.gd:31-36` 同步构建,它们用到的酒瓶和(B3 起)空椅子网格会先同步建好,预计约 3–4 ms。

**清理**:`MeshForge.clear_cache()` 放进 `main.gd:82-88`。它先对所有在途 task 调 `wait_for_task_completion`(避免退出时报"任务未等待"),再清空缓存。

### A3. 着色器组与预热

**表 A3-1 新增的共享 include 和自定义 spatial 着色器**

| 文件 | 用途 | 关键内容 |
|---|---|---|
| `src/world/shaders/vertex_pbr.gdshaderinc` | 共享 include | `vec3 vp_srgb_to_linear(vec3 c)`(分段 sRGB 公式);PBR 参数从 UV2 读 |
| `src/world/shaders/patron.gdshader` | 所有酒客共用 1 个材质 | 见下方代码 |
| `src/world/shaders/prop.gdshader` | 道具:黄铜、铁、钢、蜡等放同一 surface | 同 patron,但没有 fade 和 RIM(旧的 gunmetal/brass/iron 都是不带 rim 的 StandardMaterial3D) |
| `src/world/shaders/bottle_glass.gdshader` | 酒瓶 MultiMesh | 不透明假玻璃:深色瓶内 + 菲涅尔边 + 液面线 + 标签带;`INSTANCE_CUSTOM.x` 是液面高度,`.y` 是标签号;UV2.x 是部件号(0 玻璃 / 1 标签 / 2 瓶塞) |

**新增**自定义 spatial 着色器的预算是 ≤ 4 个(现有的 card/felt/flame/soft_particle/soft_particle_add/stone/wood 不计):

- ①用掉 3 个,②的 `patron_eye.gdshader` 是第 4 个。
- ③④不再新增自定义 spatial 着色器。可以复用或修改现有着色器(prop、wood、stone、felt、card、soft_particle),或者用 StandardMaterial3D。

```glsl
// patron.gdshader:酒客共享材质;顶点数据见 MeshForge 布局
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://src/world/shaders/vertex_pbr.gdshaderinc"
instance uniform float fade = 0.0;   // 出局褪色 0..1(Patron.die 补间),新实例默认 0
const vec3 GREY = vec3(0.42);        // = Patron.GREY(sRGB)
void fragment() {
	vec3 c = COLOR.rgb;
	float metal = UV2.y;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));             // = Color.get_luminance()
	c = mix(c, GREY * lum * 1.6, 0.85 * fade * step(metal, 0.5)); // 金属件(铜扣)不褪色,与旧版一致
	ALBEDO = vp_srgb_to_linear(c);
	ROUGHNESS = UV2.x;
	METALLIC = metal;
	RIM = 0.3 * (1.0 - metal);                                     // 复现 patron_3d.gd:185-187
	RIM_TINT = 0.5;
	// ②起:AO = COLOR.a; AO_LIGHT_AFFECT = 0.3;(①里 COLOR.a 恒为 1,先不写,保证像素一致)
}
```

这段复现的是 `patron_3d.gd:449-451` 的效果:在 sRGB 空间里线性插值到 `GREY*lum*1.6`,权重 85%,时长 1.4 s。铜扣用的是 `WorldMaterials.brass()`,旧版本来就不在 `_materials` 里,不褪色。

**wood.gdshader**(`src/world/shaders/wood.gdshader:18-24, 46`)

- 新增 `uniform bool use_part_space = false;` 和 `varying float part_seed;`。
- vertex 改为 `obj_pos = (use_part_space ? CUSTOM0.xyz : VERTEX) * scale; part_seed = use_part_space ? CUSTOM0.w : 0.0;`。
- fragment 第 46 行改为 `float rnd = hash12(vec2(plank_id, 1.3) + part_seed * 31.7);`。
- 种子为 0 时结果和原来完全一致(实测平均差 0.09/255)。
- 修正竖直圆柱的木纹方向要旋转部件坐标,会改变外观,留给②(椅子)和④(房间)。

**flame.gdshader**

- 第 9、11 行的 `uniform float intensity/seed` 改成 `instance uniform`。
- `speed` 仍是普通 uniform(冻结截图时置 0)。
- billboard 依赖 `MODEL_MATRIX`,火焰不能合进静态网格。

**WorldMaterials(`src/world/materials.gd`)**

- 新增 `patron()`、`prop()`、`bottle_glass()`、`enamel(color)`。`enamel` 必须设 `cull_mode = CULL_DISABLED`,沿用 `tavern.gd:189`,否则从下方看不到灯罩内壁。
- `wood(preset, part_space := false)` 用 key `"wood:%s:%s"`。开 part_space 时**用工厂新建材质**,不 duplicate。
- `flame()` 不再带参数,单例缓存(第 98-104 行)。
- `particle()` 按 `(additive, boost, softness)` 缓存(第 107-114 行)。
- 所有材质都走 `_cached`(第 161-165 行),由 `clear_cache` 统一释放。

**实例参数**:每个着色器最多 16 个,默认值只来自着色器里的声明。实例参数不会打断自动实例化;每个实例复制一份材质才会。

**预热(条件项,B2.8 用冷缓存实测决定)**

- Godot 4.4+ 有 ubershader,而且网格加材质进场景时就会在后台预编译管线,很可能已经不卡。所以先不写 ShaderWarmup,只按 B2.8 的冷缓存流程测首用尖峰。
- **只有尖峰 > 33 ms 时**才新增 `src/world/shader_warmup.gd`(`class_name ShaderWarmup`,`static func run(tavern: Tavern) -> void`,协程),做法如下:
  - 建一个隐藏的 64×64 `SubViewport`:`own_world_3d = false`(共享 Tavern 的 World3D),先 `RenderBudget.apply`,让帧缓冲格式和主视口一致。
  - 给它配自己的 Camera3D,对准 Tavern 下 (0, −0.6, 0) 处的一组临时 MeshInstance3D。那里在吊灯 spot 的照射和阴影范围内,地板挡住主相机。
  - 每种新材质放一个,**顶点格式必须和真实网格一致**:patron 和 prop 用 MeshForge 建的带 COLOR/UV2 的小块;木纹 part-space 用 `chair`;另外放 5 种卡牌材质、加色和受光粒子材质。
  - 保留 3 帧后,连 SubViewport 一起释放。
  - **不能用主相机**:启动期间相机在 rig 原点(y=0,朝 −Z,`camera_rig.gd:33-39`),环绕要到 `_show_menu()` 才开始(`main.gd:139`)。地板下的块在它正下方,会被视锥剔除。
  - 和 `MeshForge.wait_prebuilt` 并行的写法:先 `var warm := ShaderWarmup.run(tavern)` 不 await,`await MeshForge.wait_prebuilt(self)` 之后用 `await warm` 汇合。
  - 无头下(`DisplayServer.get_name() == "headless"`)直接返回。
- 不在①开 shader baker:它要改导出预设和发布流程,收益未经测量。

### A4. 阴影策略(B1 / B2 落地;②③④沿用)

- **投影灯固定 3 盏**:吊灯 spot、壁炉 omni(保持 CUBE)、月光 spot。不新增投影灯。壁炉不改双抛物面:B2 后 seat 已降到 387,没必要冒接缝的风险。
- **层与 caster mask**(`MeshKit.LAYER_*`,位值;不在 project.godot 里命名层,见 A6)
  - 所有物体默认 `layers = LAYER_WORLD`(1)。
  - **只有**窗框(`tavern.gd:343-348`,Window 枢轴下的 6 块木框)和窗墙各段(`_window_wall`,`tavern.gd:144-154`)设 `layers = LAYER_MOON`(位值 4)。相机 `cull_mask` 和灯的 `light_cull_mask` 默认包含全部层,所以它们照样可见、照样被照亮。
  - `moon.shadow_caster_mask = LAYER_MOON`(`tavern.gd:353-361`)。吊灯 spot(`:194-205`)和壁炉 omni(`:270-278`)设 `shadow_caster_mask = LAYER_WORLD`。
  - 效果:酒客和桌子不再投月光影子(实测 seat −160 dc);窗墙也不进室内灯的阴影 pass。
  - ④将来的窗外景板只要不放进 LAYER_MOON,就自动挡不住月光。
- **`_wall` 改签名**(`tavern.gd:126-141`):`_wall(parent, base, extent, wood_preset, bottom := 0.0, top := ROOM_HEIGHT, name_prefix := "Wall", casts_panels := false, layers := MeshKit.LAYER_WORLD)`。
  - 三个件的节点名为 `<前缀>Wainscot`、`<前缀>Plaster`、`<前缀>Rail`。
  - `casts_panels` 只管护墙板和灰泥;**压条始终 `SHADOW_AUTO`**(照常投影),和实测配置一致。
  - 三面实墙的前缀为 `WallBack`、`WallFront`、`WallLeft`。窗墙四段为 `WindowWall0..3`,传 `casts_panels = true, layers = LAYER_MOON`。
- **cast_shadow 规则**
  - `MeshKit.add` 默认 `SHADOW_AUTO`,最大边 < 8 cm 的件不投影。MeshForge 合并出的实例按合并后的最大边套用同一规则:瞳孔、眉、转轮、击锤关掉;眼白 9.2 cm、手、帽、身体、枪身照常投影。
  - **显式关掉**:地板(`tavern.gd:112`,节点名 `Floor`);三面实墙的护墙板和灰泥;天花板、毡面、窗玻璃(已经关了,`:115, :170, :351`);火焰;酒瓶 MultiMesh。
  - 牌桌立牌(`card_table.gd:57-60`):底座直径约 0.11 m,照常投影;只有 3 cm 的夹子自动关掉。
  - **保留清单**:爪、手臂、帽檐、卡牌(12 cm)、举到太阳穴的枪身、窗墙、墙面压条。这些都 ≥ 8 cm,自动投影,不需要 `SHADOW_ON`。以后遇到"小但必须投影"的件,显式传 `SHADOW_ON` 并打 `force_shadow` meta。
- 粒子、贴花、窗外景板一律不投影。
- **实测**(冻结画面对比):小件和 7 个房间壳件不投影,像素差值 >2/255 ≤ 0.94%、>8/255 ≤ 0.26%,只在小件影子处;月光 mask 的差值 >2/255 ≤ 0.16%。

### A5. 合批策略(②③④沿用)

1. **按动画枢轴合并,不跨枢轴**
   - 每个动画枢轴下只有一个 MeshInstance3D,装下直接挂在它下面的全部静态部件。枢轴包括:Body、Neck、Head、眼、Pupil、Marks、眉、耳、Hat、ArmL/R、Hand、Fan、Drum、Hammer、LampPivot、TargetStand。
   - 左右镜像的枢轴共享同一个网格资源:眼、瞳孔、眉、耳、臂、手的几何在枢轴空间里完全相同。
2. **静态物按空间区域合并**:每面墙或每个道具簇一份,按材质分 surface,包围盒对角线 ≤ 约 4 m。**禁止全局合并**:审计实测把 337 件合成 24 件后,图元从 281k 涨到 393k,因为阴影 pass 剔除不掉。
3. **相同物体共享资源**:网格和材质都必须是同一份,才能触发 Forward+ 自动实例化。椅子、左轮、卡牌、壁灯、木桶、凳子、烛台都靠这一点。
4. **大量相同小件用 MultiMesh**:≥ 约 10 个同形小件(酒瓶、链节、铆钉、碎屑),按"形状 × 材质"各开一个 MultiMeshInstance3D。必须不透明(MultiMesh 整体剔除,实例之间不排序),默认不投影。
5. **重复物体不用半透明**:半透明不会被实例化,也不进深度预通道。现存的半透明只剩窗玻璃(1 块)、7 个壁灯玻璃罩和粒子;新增物件不再用半透明。
6. **多 surface**:只有材质本质不同时才分 surface(如程序化木纹 vs 顶点 PBR),每个 surface 算一次 draw。能用顶点 PBR 就合进一个 surface。
7. billboard(火焰、粒子)不进合并网格,材质靠实例参数共享。

### A6. 给②③④的硬规则清单

- 运行时游戏代码里禁止 `get_mesh_arrays`、`surface_get_arrays`、`get_faces`(GPU 回读)。B2.1 有 grep 测试守住;tools/ 不在扫描范围。
- 工作线程只做数组运算。
- 禁止 `duplicate()` 复制 ShaderMaterial 做变体。
- 缓存里的网格只读。
- 新几何一律走 MeshForge 布局。
- 新材质走 `WorldMaterials._cached`。
- 新静态缓存要在 `main.gd:82-88` 释放。
- 新物件默认 `SHADOW_AUTO`、`LAYER_WORLD`。
- 动画枢轴的名字和变换语义不变(见审计 §6.1)。
- 新的 src 和 tools 脚本不能引用 autoload 或 DebugFlags(`debug_flags.gd:41-43`),除非只在 main 流程里用。
- **不改 `project.godot`**:改了就要设 `base_build`,所有老玩家都得重装(release-update SKILL.md)。层名、渲染设置一律用代码常量。

---

## B. 子项目① 地基与观感修正

协议不变:`src/net/protocol.gd` 仍为 VERSION 4,可以和 0.6.x 同桌。B0 → B1 → B2 依次进行;B3 可以和 B1 并行开发,但要在 B2 之后合并。B1、B2 不单独发版。

### B0 测量护栏(运行时 0 改动)

**B0.1 共享机位表**

- 新文件 `tools/probe_views.gd`,不加 class_name(tools/ 不进导出包,`export_presets.cfg:10`),由 shot 和 perf_probe `preload`。
- 内容:`const VIEWS := ["seat","menu","opponent","overhead","closeup","bar","gun","selfshot","window","fireplace"]`,以及 `static func place(rig: CameraRig, view: String)`。
- 机位从 `tools/shot.gd:42-69` 原样搬过来:seat 用 `TableWorld.THIRD_PERSON_*`,并设 `fill_light = TableWorld.SEAT_FILL_LIGHT`。
- `shot.gd:42-69` 和 `perf_probe.gd:249-259` 都改用它,修掉 perf_probe 的 seat 机位 (0.55, 1.92, 2.1) 和游戏不一致的问题。
- 参数 `--views=all` 表示全部 10 个视角。
- 真实主菜单不另设视角,用 B0.4 的 `--scene=menu`。

**B0.2 统计工具**

新文件 `tools/scene_stats.gd`,不加 class_name,由 perf_probe、shot 和 GUT 测试 preload。提供:

- `inventory(root) -> Dictionary`,统计:
  - 可见 MeshInstance3D 数、唯一网格数、MultiMesh 实例总数;
  - 唯一材质数,口径为 `material_override` → surface override → 网格 surface 材质,粒子不算;
  - 投影物数、三角形总数(ArrayMesh 用 `surface_get_array_index_len`;PrimitiveMesh 用 `get_faces()`,窗口模式下会回读,只在工具里用,按网格缓存结果);
  - 灯的总数、omni 数、spot 数、投影灯数;
  - 每名酒客的统计。**口径**:Patron 子树里的可见 GeometryInstance3D,不含 Fan 子树(手牌)和 Revolver3D。**实例数和三角形含椅子;材质数不含椅子**(椅子木纹算场景共享材质)。
  - 每把左轮的实例数。
- `render_info(vp) -> Dictionary`:用 `RenderingServer.viewport_get_render_info(rid, VISIBLE/SHADOW, DRAW_CALLS/OBJECTS/PRIMITIVES_IN_FRAME)` 读数。
- `image_diff(a, b, mask := null) -> {mean, over2, over8, max}`:步长 2 采样,mask 内的像素不计。
- `face_stats`、`paw_stats` 和 `plaster_stats`,见 B0.4。

**B0.3 `tools/perf_probe.gd` 改造**

- **视口**:直接用游戏配置。第 30 行的 MSAA 换成 `RenderBudget.apply(_viewport)`;`budget` 用例保留,作为空操作的别名;另加 `msaa-2` 用例。默认 `--size` 改为 1920x1080(第 26 行)。
- **每个"视角 × 用例"的测量**:
  - 先走 60 帧预热(正常帧);
  - 在 30 个正常帧里读 render_info,同时用 `viewport_set_measure_render_time` + `viewport_get_measured_render_time_cpu` 取 CPU 时间平均值;
  - 再用 `force_draw` 吞吐法测 GPU 帧时间(沿用第 214-232 行;Metal 上 GPU 计时恒为 0)。
- **阴影重画模式默认开**:吞吐循环里每帧把所有投影灯的 `shadow_bias` 交替加减 1e-5。实测这样每帧阴影 dc 1262–1269,和游戏帧的 1213 相当;不开时是 0。`--static-shadows` 关掉。
- **输出**:
  - `--repeat=3` 取中位数。
  - 每行:`PROBE view=… case=… frame=… p95=… cpu=… vis_dc=… sh_dc=… dc=… vis_obj=… sh_obj=… prims=…`。
  - `--inventory` 每个场景状态打印一行 `INV …`;`--csv=<文件>` 追加记录。
- **开关**(第 64-96 行之外新增):
  - `hide:<名字>`:patrons、revolvers、cards、bottles,或 Tavern 顶层节点名前缀 Room/Table/LampPivot/Candles/Fireplace/Bar/Window/Barrel/Sconce;
  - `shadow-off:<前缀>`、`moon-shadow-off`。
  - 现有开关名全部保留,灯仍按父节点名前缀查找(第 115-117 行)。
- **冷缓存首用用例 `--first-use`**(单独进程,不和其他用例混跑):
  - 运行前在 shell 里删掉本项目 user:// 目录(`OS.get_user_data_dir()`)下的 `shader_cache` 和管线缓存。
  - 脚本先只搭 Tavern 走 60 帧,再**第一次**加入 showcase,按 `Time.get_ticks_usec()` 记录之后 10 个处理帧的最大帧间隔。
  - 带 `--with-prebuild` 时,先照 main.gd 跑 `MeshForge.prebuild`/`wait_prebuilt`(以及存在时的 ShaderWarmup)。
  - 重复 3 次(每次都清缓存)取中位数。
- **预算检查** `--assert-budget[=limits|target]`,读新文件 `tools/perf_budget.gd`:
  - `CAP`:任一视角 ≤ 900 dc、CPU ≤ 1.0 ms。只在 `LIMITS.enforce_cap == true` 时强制,超了 exit 1。
  - `TARGET`:seat 700 / menu 800 / opponent 400,超了只警告。
  - `LIMITS`:当前阶段门槛,每批次收紧一次,见各批次和验收。
  - `--frame-budget=10.0` 另外断言帧时间,只在 M3 上有意义。
- **验证**:`$GODOT --path . -s tools/perf_probe.gd -- --size=1920x1080 --views=all --cases=budget --frames=300 --repeat=3 --inventory` 能复现基线:seat 1798±10、menu 1940±10,seat 阴影 dc 约 1210–1270。

**B0.4 `tools/shot.gd` 新增参数**

- `--freeze`(配合引擎参数 `--fixed-fps 60`):
  - 脚本开头 `seed(2026)`;所有 GPUParticles3D 设 `use_fixed_seed=true; seed=7`。
  - showcase 搭好后再走 30 帧,然后把 Tavern、TableWorld、showcase 设成 `PROCESS_MODE_DISABLED`,粒子 `speed_scale=0`,所有火焰材质 `speed=0`。`CameraRig.snap` 是立即生效的(`camera_rig.gd:97-100`),冻结后照样能换机位。
  - 每个视角等 45 帧,让体积雾的时间重投影收敛(`shot.gd:7` 已经是 45)。
  - 实测两个进程截出的图逐像素一致。
- `--kill=<pid>`:showcase 搭好后对该座位调用 `die()`,等 1.6 s 再冻结,用来比对褪色终点。
- `--stats`:ID 掩码统计。
  - 做法:把材质临时换成 unshaded 纯色(用 `material_override`,MeshForge 的 surface 材质同样覆盖到);环境关掉雾、辉光、SSAO、调整,tonemap 设为 LINEAR、曝光 1;藏起粒子;渲染 3 帧截 ID 图,恢复原样;再用正常截图按掩码统计。
  - 掩码:
    - **脸**:每名酒客的 Head 子树,不含 Hat 子树和 `_ears` 枢轴,**含眼睛**;
    - **爪**:两个 Hand 子树,不含挂在手上的 Revolver3D;
    - **灰泥**:`material == WorldMaterials.stone("plaster")`。
  - 输出:`STATS view=… face.<物种> washed=…% clip=…% | paw.<物种> washed=…% clip=…% | plaster tile_std=… region_std=… mean=…`。
    - washed:Rec.709 亮度 ≥ 0.85 的像素;
    - clip:任一通道 ≥ 250;
    - tile_std:32px 小块(≥ 90% 是灰泥)亮度标准差的中位数;region_std:整片区域的标准差。
  - 实测 ID pass 首次约 1.6 s(编译管线),之后每个视角约 40 ms。
- `--diff=<目录>`:和目录里同名的 png 比较,输出 `DIFF view mean >2 >8 max`。`--mask=<Tavern 顶层节点名前缀>` 按 ID 掩码把该子树(外扩 4 px)排除在比较之外。
- `--assert-same[=identity|shadow]`:超过 B1 定义的门槛就 exit 1。
- `--scene=menu`:真实主菜单状态。Tavern + TableWorld 先 `clear()`,不搭 showcase(B3 后有空椅子);机位为菜单环绕的起始点,用 snap 固定。

**B0.5 GUT 预算测试**

新文件 `tests/test_scene_budget.gd`,无头运行;`preload("res://tools/perf_budget.gd")` 和 `preload("res://tools/scene_stats.gd")`。

- **场景**:`before_all` 用 `tools/showcase.gd` 搭场景,和 perf_probe 是同一个,清单门槛只有一套。
  - 无头时 `card_faces.gd:49-53` 直接用纯色纹理;搭建期间设 `Engine.time_scale = 8`,`after_all` 恢复为 1 并释放。
  - 另外用 `TableWorld.new(null)`(`add_child_autofree`)跑 2、3、4 人局的个别用例。
- **用例**(门槛读 `LIMITS`):
  - 每名酒客的可见实例 ≤ `patron_instances`(B0 为 60,实测 53–60);
  - 每名酒客的材质 ≤ `patron_materials`(B0 为 12,不含椅子,实测 11–12);
  - 每名酒客的三角形 ≤ 12000(实测 10.2–11.3k);
  - 每把左轮的实例 ≤ `revolver_instances`(28),`Chamber*` 恰好 5 个;
  - 灯 ≤ `lights`(18)、投影灯 ≤ 3;
  - 场景唯一材质 ≤ `scene_materials`(B0 用 GUT 实测值 +2,约 92);
  - 已缓存物种的生成时间:`Patron.new` 取 3 次中的最小值,≤ 16 ms(现状 1.7–5 ms)。
- **收紧方式**:B0 的门槛是现状加一点余量,每个批次在同一个提交里收紧,先改门槛让测试变红,再实现到变绿。dc 和 CPU 只能由 perf_probe 测,GUT 只管清单。

**B0.6 README**

- `README.md:99-110` 补上 perf_probe(含 `--first-use` 冷缓存流程)和 `shot --freeze/--stats/--diff/--kill/--mask` 的用法。
- 可选:在 `.claude/skills/release-update/SKILL.md` 的导出步骤前加一步 `--assert-budget`(不依赖帧时间)。

### B1 渲染地基(零视觉变化)

**像素门槛**:用 `shot --freeze --diff` 跨提交对比 10 个视角;before 在父提交的干净 worktree 里拍。

- **identity**:平均差 ≤ 0.5/255,差值 >2/255 的像素 ≤ 0.05%,>8/255 的 ≤ 0.01%。实测噪声底:平均 ≤ 0.35,>2/255 ≤ 0.013%,>8/255 ≤ 0.003%。
- **shadow**:差值 >2/255 ≤ 1.0%,>8/255 ≤ 0.3%,并且要人工看差异热图,确认只出现在小件影子处。这个门槛是按 7 个房间壳件的配置标定的,B1.2 不能多关。

**B1.1 网格缓存**

- 改动:`mesh_kit.gd` 按 A1 改;`tavern.gd:183-184` 改用 `CAPS_TOP`;`main.gd:82-88` 加 `MeshKit.clear_cache()`。
- 预期:seat 1798 → 约 1083,其他视角同比下降;三角形和材质不变。
- `LIMITS`:任一视角 ≤ 1200,`enforce_cap = false`。
- 门槛:identity。
- 新测试 `tests/test_mesh_kit.gd`:
  - 同参数返回同一实例,不同参数返回不同实例;
  - `box(Vector3(0.1,0.1,0.1))` 和 `box(Vector3(0.10004,0.1,0.1))` 共用一份,和 `0.10006` 不共用;网格尺寸等于量化后的值;
  - `hemisphere(r)` 不影响 `sphere(r)`,且其 `rings == maxi(segments/2, 6)`;
  - `cylinder` 的 caps 变体是不同的 key;
  - 搭好 Tavern 和 4 人 TableWorld 后 `audit_cache()` 为空;
  - `clear_cache` 之后缓存为空;
  - SHADOW_AUTO:小于 8 cm 的件关闭投影,显式参数可覆盖。

**B1.2 投影策略**

- 改动:
  - `mesh_kit.gd` 的 `add` 加 `shadow` 参数;
  - `tavern.gd:112` 地板设 OFF,命名 `Floor`;
  - `_wall`(`:126-141`)按 A4 改签名,三面实墙 `casts_panels = false`(压条照常投影);
  - `_window_wall` 传 `casts_panels = true`。
  - 现有的天花板、毡面、窗玻璃 OFF 保留(`:115, :170, :351`)。
- 预期(实测):B1 合计 seat 825、menu 892、overhead 674、window 676、bar 617;其余视角 ≤ 400;投影物 730 → 374。
- 门槛:shadow。
- 测试(`test_scene_budget`):
  - 节点自身尺寸 < 0.08 的 MeshInstance3D 一律 `cast_shadow == OFF`(带 `force_shadow` meta 的除外);
  - `Floor` 和 `Wall*Wainscot` / `Wall*Plaster` 为 OFF;`Wall*Rail` 和 `WindowWall*` 各件为 ON。

**B1.3 火焰共享材质**

- 改动:`flame.gdshader:9-11` 改成 instance uniform;`materials.gd:98-104` 的 `flame()` 改为单例;Tavern 新增 `_flame(parent, size, pos, intensity, seed)` 辅助函数,替换 `tavern.gd:237, 268, 398` 三处调用。
- 预期:材质 −17;dc 不变(加色混合本来就不会被实例化)。
- 门槛:identity(冻结时 `speed=0`)。
- 测试:Tavern 里所有火焰共用同一份材质,且各自的 `seed` 实例参数互不相同。

**B1.4 卡牌和粒子共享资源**

- 改动:
  - `card_3d.gd:40-41` 改用 `MeshKit.plane(Vector2(WIDTH, HEIGHT))`;
  - `fx.gd:129-150` 的 `_additive_quad` 和 `_lit_quad` 按参数缓存网格加材质,由 `Fx.clear_cache` 释放;
  - `materials.gd:107-114` 的 `particle()` 加缓存。
- 预期:同牌型的牌可以自动实例化,showcase 下约 −10~−40 dc(B1 实测里已经包含了卡牌网格去重);每次开枪少新建 3 份材质。
- 测试:`test_fx.gd:54-58` 不用改(着色器选择不变);新增"两张牌的 `_front.mesh` 是同一个资源"。

**B1 收紧**

- `LIMITS`:seat ≤ 850、menu ≤ 920、其余视角 ≤ 700、seat 阴影 ≤ 520、场景唯一材质 ≤ 75。
- `enforce_cap` 仍为 false:menu 实测 892,和 CAP 900 只差测量噪声。

### B2 合批架构

**B2.1 MeshForge 核心**

- 新增 `src/world/mesh_forge.gd`(A2):7 种旧基础体复刻、lathe、多 surface、缓存、预建、清理。
- 测试 `tests/test_mesh_forge.gd`(无头,此时 PrimitiveMesh 的数组在 CPU 上):
  - **基础体一致性**:sphere、hemisphere、cylinder 的 4 种 caps、capsule、box、torus、prism,每种 2–3 组参数,和 `PrimitiveMesh.get_mesh_arrays()` 比较:顶点数相同、位置误差 ≤ 1e-5、法线误差 ≤ 1e-4、索引相同;
  - `MeshForge.xf()` 等于 Node3D 设同样属性后的 `transform`;
  - 非均匀缩放后法线仍是单位长度,方向等于逆转置的结果;
  - 镜像变换后绕序正确(三角形叉积和顶点法线同向);
  - commit 后的 AABB 等于变换后基础体的 AABB;
  - COLOR、UV2、CUSTOM0 按布局写入,CUSTOM0 只在开了 part_space 时出现;
  - `cached` 返回同一实例,`clear_cache` 后清空;
  - 所有已注册配方放进 `WorkerThreadPool` 跑(每个任务都 wait),结果和同步构建一致(顶点数和坐标校验和);
  - lathe 的顶点数 = (轮廓点数 + crease 数) × (segments+1),再加封口;
  - **不准运行时回读**:扫描 `res://src/**/*.gd`,不得出现 `get_mesh_arrays(`、`surface_get_arrays(`、`get_faces(`。

**B2.2 着色器和材质**

- 新增 `vertex_pbr.gdshaderinc`、`patron.gdshader`、`prop.gdshader`、`bottle_glass.gdshader`;按 A3 改 `wood.gdshader`。
- `materials.gd` 新增 `patron()`、`prop()`、`bottle_glass()`、`wood(preset, part_space)`。
- 门槛:identity。`use_part_space` 默认 false,旧网格外观不变。

**B2.3 共享椅子**

- 改动:`patron_parts.gd:41-51` 改成配方 `PatronParts.chair_recipe(f)`:13 个基础体原样写入,用 `paint` 设颜色,开 part_space;网格 = `MeshForge.cached("chair", …, {&"wood": WorldMaterials.wood("dark", true)})`。
- `patron_3d.gd:111` 改成 `MeshKit.add(self, PatronParts.chair_mesh(), null)`,节点名 `"Chair"`,仍挂在 Patron 下,跟着登场缩放。
- 预期:每人 13 个实例变 1 个,4 把椅子共用一个网格,自动实例化。
- 门槛:identity(实测椅子平均差 0.09/255)。

**B2.4 酒客按枢轴合并 + fade 实例参数**

改动范围:`patron_3d.gd:103-189, 431-451`,以及 `patron_parts.gd:54-124` 改写成配方。配方和旧代码的 `MeshKit.add` 一一对应;颜色和粗糙度来自 `patron_3d.gd:105-110, 124` 和 `PatronParts.SPECIES`;铜扣写 metal=1、rough 0.32、颜色同 `WorldMaterials.brass()`。

**表 B2-1 枢轴与网格对应**

| 枢轴(名字不变) | 新的 MeshInstance3D 子节点 | 网格 key | 来源 | 投影 |
|---|---|---|---|---|
| Patron 根 | Chair | chair | 见 B2.3 | ON |
| Body | BodyMesh | patron:<id>:body | `:114-131, 134`(含铜扣) | ON |
| Neck | NeckMesh | patron:<id>:neck | `:133`(单位高圆柱不变) | ON |
| Head | HeadMesh | patron:<id>:head | `:149-150` 加 `build_snout` | ON |
| 眼 L/R | EyeMesh(共享) | patron:<id>:eye | `:154` | ON |
| 瞳孔 L/R | Pupil(本身就是 MeshInstance3D,换成合并网格) | patron:<id>:pupil | `:155` | OFF |
| 高光 | B2 仍是瞳孔下独立的自发光节点;B3 并入瞳孔 | — | `:156` | OFF |
| ×标记 L/R | MarksMesh(隐藏) | patron:<id>:marks | `:158-159` | OFF |
| 眉 L/R | BrowMesh | patron:<id>:brow | `:163` | OFF |
| 耳 L/R | EarMesh | patron:<id>:ear | `build_ears` | 自动 |
| Hat | HatMesh | patron:<id>:hat | `build_hat` | ON |
| ArmL/ArmR | ArmMesh | patron:<id>:arm | `:171-174` | ON |
| Hand | HandMesh | patron:<id>:hand | `:176` | ON |

- `_eyes` 每项仍是 `{"pivot","pupil","marks"}`,其中 `marks` 指 MarksMesh(位置同旧的 marks 枢轴 (0,0,−0.036))。眨眼、看向、耳朵抖动、表情、IK、弹簧脖子的代码都不用改。
- **褪色**
  - 删掉 `_materials` 和 `_mat()`(`:67, 180-189`)。
  - 构建时把所有用 `WorldMaterials.patron()` 的实例收进 `_fade_targets`,包括帽子和 MarksMesh,不包括椅子和高光。范围和旧 `_materials` 完全一样;铜扣由着色器里的 metal 判断豁免。
  - `die()` 里的 `:449-451` 改成 `fall.tween_method(_set_fade, 0.0, 1.0, 1.4)`;`_set_fade` 对 `is_instance_valid` 的目标逐个调 `set_instance_shader_parameter("fade", v)`。帽子被打飞、挂到别的父节点下以后仍在列表里。
- `PatronParts.forge_jobs()`:4 个物种的 11 个部件网格加椅子。
- 预期(实测原型):每人 55–60 个实例降到 19 个(含椅子);材质 11–12 个降到 2 个(不含椅子:patron + 共享的高光自发光)。B2 合计 seat 387、menu 401。
- 门槛:identity。另外用 `shot --kill=2 --freeze --diff` 断言 fade=1 时和旧材质褪色终点的像素差在 identity 内。
- 测试:
  - 新文件 `tests/test_patron_fade.gd`:`die()` 1.6 s 后所有 fade 目标(包括打飞的帽子)的 fade ≈ 1(±0.01),活着的酒客为 0;酒客没有私有的 StandardMaterial3D。
  - `test_hand_visibility`、`test_patron_arms`、`test_patron_neck`、`test_table_world` 原样通过(合并后头部挡牌实测 0%)。

**B2.5 左轮拆成 Body/Drum/Hammer**

- 改动:`revolver_3d.gd:15-53`。保留 `Body`、`Drum`、`Hammer` 三个 Node3D 枢轴(变换和层级不变),各挂一个合并网格子节点:
  - **BodyMesh**:2 个 surface。`metal` 用 prop,放钢件、黄铜件、扳机;`grip` 用 `wood("grip", true)`。
  - **DrumMesh**:1 个 prop surface,含转轮、弹膛盖、底火、槽线。Drum 下另挂 5 个 **Marker3D**,命名 `Chamber1..5`,放在弹膛位置。
  - **HammerMesh**:1 个 prop surface。
  - 钢件参数用 `revolver_3d.gd` 里的常量 `STEEL`,对应原 gunmetal(`materials.gd:117-118`)。
  - 新增 `Revolver3D.forge_jobs()`。
- API 不变:`drum`、`hammer`、`muzzle`、`spin_drum`、`cock_hammer`。
- 预期:每把 28 个实例变 3 个,4 把共用网格;dc 已经算在 B2 实测里。
- 门槛:identity。
- 测试:`test_revolver_3d.gd:5-17` 不用改(按 `Chamber*` 计数,弹膛数等于膛数的意图不变);新增"4 把枪的 Body/Drum/Hammer 网格是同一资源"。

**B2.6 酒瓶 MultiMesh**

- 改动:`tavern.gd:284-323`。
  - 用 `lathe` 做 6 种瓶型,key 为 `bottle:whiskey|wine|rum|gin|jug|flask`。
  - **rng 调用顺序不变**(种子 2026,每瓶依次取高度、颜色、间距),否则后面的啤酒杯会挪位。瓶型由高度分桶得出,不额外消耗 rng。
  - 每种瓶型一个 MultiMeshInstance3D,开 `use_colors`(玻璃色)和 `use_custom_data`(液面高度、标签号),`cast_shadow` OFF。
  - 瓶塞并进瓶型网格(UV2.x=2)。
- 预期:bar 视角约 230(B2 合计),menu 和 seat 分别少 130–260 dc;三角形约 +12k;玻璃色材质从 5 个变 1 个,不再有半透明叠画。
- 门槛:**这是唯一一项有意改外观的**。bar、menu、seat 三个视角用 `--diff --mask=Bar` 满足 identity,吧台区域人工评审。
- 测试:吧台下 MultiMesh 实例总数等于原来的瓶子数(53);没有半透明的瓶子材质。

**B2.7 层和 caster mask**

- 按 A4 改 `tavern.gd:144-154, 194-205, 270-278, 343-361`。
- 预期(实测):这一步 seat −160 dc。
- 门槛:shadow(主要影响 window 和 overhead 视角的月光影子;实测各视角 >2/255 ≤ 0.16%)。
- 测试:月光的 `shadow_caster_mask == LAYER_MOON`;Window 枢轴下的木框和 `WindowWall*` 各件 `layers == LAYER_MOON`;其余投影物 `layers == LAYER_WORLD`。

**B2.8 预建、首用测量和(按需)预热**

- `main.gd:51` 按 A2 接入 `MeshForge.prebuild` / `wait_prebuilt`;`main.gd:82-88` 加 `MeshForge.clear_cache()`。
- 新增调试参数 `--print-startup`:`main.gd` 在第一次 `_show_menu()` 前用静态的 `DebugFlags.parse_user_args().has("print-startup")` 判断,打印 `Time.get_ticks_msec()`。DebugFlags 实例此时还没创建(`main.gd:56-57`);`debug_flags.gd` 头部注释补一行说明。
- 预期:
  - 启动 +≤ 50 ms(预计:瓶子同步构建约 4 ms,物种在工作线程里和卡面生成重叠)。
  - perf_probe `--first-use --with-prebuild` 冷缓存首帧尖峰 ≤ 33 ms。超标时才按 A3 加 ShaderWarmup 并复测。

**B2 收紧**

- `LIMITS`:seat ≤ 450、menu ≤ 470、其余视角 ≤ 500、seat 阴影 ≤ 260、CPU ≤ 0.8 ms、场景唯一材质 ≤ 40、酒客实例 ≤ 19、酒客材质 ≤ 2、左轮实例 ≤ 3、MeshInstance3D ≤ 500。
- `enforce_cap = true`。

### B3 零成本观感修正(每一项都改外观,不参与像素对比,只看截图和 `--stats`)

**B3.1 去过曝:保持 ACES,压 albedo,压暗爪子**

- `tavern.gd:79-81` 的曝光保持 1.32;`:89-91` 加 `environment.ssao_light_affect = 0.35`。
- `patron_parts.gd:5-26` 的调色板:fur、muzzle、coat、accent、dark 按最大通道**等比**压到 ≤ `PatronParts.ALBEDO_CAP := 0.65`,保持色相(例如猪 fur (0.93,0.6,0.58) → (0.65,0.42,0.405))。
- 眼白:`patron_3d.gd:108` 的 0.97 改为 `EYE_WHITE := Color(0.65, 0.64, 0.62)`,就是 v9 实测用的值(0.97 的眼白按 0.65 封顶)。
  - 评审补测:眼白 0.80 时猪脸发白升到 5–6%,超过 5% 预算。
  - 只有 `--stats` 证明脸部发白仍 ≤ 5% 时,才允许调高,上限 0.72。
- 爪子:新增 `PatronParts.PAW_SHADE := 0.8`,爪子的顶点色 = fur(封顶后)× PAW_SHADE,在配方里算,零成本,也能读成肉垫色。实测猪爪发白从 10–33% 降到 0%。`--stats` 里爪子发白 > 5% 时降到 0.7。
- 高光改为不自发光:并进 pupil 网格,白色 0.95、rough 0.08,每人 −2 个实例。高光是点状,不受 ALBEDO_CAP 约束;它在脸部掩码里,但面积可以忽略。
- `tavern.gd:192` 灯泡 9 → 4;`:232` 蜡等比压到 0.72。
- 大厅名单仍用 `fur.lightened(0.3)`(`src/ui/lobby/lobby.gd:232`),可读性不受影响。
- 预期:
  - 实测(圆形区域测法,眼白 0.65):猪脸发白 → 1%,狐狸 → 0%,整帧平均亮度不变;红通道饱和仍有约 30%(ACES 本身的性质)。
  - 实测(爪 ×0.8):猪爪 0%。
  - ID 掩码的最终值由 B3 验收确认。
- 测试:`test_patron_parts.gd` 新增"调色板最大通道 ≤ ALBEDO_CAP;EYE_WHITE 各通道 ≤ 0.72;0 < PAW_SHADE ≤ 0.8"。②新增的物种也要守这条规则。

**B3.2 烛光 5 → 2**

- 改动:`tavern.gd:218-245`。每个烛台只放 1 盏 OmniLight3D,节点名仍以 `Candles` 开头,perf_probe 按前缀找灯。
  - 位置在烛台中心上方 (0, 0.012+平均烛高+0.05, 0)。
  - 能量 = 0.42 × 支数 × 0.75(3 支为 0.945,2 支为 0.63),range 2.4,一条 flicker。
  - 火苗仍是每支蜡烛一片。
- 预期:灯 18 → 15;帧时间约 −0.3 ms,已经算在实测的 −0.5 ms 里。
- 测试:`test_scene_budget` 的灯数 ≤ 16。

**B3.3 金属**

- Revolver 的 `STEEL` 改为 albedo (0.30,0.31,0.34)、metallic 0.70、rough 0.38。
- `materials.gd:49-53` 的 grip 改成胡桃木:dark (0.10,0.055,0.03)、light (0.32,0.18,0.09)、varnish 0.6。
- `WorldMaterials.gunmetal()` 没人用了就删掉。
- 灯罩(`tavern.gd:185-189`)改为缓存的 `WorldMaterials.enamel(Color(0.16,0.27,0.19))`:metallic 0、rough 0.5、`CULL_DISABLED`。内侧提亮留给③的 P6。
- 预期:枪不再是黑团,灯罩不再是黑锥;0 ms。

**B3.4 桌布金线**

- 改动:`felt.gdshader:28-37`。
  - 内圈改成双股虚线针脚:`inner_ring ± 0.0045`,`step(0.35, fract(angle*96/TAU))`。
  - 外圈保持实线;外圈虚线改成菱形针脚:`1 - smoothstep(0, 0.0035, |r-(outer+0.022)| + |fract(angle*48/TAU)-0.5|*0.02)`。
  - `METALLIC = thread*0.35`,`ROUGHNESS = mix(0.95, 0.6, thread)`,`SPECULAR = mix(0.15, 0.4, thread)`。
- 预期:不再超过辉光阈值(`tavern.gd:87`);0 ms。

**B3.5 主菜单空椅子**

- 改动:`table_world.gd`。`_ready` 里在 `seat_transform(i*TAU/4)` 处放 4 个 `"EmptyChair"`,共用 `chair` 网格,默认可见;`clear()`(`:114-123`)时显示,`arrange()`(`:39`)时隐藏。
- 预期:真实主菜单 +1–2 次实例化 draw;第一眼不再是一张光秃秃的桌子。
- 测试:`test_table_world.gd` 新增"clear 后 4 把可见且共用同一网格,arrange 后隐藏"。

**B3.6 bug 合集**(新测试文件 `tests/test_table_props.gd`,另外补 `test_revolver_3d.gd`)

1. **毡面吃掉牌堆底牌**
   - `seat_layout.gd` 新增 `const FELT_TOP := TABLE_TOP + 0.004` 和 `const FELT_RADIUS := 0.82`。
   - `tavern.gd:168-169` 的毡面改由这两个常量推算,节点命名为 `"Felt"`。
   - 新增静态函数 `CardTable.pile_y(i) = FELT_TOP + Card3D.GAP + 0.0004 + i*0.0011`,替换 `card_table.gd:195`;`reveal_y` 同理,替换 `:254`。
   - 测试:i = 0..20 时 `pile_y(i) - GAP ≥ FELT_TOP + 0.0003`,`reveal_y - GAP` 同样;Tavern 的 Felt 顶面等于 FELT_TOP、半径等于 FELT_RADIUS。
2. **平放的枪陷进桌面 13 mm**
   - 新增 `Revolver3D.REST_HALF_WIDTH := 0.026`(转轮半径 0.025 加 1 mm,槽线外缘也到 0.026)。
   - `table_world.gd:148` 的 `SeatLayout.TABLE_TOP + 0.013` 改为 `SeatLayout.FELT_TOP + Revolver3D.REST_HALF_WIDTH`。
   - 必须用 FELT_TOP:实测平放时转轮中心离桌心 0.807 m,在毡面以内;用 TABLE_TOP 仍会陷进毡面 4 mm。悬在木桌沿上方 ≤ 4 mm 看不出来,而且高于铜边的 3.5 mm。
   - 测试:2、3、4 人局各座位上,左轮所有网格**顶点**(无头下 `get_faces()` 在 CPU 上,乘全局变换)的最低点 ≥ FELT_TOP − 0.0005。
3. **倒地后枪掉到桌外半空**
   - 实测落在 y=0.600、离桌心 1.224 m。原因是 `landing.lerp(global_position, 0.25)` 在往地面上的座位原点插值。
   - `patron_3d.gd:440-442` 的落点改为 `global_transform * Vector3(0.24, SeatLayout.FELT_TOP + Revolver3D.REST_HALF_WIDTH, -0.42)`,即本人面前的桌沿(实测 r≈0.864)。
   - 旋转仍是 `(0, rot.y+1.8, PI/2)`:Rz(π/2) 让枪的 −X 侧朝下,和 REST_HALF_WIDTH 的口径一致。
   - 测试:die 1 s 后,枪原点离桌心 < TABLE_RADIUS,顶点最低点 ≥ FELT_TOP − 0.0005。
4. **枪口插进头里**
   - `patron_3d.gd:34` 的 `HAND_GUN_HEAD` 改为 (0.355, 0.85, −0.05)。评审实测:枪口到头心 0.182–0.187 m(头半径 0.17)。
   - 测试:4 个物种在 `raise_gun_to_head` 之后,枪口到头心的距离都在 0.172–0.20 之间。③的 P1 换了更粗的枪后重调,这个测试继续守着。
   - 牛仔帽檐穿模交给②的 C3(帽檐两侧卷起)。
5. **弹膛对不准枪管、转轮停在随机角度**
   - `revolver_3d.gd:40, 45` 的角度加 `PI/2`:Chamber1 落在转轮的 12 点位,和枪管同轴(弹膛 y = 0.045+0.0145 = 0.0595,枪管轴 y = 0.058)。
   - `spin_drum`(`:56-60`)改为转整数格:`var start := snappedf(drum.rotation.z, TAU / CHAMBERS)`,`steps = roundi(turns * CHAMBERS)`,目标为 `start + TAU * steps / CHAMBERS`。
   - 转几格仍是本地随机数(`table_director.gd:195`),和弹药状态无关;所有弹膛外观一样,不泄露子弹位置。
   - 测试:扳击加转动后,`fposmod(rotation.z, TAU/5)` 和 0 或 TAU/5 的差 ≤ 1e-3;新建的枪上,Chamber1 换算到 Revolver3D 坐标后 x ≈ 0,y 与 `MUZZLE_POS.y` 相差 ≤ 2 mm。
6. **牌背画 6 孔**
   - `card_faces.gd:251-255` 改用新静态函数 `CardFaces.chamber_points(center, radius)`,点数等于 `Revolver.CHAMBERS`。
   - 测试:`chamber_points` 的点数等于 5。
7. **啤酒面自发光**
   - `tavern.gd:328` 改为缓存的不发光材质,albedo (0.78,0.6,0.28)、rough 0.25。

**B3 收紧**:`LIMITS` 改为灯 ≤ 16、酒客实例 ≤ 17、酒客材质 ≤ 1(不含椅子)、场景唯一材质 ≤ 36、MeshInstance3D ≤ 490。

### 提交与发版顺序

1. B0 一组提交。
2. B1.1–B1.4,每项一个提交,都附 diff 报告。
3. B2.1 → B2.8。
4. B3 按 3.1–3.6 分开提交。

- 每个提交都要通过全量 GUT。
- 从 B1 起附上 `perf_probe --assert-budget` 的输出:B1 期间按当时的 LIMITS 判定;B2.7 起 `enforce_cap = true`,必须退出码 0。
- 最后用 release-update skill 发 0.7.0:只改 `version` 和 `build`,`base_build` 不动(①不改 project.godot)。协议不变。

### ① 发版验收(数字)

1. **draw call 和 CPU**
   - 命令:`$GODOT --path . -s tools/perf_probe.gd -- --size=1920x1080 --views=all --cases=budget --frames=300 --repeat=3 --inventory --assert-budget`,退出码为 0。
   - seat 总 dc ≤ 450(实测 387),其中可见 ≤ 200(155)、阴影 ≤ 260(232);menu ≤ 470(401);其余 8 个视角都 ≤ 500(实测最大 358)。
   - seat 和 menu 的 CPU 渲染线程 ≤ 0.8 ms(实测 0.41–0.43)。
2. **帧时间**:M3、1080p、游戏配置、seat 视角中位数 ≤ 9.7 ms,不得比基线差(实测 9.61 → 9.09)。
3. **清单**(showcase,GUT 和 perf_probe 共用)
   - 唯一材质 ≤ 36(预计 33);MeshInstance3D ≤ 490(预计 482);灯 ≤ 16(15),投影灯 = 3。
   - 每名酒客:可见实例 ≤ 17(含椅子,不含手牌和左轮);材质 ≤ 1(不含椅子;②加眼睛着色器后 ≤ 2);三角形 ≤ 12k。
   - 每把左轮:3 个实例、`Chamber*` = 5、三角形 ≤ 3k。
   - 酒瓶 ≤ 6 个 MultiMesh;火焰材质 = 1。
4. **观感**
   - 命令:`shot --fixed-fps 60 --showcase --freeze --stats`,视角 seat、opponent、selfshot、closeup、gun、menu。
   - 每名酒客的脸部发白(亮度 ≥ 0.85,ID 掩码,含眼睛)≤ 5%;每名酒客的爪子发白 ≤ 5%;seat 整帧任一通道削顶 ≤ 1%(实测 0.77–0.82%)。
   - 记录灰泥 tile_std 的基线(3.6–5.4),作为④的对比基准,①不设门槛。
5. **像素门槛**:
   - B1.1、B1.3、B1.4、B2.1–B2.5 的提交满足 identity(B2.4 另加 `--kill` 褪色终点对比);
   - B1.2、B2.7 满足 shadow;
   - B2.6 用 `--mask=Bar` 后满足 identity,吧台区域人工评审;
   - 都有 diff 报告存档。
6. **启动和首用**
   - `--print-startup` 显示启动增加 ≤ 50 ms;
   - 已缓存物种生成 ≤ 16 ms(GUT 断言);
   - perf_probe `--first-use --with-prebuild` 冷缓存首帧尖峰中位数 ≤ 33 ms(超标时加 ShaderWarmup 后复测)。
7. **测试**:全量 GUT 通过。测试脚本数 = 原来的 46 + 新增 5 个(test_mesh_kit、test_mesh_forge、test_scene_budget、test_patron_fade、test_table_props)= 51。现有断言零修改,只在 test_revolver_3d、test_table_world、test_patron_parts 里新增用例。
8. **人工检查 10 张截图**,和 `shots-before` 对比:
   - 猪是粉色而不是白色,爪子不泛白;枪不是黑团;桌布金线不像霓虹灯;
   - 主菜单有 4 把空椅子;牌背是 5 孔;最上面的弹膛对准枪管;
   - 牌堆的第一张牌可见;平放的枪不陷进桌面和毡面;倒地后枪落在桌上;枪口不插进头里。
9. **兼容性**:0.6.x 和 0.7.0 能同桌打完一局。
   - `git worktree add <临时目录> v0.6.0` 后,运行 `HOST_ROOT=<临时目录> tools/lan_smoke.sh`(新增的 HOST_ROOT 只让房主进程用旧版本,两个 bot 用 HEAD);
   - 再跑一次不带 HOST_ROOT 的同版本冒烟。
10. **非 Apple 驱动数据点(只存档,不设门槛)**:`perf_probe --rendering-driver vulkan`(MoltenVK)跑 seat 和 menu;有 Windows 集显机就补一次。


## 涉及文件
src/world/mesh_kit.gd
src/world/mesh_forge.gd (新)
src/world/shader_warmup.gd (仅当冷缓存首用尖峰 > 33 ms 时新增)
src/world/materials.gd
src/world/tavern.gd
src/world/patron_3d.gd
src/world/patron_parts.gd
src/world/revolver_3d.gd
src/world/card_3d.gd
src/world/card_table.gd
src/world/card_faces.gd
src/world/table_world.gd
src/world/seat_layout.gd
src/world/fx.gd
src/world/shaders/vertex_pbr.gdshaderinc (新)
src/world/shaders/patron.gdshader (新)
src/world/shaders/prop.gdshader (新)
src/world/shaders/bottle_glass.gdshader (新)
src/world/shaders/wood.gdshader
src/world/shaders/flame.gdshader
src/world/shaders/felt.gdshader
src/ui/main.gd
src/ui/debug_flags.gd (只补 --print-startup 的注释行)
tools/probe_views.gd (新)
tools/scene_stats.gd (新)
tools/perf_budget.gd (新)
tools/perf_probe.gd
tools/shot.gd
tools/lan_smoke.sh (新增 HOST_ROOT 环境变量,默认 ROOT)
tests/test_mesh_kit.gd (新)
tests/test_mesh_forge.gd (新)
tests/test_scene_budget.gd (新)
tests/test_patron_fade.gd (新)
tests/test_table_props.gd (新)
tests/test_revolver_3d.gd (只新增用例)
tests/test_table_world.gd (只新增用例)
tests/test_patron_parts.gd (只新增用例)
README.md
.claude/skills/release-update/SKILL.md (可选:导出前加 --assert-budget)

## 测试
tests/test_mesh_kit.gd:同参数返回同一网格;0.1 和 0.10004 共用一份、和 0.10006 不共用,网格尺寸等于量化值;hemisphere 不改 sphere 的缓存,且 rings == maxi(segments/2, 6);cylinder 的 caps 变体是不同 key;搭好 Tavern 和 4 人 TableWorld 后 audit_cache() 为空;clear_cache 后为空;SHADOW_AUTO 按节点自身变换判断,小于 8 cm 的件关闭投影,显式参数可覆盖
tests/test_mesh_forge.gd:sphere、hemisphere、cylinder(4 种 caps)、capsule、box、torus、prism 和 PrimitiveMesh.get_mesh_arrays() 逐顶点一致(位置误差 ≤1e-5、法线误差 ≤1e-4、索引相同);MeshForge.xf 等于 Node3D 的 transform;非均匀缩放后法线是单位长度且方向等于逆转置;镜像后绕序翻转;commit 后 AABB 正确;COLOR、UV2、CUSTOM0 布局和格式标志正确;cached 返回同一实例;全部配方在 WorkerThreadPool 里跑(每个任务都 wait)的结果和同步构建一致;lathe 顶点数 = (轮廓点数+crease 数)×(segments+1)+封口;扫描 src/**/*.gd 不得出现 get_mesh_arrays/surface_get_arrays/get_faces
tests/test_scene_budget.gd(无头;场景用 tools/showcase.gd,与 perf_probe 相同;门槛读 tools/perf_budget.gd 的 LIMITS,每批次收紧):每名酒客可见实例(含椅子:B0 ≤60,B2 ≤19,B3 ≤17)、材质(不含椅子:≤12 → ≤2 → ≤1)、三角形 ≤12000;左轮实例(≤28 → ≤3)且 Chamber* 恰好 5 个;灯(≤18 → ≤16)、投影灯 ≤3;场景唯一材质(B0 实测+2 → ≤75 → ≤40 → ≤36);MeshInstance3D(B2 ≤500,B3 ≤490);节点自身尺寸小于 8 cm 的件都不投影(force_shadow 豁免);Floor 和 Wall*Wainscot/Plaster 不投影,Wall*Rail 和 WindowWall* 投影;火焰共用一份材质且 seed 各不相同;4 把椅子共用网格,4 把枪共用 Body/Drum/Hammer;月光 caster mask 和窗户层正确;已缓存物种 Patron.new ≤16 ms(取 3 次最小值)
tests/test_patron_fade.gd:die() 1.6 s 后所有 fade 目标(包括打飞的帽子和 MarksMesh)的 fade 实例参数 ≈1,活着的酒客为 0;酒客没有私有 StandardMaterial3D
tests/test_table_props.gd:i=0..20 时 pile_y(i) 和 reveal_y 减去 GAP 都 ≥ FELT_TOP+0.0003;Tavern 的 Felt 顶面等于 SeatLayout.FELT_TOP、半径等于 FELT_RADIUS;2、3、4 人局各座位平放左轮的顶点最低点 ≥ FELT_TOP−0.5 mm;倒地 1 s 后枪原点离桌心 < TABLE_RADIUS,顶点最低点 ≥ FELT_TOP−0.5 mm;4 个物种举枪后枪口到头心 0.172–0.20 m;CardFaces.chamber_points 点数等于 Revolver.CHAMBERS
tests/test_revolver_3d.gd 新增:扳击加转动后转轮停在整格(fposmod(rotation.z, TAU/5) 离 0 或 TAU/5 ≤1e-3);新建枪的 Chamber1 在 12 点位,换算到 Revolver3D 坐标后 x≈0,y 与 MUZZLE_POS.y 相差 ≤2 mm;原有两个用例不改
tests/test_table_world.gd 新增:clear() 后 4 把 EmptyChair 可见且共用同一网格,arrange() 后隐藏
tests/test_patron_parts.gd 新增:SPECIES 调色板最大通道 ≤ PatronParts.ALBEDO_CAP(0.65);EYE_WHITE 各通道 ≤0.72(默认 0.65 档);0 < PAW_SHADE ≤ 0.8
必须原样通过的现有测试:test_hand_visibility(实测合并后挡牌 0%)、test_patron_arms、test_patron_neck、test_table_world、test_revolver_3d、test_fx、test_cursor_look、test_gaze_sync、test_patron_parts、test_seat_layout、test_render_budget、test_post_fx;①不修改任何现有断言
工具级回归:跨提交运行 shot --fixed-fps 60 --showcase --freeze --diff=<父提交截图> --assert-same=identity|shadow,覆盖 10 个视角(B2.4 另加 --kill=2,B2.6 用 --mask=Bar);shot --stats 输出脸和爪的 ID 掩码统计;perf_probe --assert-budget;perf_probe --first-use --with-prebuild 冷缓存流程跑 3 次取中位数;HOST_ROOT 跨版本 lan_smoke

## 预算影响
M3、1080p、游戏渲染配置、showcase 场景。实测是 B2 原型外加 B3 的烛光和 ssao 改动;标"预计"的是推算。

- **draw call(实测)**:seat 1798 → 387(可见 155 + 阴影 232);menu 1940 → 401;其余视角 ≤ 358。离目标 700 还有约 310,离硬上限 900 还有约 510,留给②③④。按瓶型分 6 个 MultiMesh,比原型最多多 5 dc。
- **CPU 渲染线程(实测)**:0.81 → 0.41 ms(本次测量;审计时为 1.1–1.5 ms),预算 1.0 ms。
- **帧时间(实测)**:9.61 → 9.09 ms(−0.5 ms),预算 10.0 ms,剩 0.9 ms。
- **唯一材质(预计)**:90 → 约 33,预算 40,剩 7。原型 B2 实测是 55,当时还没共享 18 份火焰材质和粒子材质、高光仍自发光;按 B1.3、B1.4、B2.6、B3 逐项扣减得到 33,由 B3 的清单确认。
- **自定义 spatial 着色器**:新增用掉 3/4(patron、prop、bottle_glass),第 4 个留给②的 patron_eye;③④不再新增。
- **灯**:18 → 15,投影灯仍是 3 盏,预算 16 盏。
- **每名酒客**:
  - 实例 55–60 个 → 17 个(含椅子;②要做到 ≤16,做法是把眼白并进头或改成 shader 眼);
  - 材质(不含椅子)11–12 个 → 1 个,②加眼睛着色器后为 2,满足 ≤2;
  - 三角形 10–11k 不变,预算 15k。
- **每把左轮**:28 → 3 个实例,约 2.7k tri,预算 8k。
- **MeshInstance3D**:733 → 490(B2 实测)→ 预计 482(B3 并掉 8 个高光)。三角形总量约 +12k(lathe 酒瓶)。
- **启动(预计)**:+≤ 50 ms(预算 200 ms);已缓存物种生成约 1–2 ms(预算 16 ms)。冷缓存首用尖峰按 B2.8 实测。
- **脸部发白**:53–81% → v9 实测 ≤ 1%(眼白 0.65,圆形区域测法),预算 ≤ 5%。若用眼白 0.80,实测为 5–6%,会超预算,所以眼白定为 0.65 档。
- **爪子发白**:猪爪 10–44% → 0%(爪 ×0.8,实测)。

## 验收
perf_probe --size=1920x1080 --views=all --cases=budget --frames=300 --repeat=3 --inventory --assert-budget 退出码为 0(此时 enforce_cap=true)
seat 总 draw call ≤450(实测 387),其中可见 ≤200、阴影 ≤260;menu(showcase)≤470(实测 401);其余 8 个视角都 ≤500(实测最大 358)
seat 和 menu 的 CPU 渲染线程(viewport_get_measured_render_time_cpu)≤0.8 ms(实测 0.41–0.43)
M3、1080p、游戏配置、seat 帧时间中位数 ≤9.7 ms,不比基线差(实测 9.61 → 9.09 ms)
showcase 清单:唯一材质 ≤36(预计 33);MeshInstance3D ≤490(预计 482);灯 ≤16(预计 15),投影灯 =3
每名酒客可见实例 ≤17(含椅子,不含手牌和左轮),材质 ≤1(不含椅子),三角形 ≤12k;每把左轮 3 个实例且 Chamber* = 5;酒瓶 ≤6 个 MultiMesh;火焰材质 = 1
shot --stats 的 ID 掩码统计:seat、opponent、selfshot、closeup、gun、menu 里每名酒客的脸部发白像素(亮度 ≥0.85,含眼睛)≤5%、爪子发白像素 ≤5%;seat 整帧任一通道削顶 ≤1%;灰泥 tile_std 基线已记录
像素门槛:B1.1、B1.3、B1.4、B2.1–B2.5 满足 identity(平均差 ≤0.5/255,差值 >2/255 的像素 ≤0.05%,>8/255 的 ≤0.01%;B2.4 另用 --kill 比对褪色终点);B1.2、B2.7 满足 shadow(>2/255 ≤1.0%,>8/255 ≤0.3%,差异只在小件影子处);B2.6 用 --mask=Bar 后满足 identity,吧台人工评审;每个提交都附 diff 报告
--print-startup 显示启动增加 ≤50 ms;已缓存物种 Patron.new ≤16 ms;perf_probe --first-use --with-prebuild 冷缓存(清掉 user:// 的 shader_cache 和管线缓存,全新进程)首帧尖峰中位数 ≤33 ms
全量 GUT 通过,测试脚本数 = 46 + 5 = 51;现有断言零修改,只在 3 个现有测试文件里新增用例
人工核对 10 个视角截图:猪是粉色不发白,爪子不泛白;枪不是黑团;金线不像霓虹灯;主菜单有 4 把空椅子;牌背是 5 孔;最上面的弹膛对准枪管;牌堆第一张可见;平放的枪不陷进桌面和毡面;倒地后枪落在桌面上;枪口不插进头里
协议 VERSION 仍为 4;HOST_ROOT 指向 v0.6.0 worktree 的 lan_smoke 跨版本跑通一局,同版本 lan_smoke 也通过;build.json 只升 version/build,base_build 不变(未改 project.godot)

## 决策(均按推荐默认采纳)
月光只让窗墙和窗框投影,酒客和牌桌不再有月光影子(用户尚未确认的设计默认)。推荐默认:接受。实测 seat 少 160 次 draw call,画面差异主要在 window 和 overhead 视角的地面月光影子里,>2/255 的像素 ≤0.16%
去过曝的做法和口径。推荐默认:保持 ACES、曝光 1.32 不降;酒客调色板按最大通道等比压到 ≤0.65;眼白定为 0.65 档(0.97 按同一上限压缩);爪子颜色再 ×0.8;烛光 5→2;ssao_light_affect 0.35。实测猪脸发白从 53–81% 降到 ≤1%,猪爪降到 0%,整帧平均亮度不变。这和你给的默认「降曝光 + 压 albedo」不同:实测曝光降到 1.0–1.1 会让整间屋子暗 14–16%,只压 albedo 就够。口径建议把「脸部削顶 ≤5%」定为「亮度 ≥0.85 的发白像素 ≤5%(含眼睛)」,爪子同一标准。代价有两个:眼白偏灰白,不是纯白(想更白要以 --stats ≤5% 为前提,最多 0.72);暖光下猪和狐狸脸的红通道仍有约 30% 饱和(不发白,只是红色层次略平),要彻底消除只能换 AgX(偏中性、不够暖)
酒瓶改为不透明的风格化假玻璃,加 6 种车削瓶型,用 MultiMesh 绘制,不再半透明。推荐默认:接受。这是①里唯一有意改外观的合批项,吧台少约 130–260 次 draw call;它占用一个新增着色器名额,本来属于④的吧台范围
主菜单放 4 把空椅子(用户尚未确认的设计默认)。推荐默认:接受。共用一个椅子网格,只多 1–2 次实例化 draw
每名酒客预算的统计口径:实例数含椅子(①为 17,②要做到 ≤16),材质数不含椅子(椅子木纹算场景共享材质)。推荐默认:接受。材质如果也含椅子,②加眼睛着色器后就是 3 个,超过「每人 ≤2 个共享材质」

## 风险
GPU 回读:在 Metal 上 PrimitiveMesh.get_mesh_arrays()/surface_get_arrays() 每次约 1.2 ms,只要游戏代码里出现一次,构建就慢 10 倍以上(合并原型在窗口模式下花了 137–252 ms)。对策:MeshForge 复刻 7 种基础体并有一致性测试;grep 测试禁止在 src 里调用
线程安全:工作线程里新建或读取网格资源会报 RID 重复初始化,主线程阻塞等待时还会死锁。对策:配方只做纯数组运算;每个任务只写自己的 Job;完成后立即 wait_for_task_completion 回收;用并发跑全部配方的测试守住
ShaderMaterial.duplicate() 会改变木纹观感(实测 15% 的像素差值 >2/255)。对策:变体一律走 WorldMaterials 工厂新建,写进 A6 红线
顶点色按 RGBA8 存,存线性色会让暗色误差达 25%。对策:COLOR 存 sRGB,在着色器里转换(实测像素一致)
像素对比的稳定性:体积雾的时间重投影要 ≥45 帧收敛,灯光闪烁、粒子、TIME 都要冻结。对策:shot --freeze 配合 --fixed-fps 60 和固定种子(实测两个进程截图逐像素一致)
复刻旧基础体时,一处算法细节不一致就会破坏像素一致(例如 hemisphere 的 rings 规则)。对策:每种基础体用 2–3 组参数,和 Godot 的输出逐顶点比对;Godot 升级时这组测试会先报警
阴影门槛只是按实测配置标定的:fireplace 视角 0.937% 对门槛 1.0%。B1.2 只要比实测多关任何东西(比如压条),就可能超门槛。对策:B1.2 严格按 7 个房间壳件实施,压条保持投影
首用卡顿的测量依赖冷缓存:Godot 会把着色器和管线缓存写在 user:// 下,热缓存下测量必然通过。对策:--first-use 流程每次都清缓存,在全新进程里跑;只有超标才加 ShaderWarmup,而且用隐藏的 SubViewport,不能用启动时停在原点的主相机
褪色豁免借用了 metallic>0.5 的约定(保住铜扣):如果②加入「金属但应该褪色」的部件,要另找通道做标记
B2 合并组的投影由整组最大边决定:组里的小件(铜扣等)也会进阴影 pass。只多图元不多 dc(实测阴影图元 105k→127k),可以接受
性能计时受机器负载影响:设计期间有别的 Godot 进程在跑,CPU 时间在 0.6–1.5 ms 之间波动。对策:--repeat=3 取中位数,接电源并关闭其他 GPU 程序;dc 和清单这类确定性指标作为主要门槛;CAP 从 B2.7 才强制,避开 B1 期间 menu 892 对 900 的噪声区
红通道饱和:保持 ACES 时猪脸仍有约 30% 的像素红通道 ≥250。如果用户把「削顶」理解为「任一通道」,就达不到 5%,需要拍板口径或改用 AgX
眼白 0.65 档偏灰白:是去过曝实测过的取值,调高必须以 --stats ≤5% 为前提;②换成 shader 眼后会重调
举枪手位 HAND_GUN_HEAD 按 4 个现有物种调到枪口离头表面约 1–1.7 cm(实测 0.182–0.187 m),②重塑头型和③加粗枪身后必须重调。由枪口间隙测试守住
倒地掉枪落点从「椅子旁 0.6 m 高的半空」改成「桌沿」,属于行为修正,演出里能看到;动画时长和补间方式都不变。枪的朝向仍随演出变化,枪管可能伸出桌沿,只是悬空,不穿模
非 Apple GPU 没有门槛数据:目标机型含 GTX 1060、Iris Xe、780M,①只在 M3 上测。dc 降到 1/4.6 以后风险低;发版前存档 MoltenVK 数据,有 Windows 集显机再补
