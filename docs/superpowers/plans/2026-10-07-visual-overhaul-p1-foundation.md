# 模型美化子项目① 地基与观感修正 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 draw call 从约 1800 降到 ≤ 450、外观不变,再做零成本观感修正(去过曝、金属、桌布、空椅子、小 bug),发 0.7.0。

**Architecture:** 先补测量工具,再用网格缓存与投影策略降 draw call(像素对比验证外观不变),
再用 MeshForge 把角色/椅子/左轮/酒瓶按动画枢轴合并成共享网格,最后逐项改外观。

**Tech Stack:** Godot 4.7.2、GDScript、GUT 9;工具脚本 `tools/*.gd`(不进导出包)。

**Spec:** `docs/superpowers/specs/2026-10-07-visual-overhaul-design.md`(总纲)与
`docs/superpowers/specs/2026-10-07-visual-overhaul-p1-foundation.md`(详细设计,下文「设计 X」指其中的章节)。
每个任务的具体做法、代码要点与测试清单以详细设计为准,本计划只给顺序、文件、验证命令与提交。

## Global Constraints

- 协议不变(`Protocol.VERSION` 仍为 4);不改 `project.godot`(`base_build` 不动)。
- 游戏代码(`src/**`)禁止 `get_mesh_arrays(` / `surface_get_arrays(` / `get_faces(`;工作线程只做数组运算。
- 新静态缓存在 `src/ui/main.gd` 的 `_exit_tree` 里释放;新材质走 `WorldMaterials._cached`;禁止 `duplicate()` 复制 ShaderMaterial 做变体。
- tools/ 新脚本不声明 class_name,用 `preload` 取用;新的 src/tools 脚本不引用 autoload 与 DebugFlags。
- Tab 缩进;中文注释与周边密度一致;中文约定式提交,结尾附 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`。
- 现有测试断言不改,只新增用例/测试文件;每个提交全量 GUT 通过。

命令(下文沿用):

```bash
G=/Applications/Godot.app/Contents/MacOS/Godot
# 全量单测
$G --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
# 单个测试
$G --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_x.gd -gexit
# 冻结截图(10 个视角)与对比
$G --fixed-fps 60 --path . -s tools/shot.gd -- --out=<目录> --views=seat,selfshot,gun,menu,overhead,fireplace,bar,window,closeup,opponent --showcase --freeze
$G --headless --path . -s tools/shot_diff.gd -- --a=<改前目录> --b=<改后目录> [--tolerance=0.0079 --max=0.0005]
# 性能
$G --path . -s tools/perf_probe.gd -- --size=1920x1080 --view=seat,menu,opponent,overhead,closeup,bar,gun,selfshot,window,fireplace --cases=budget --frames=300 --assert-budget
```

像素门槛(设计 B1):**identity** = 差值 >2/255 的像素 ≤ 0.05%(`--tolerance=0.0079 --max=0.0005`);
**shadow** = >2/255 ≤ 1.0%(`--tolerance=0.0079 --max=0.01`),并人工确认差异只在小件影子处。改前截图在父提交上拍。

## Review Focus

- 冻结截图不可比(动画、粒子、火焰 TIME 没停)会让「外观不变」的验证失真:每个 identity 任务都先确认父提交两次截图差异为 0。
- 缓存网格被调用方改写(`cap_bottom`、hemisphere)会悄悄改变别处外观:T4 的 `audit_cache()` 测试守住。
- 合并后动画枢轴名字/层级变化会让眨眼、看向、IK、褪色、打飞帽子失效:T10 跑现有角色测试并新增 `test_patron_fade`。
- 窗口模式下的构建耗时(GPU 回读)无头测试测不出:T8 的 grep 测试 + T13 的启动耗时打印守住。
- 平放/倒地的枪与牌堆底牌要高于毡面(`FELT_TOP`),而不只是高于桌面:T17/T18 按顶点最低点断言。

---

### Task 1–3: B0 测量护栏 ✅ 已完成

- T1 `tools/scene_census.gd`、`tools/perf_budget.gd` + `tests/test_scene_census.gd`、`tests/test_perf_budget.gd`(提交 180cd28)
- T2 `tools/perf_probe.gd` 可见/阴影拆分、阴影重画、多机位、`--assert-budget`;`tools/camera_views.gd` 共用机位(提交 476630d)
- T3 `tools/image_stats.gd`、`shot.gd --stats/--freeze`、`tools/shot_diff.gd` + `tests/test_image_stats.gd`(提交 fcc3ea9)
- 基线(seat):draw call 1860 = 可见 585 + 阴影 1275;帧时间(budget)9.68 ms;CPU 0.93 ms;灯 18。

### Task 4: B1.1 MeshKit 网格缓存(设计 A1、B1.1)

**Files:** Modify `src/world/mesh_kit.gd`、`src/world/tavern.gd:183-184`、`src/ui/main.gd:82-88`;Test `tests/test_mesh_kit.gd`(新)

**Interfaces — Produces:** `MeshKit.CAPS_NONE/TOP/BOTTOM/BOTH`;`MeshKit.cylinder(top_r, bottom_r, height, segments := 32, caps := CAPS_BOTH)`;
各基础体返回只读共享资源;`MeshKit.clear_cache()`;`MeshKit.audit_cache() -> PackedStringArray`。

- [ ] 写 `tests/test_mesh_kit.gd`:同参数同实例/不同参数不同实例;0.1 与 0.10004 共用、与 0.10006 不共用且尺寸为量化值;`hemisphere(r)` 不影响 `sphere(r)` 且 `rings == maxi(segments/2, 6)`;caps 变体不同 key;搭 Tavern + 4 人 TableWorld 后 `audit_cache()` 为空;`clear_cache()` 后为空
- [ ] 运行,确认失败
- [ ] 按设计 A1 实现(量化 `roundi(x*10000)`,工厂用量化值建网格;hemisphere 独立 key;tavern 灯罩改 `CAPS_TOP`;main 释放)
- [ ] 单测通过;全量通过
- [ ] 冻结截图对比父提交:identity
- [ ] perf_probe:记录 seat/menu 数字(预期 seat ≈ 1080)
- [ ] 提交 `perf: MeshKit 基础体按参数缓存共享(触发自动实例化,外观不变)`

### Task 5: B1.2 投影策略(设计 A4、B1.2)

**Files:** Modify `src/world/mesh_kit.gd`(`add` 加 `shadow`)、`src/world/tavern.gd`(地板 `Floor` OFF;`_wall` 新签名与命名;三面实墙护墙板/灰泥 OFF,压条与窗墙照常);Test `tests/test_scene_budget.gd`(新,无头,场景用 `tools/showcase.gd`)

**Interfaces — Produces:** `MeshKit.SHADOW_AUTO/OFF/ON`、`MeshKit.SMALL_CASTER := 0.08`、`MeshKit.LAYER_WORLD := 1`、`MeshKit.LAYER_MOON := 4`;
`add(..., shadow := SHADOW_AUTO)`(按节点自身变换 × 网格 AABB 判断,显式 `SHADOW_ON` 打 `force_shadow` meta)。

- [ ] 写 `test_scene_budget.gd`:自身尺寸 < 0.08 的 MeshInstance3D 都不投影(force_shadow 豁免);`Floor`、`Wall*Wainscot`、`Wall*Plaster` OFF;`Wall*Rail`、`WindowWall*` ON;`test_mesh_kit` 加 SHADOW_AUTO 用例
- [ ] 运行确认失败 → 实现 → 通过;全量通过
- [ ] 冻结截图对比父提交:shadow 门槛 + 人工看差异
- [ ] 提交 `perf: 小件与房间壳不投影(按节点自身尺寸自动判断)`

### Task 6: B1.3 火焰共享材质(设计 B1.3)

**Files:** `src/world/shaders/flame.gdshader:9-11`、`src/world/materials.gd:98-104`、`src/world/tavern.gd`(`_flame` 辅助,替换三处);Test `test_scene_budget.gd`

- [ ] 测试:Tavern 内所有火焰共用一份材质,`seed` 实例参数各不相同 → 失败 → 实现 → 通过
- [ ] identity 对比;提交 `perf: 火焰共用一份材质(强度与种子改为实例参数)`

### Task 7: B1.4 卡牌与粒子共享资源(设计 B1.4)

**Files:** `src/world/card_3d.gd:40-41`、`src/world/fx.gd:129-150`、`src/world/materials.gd:107-114`;Test `test_scene_budget.gd`

- [ ] 测试:两张牌的牌面网格是同一资源 → 实现 → 通过;`test_fx` 不改仍通过
- [ ] identity 对比;收紧 `tools/perf_budget.gd`(B1 收紧值,`enforce_cap = false`)
- [ ] 提交 `perf: 卡牌与粒子共享网格和材质`

### Task 8: B2.1 MeshForge 核心(设计 A2、B2.1)

**Files:** Create `src/world/mesh_forge.gd`;Test `tests/test_mesh_forge.gd`(新)

**Interfaces — Produces:** 设计 A2 的完整 API(`color/ao/rough/metal/part_space/seed`、`paint`、`surface(name)`、`push/pop`、`xf`、
7 种基础体复刻、`lathe`、`build()`、`commit(built, materials)`、`cached(key, recipe, materials)`、`prebuild`、`wait_prebuilt`、`clear_cache`)。

- [ ] 写测试:7 种基础体与 `PrimitiveMesh.get_mesh_arrays()` 逐顶点一致(无头下在 CPU 上);`xf` 等于 Node3D transform;非均匀缩放法线;镜像绕序;AABB;布局与格式标志;缓存;线程池构建与同步一致;lathe 顶点数;扫描 `src/**/*.gd` 禁用 API
- [ ] 失败 → 实现 → 通过;全量通过
- [ ] 提交 `feat: MeshForge 合批构建器(复刻基础体、车削、多 surface、缓存与后台预建)`

### Task 9: B2.2 着色器与材质(设计 A3、B2.2)

**Files:** Create `src/world/shaders/vertex_pbr.gdshaderinc`、`patron.gdshader`、`prop.gdshader`、`bottle_glass.gdshader`;Modify `wood.gdshader`、`materials.gd`

- [ ] 测试:`WorldMaterials.patron()/prop()/bottle_glass()` 走缓存;`wood(preset, true)` 与 `wood(preset)` 是不同实例且 `use_part_space` 正确;`clear_cache` 后重建
- [ ] 实现;identity 对比(`use_part_space` 默认 false,外观不变)
- [ ] 提交 `feat: 顶点 PBR 共享着色器(酒客/道具/酒瓶)与木纹部件空间`

### Task 10: B2.3 + B2.4 共享椅子、酒客按枢轴合并、fade 实例参数(设计 B2.3、B2.4)

**Files:** `src/world/patron_parts.gd`、`src/world/patron_3d.gd:103-189, 431-451`;Test `tests/test_patron_fade.gd`(新)、`test_scene_budget.gd`

- [ ] 测试:每名酒客可见实例 ≤ 19(含椅子)、材质 ≤ 2(不含椅子);4 把椅子共用网格;`die()` 1.6 s 后所有 fade 目标(含打飞的帽子、MarksMesh)fade ≈ 1;酒客无私有 StandardMaterial3D
- [ ] 实现(表 B2-1 的枢轴与网格对应;配方与旧 `MeshKit.add` 一一对应)
- [ ] 现有 `test_hand_visibility/test_patron_arms/test_patron_neck/test_table_world` 原样通过
- [ ] identity 对比(另做倒下后的褪色终点对比)
- [ ] 提交 `perf: 酒客按动画枢轴合并为共享网格(每人 19 个实例),出局褪色改为实例参数;椅子共享网格`

### Task 11: B2.5 左轮三件(设计 B2.5)

**Files:** `src/world/revolver_3d.gd:15-53`;Test `test_scene_budget.gd`、`test_revolver_3d.gd`(只新增用例)

- [ ] 测试:每把 3 个可见实例;4 把枪共用 Body/Drum/Hammer 网格;`Chamber*` 是 5 个 Marker3D
- [ ] 实现 → identity 对比 → 提交 `perf: 左轮合并为机身/转轮/击锤三件共享网格`

### Task 12: B2.6 酒瓶 MultiMesh(设计 B2.6)

**Files:** `src/world/tavern.gd:284-323`;Test `test_scene_budget.gd`

- [ ] 测试:吧台下 MultiMesh 实例总数 = 原瓶数(53);瓶型 MultiMesh ≤ 6;无半透明瓶子材质;不投影
- [ ] 实现(rng 调用顺序不变)→ 除吧台外 identity,吧台人工评审 → 提交 `feat: 酒瓶改为 6 种车削瓶型的不透明假玻璃(MultiMesh)`

### Task 13: B2.7 + B2.8 月光层与 caster mask、后台预建接入(设计 A4、B2.7、B2.8)

**Files:** `src/world/tavern.gd:144-154, 194-205, 270-278, 343-361`、`src/ui/main.gd:51, 82-88`;Test `test_scene_budget.gd`

- [ ] 测试:月光 `shadow_caster_mask == LAYER_MOON`;窗框与 `WindowWall*` 在 `LAYER_MOON`;吊灯/壁炉 mask = `LAYER_WORLD`
- [ ] 实现;main 接入 `MeshForge.prebuild/wait_prebuilt` 与 `clear_cache`;启动耗时打印对比
- [ ] shadow 对比;收紧 B2 门槛(`enforce_cap = true`),`perf_probe --assert-budget` 退出码 0
- [ ] 提交 `perf: 月光只让窗墙投影;启动时后台预建共享网格`

### Task 14: B3.1 去过曝(设计 B3.1、总纲第 9 节「裁定」)

**Files:** `src/world/patron_parts.gd`、`src/world/patron_3d.gd`、`src/world/tavern.gd`(ssao_light_affect、灯泡、蜡);Test `test_patron_parts.gd`(新增用例)

- [ ] 测试:调色板最大通道 ≤ `ALBEDO_CAP`(0.65);`EYE_WHITE` 各通道 ≤ 0.72;0 < `PAW_SHADE` ≤ 0.8
- [ ] 实现;高光并进瞳孔、不自发光
- [ ] `shot --stats`:脸、爪发白 ≤ 5%(此时补上设计 B0.4 的 ID 掩码统计)
- [ ] 提交 `fix: 酒客不再过曝(调色板与眼白封顶、爪子压暗、高光不自发光、环境光遮蔽作用于直射光)`

### Task 15: B3.2–B3.4 烛光、金属、桌布金线(设计 B3.2–B3.4)

- [ ] 测试:灯 ≤ 16;烛台各 1 盏 omni 且在 `Candles*` 节点下
- [ ] 实现;截图人工检查
- [ ] 提交 `fix: 每个烛台一盏灯;枪钢与胡桃木握把、珐琅灯罩;桌布金线改为针脚不再泛光`

### Task 16: B3.5 主菜单空椅子(设计 B3.5)

- [ ] `test_table_world.gd` 新增:`clear()` 后 4 把 `EmptyChair` 可见且共用网格,`arrange()` 后隐藏 → 实现 → 提交 `feat: 主菜单牌桌摆上 4 把空椅子`

### Task 17: B3.6 卡牌相关 bug(设计 B3.6 第 1、6 项)

- [ ] `tests/test_table_props.gd`(新):`pile_y(i)`/`reveal_y` 高于 `FELT_TOP`;Felt 顶面与半径等于常量;`CardFaces.chamber_points` 点数 = `Revolver.CHAMBERS`
- [ ] 实现 → 提交 `fix: 牌堆底牌不再陷进桌布;牌背画 5 孔弹巢`

### Task 18: B3.6 左轮相关 bug 与啤酒(设计 B3.6 第 2–5、7 项)

- [ ] 测试:各人数局平放左轮顶点最低点 ≥ `FELT_TOP − 0.5 mm`;倒地 1 s 后落在桌上;举枪后枪口到头心 0.172–0.20 m;扳击转动后停在整格、Chamber1 对准枪管
- [ ] 实现 → 提交 `fix: 左轮不再陷进桌面、倒地落回桌沿、枪口不插进头;转轮停在整格对准枪管;啤酒不自发光`

### Task 19: 验收(设计「① 发版验收」)

- [ ] 收紧 B3 门槛;`perf_probe --assert-budget` 全视角退出码 0;记录帧时间、CPU
- [ ] 全量 GUT;`tools/lan_smoke.sh`;10 个视角截图人工核对
- [ ] 更新 README 工具用法;总纲状态行
- [ ] 提交;**不推送、不发版**(等用户确认)
