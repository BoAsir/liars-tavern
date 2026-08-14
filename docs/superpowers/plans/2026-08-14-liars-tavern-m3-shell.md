# M3:入口场景、主菜单与等待厅

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 可运行的 UI 外壳:主菜单(昵称/建房/房间列表/手输 IP)→ 等待厅(准备/开始/踢人)。完成后两台实例可以互相发现并进入同一等待厅。

**Architecture:** 只有一个 `main.tscn` 入口场景;各屏幕(MainMenu/Lobby/Table)是纯 GDScript 构建的 Control,由 `main.gd` 根据 `Net` 的信号切换。UI 不直接碰 multiplayer API。

**依赖:** M2 完成。牌桌 Table 在 M4 实现,本里程碑 `game_started` 信号暂以占位屏幕呈现(M4 替换为真牌桌)。

**手动验收环境说明:** 同机多开时 UDP 发现端口只有一个实例能绑定,房间列表可能为空——用手输 `127.0.0.1` 直连,这是预期行为。

---

### Task 1: 入口场景与屏幕切换

**Files:**
- Create: `src/ui/main.gd`
- Create: `src/ui/main.tscn`
- Modify: `project.godot`(`[application]` 节加 main_scene)

- [ ] **Step 1: 实现 `src/ui/main.gd`**

```gdscript
extends Control
# 屏幕管理:根据 Net 信号在 主菜单 / 等待厅 / 牌桌 之间切换。


const MainMenuScreen := preload("res://src/ui/main_menu/main_menu.gd")
const LobbyScreen := preload("res://src/ui/lobby/lobby.gd")

var current_screen: Control = null


func _ready() -> void:
	Net.joined_lobby.connect(_show_lobby)
	Net.returned_to_lobby.connect(_show_lobby)
	Net.left_lobby.connect(_back_to_menu)
	Net.game_started.connect(_show_table)
	_show_menu()


func _show_menu() -> void:
	_switch_to(MainMenuScreen.new())


func _show_lobby() -> void:
	_switch_to(LobbyScreen.new())


func _show_table() -> void:
	# M4 将替换为真正的牌桌场景
	var placeholder := Label.new()
	placeholder.text = "牌桌开发中(M4)"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_switch_to(placeholder)


func _back_to_menu(reason: String) -> void:
	_show_menu()
	if reason != "":
		var dialog := AcceptDialog.new()
		dialog.dialog_text = reason
		add_child(dialog)
		dialog.popup_centered()


func _switch_to(screen: Control) -> void:
	if current_screen != null:
		current_screen.queue_free()
	current_screen = screen
	add_child(screen)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
```

- [ ] **Step 2: 写 `src/ui/main.tscn`**(手写文本格式,仅一个根节点挂脚本)

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://src/ui/main.gd" id="1"]

[node name="Main" type="Control"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("1")
```

- [ ] **Step 3: 在 `project.godot` 的 `[application]` 节追加**

```ini
run/main_scene="res://src/ui/main.tscn"
```

- [ ] **Step 4: 验证(此时 main_menu.gd 还不存在,preload 会报错——先创建两个空壳)**

创建 `src/ui/main_menu/main_menu.gd` 与 `src/ui/lobby/lobby.gd` 占位(Task 2/3 覆盖为完整实现):

```gdscript
extends Control
```

Run: `$GODOT --headless --path . --import && $GODOT --headless --path . --quit-after 2`
Expected: 启动无脚本错误后自动退出(退出码 0)。

- [ ] **Step 5: 跑测试确认全绿,Commit**

```bash
git add src/ui project.godot
git commit -m "feat: 入口场景与屏幕切换骨架"
```

### Task 2: 主菜单

**Files:**
- Modify: `src/ui/main_menu/main_menu.gd`(替换占位内容)

- [ ] **Step 1: 实现 `src/ui/main_menu/main_menu.gd`**

```gdscript
extends Control
# 主菜单:昵称(本地持久化)/ 建房 / 自动发现房间列表 / 手输 IP 直连。


const SETTINGS_PATH := "user://settings.cfg"

var name_edit: LineEdit
var room_edit: LineEdit
var ip_edit: LineEdit
var room_list: VBoxContainer
var status_label: Label


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "骗子酒馆"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	name_edit = LineEdit.new()
	name_edit.placeholder_text = "输入昵称"
	name_edit.text = _load_saved_name()
	box.add_child(name_edit)

	room_edit = LineEdit.new()
	room_edit.placeholder_text = "房间名(建房用,留空取默认)"
	box.add_child(room_edit)

	var host_button := Button.new()
	host_button.text = "创建房间"
	host_button.pressed.connect(_on_host_pressed)
	box.add_child(host_button)

	var list_title := Label.new()
	list_title.text = "局域网房间:"
	box.add_child(list_title)

	room_list = VBoxContainer.new()
	box.add_child(room_list)

	var ip_row := HBoxContainer.new()
	box.add_child(ip_row)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "手输 IP 直连,如 192.168.1.10"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_row.add_child(ip_edit)
	var join_button := Button.new()
	join_button.text = "加入"
	join_button.pressed.connect(_on_join_ip_pressed)
	ip_row.add_child(join_button)

	status_label = Label.new()
	status_label.modulate = Color(1.0, 0.6, 0.6)
	box.add_child(status_label)

	Discovery.rooms_updated.connect(_refresh_rooms)
	Discovery.start_listening()
	Net.join_failed.connect(_on_join_failed)
	_refresh_rooms(Discovery.get_rooms())


func _exit_tree() -> void:
	Discovery.stop_listening()


func _refresh_rooms(rooms: Array) -> void:
	for child in room_list.get_children():
		child.queue_free()
	if rooms.is_empty():
		var empty := Label.new()
		empty.text = "(未发现房间,可手输 IP 直连)"
		room_list.add_child(empty)
		return
	for room in rooms:
		var button := Button.new()
		button.text = "%s — 房主 %s(%d/%d)" % [
			room["room"], room["host"], room["players"], room["max"],
		]
		button.pressed.connect(_join.bind(room["ip"]))
		room_list.add_child(button)


func _on_host_pressed() -> void:
	var pname := _validated_name()
	if pname == "":
		return
	var room_name := room_edit.text.strip_edges()
	if room_name == "":
		room_name = "%s 的酒馆" % pname
	Discovery.stop_listening()
	if Net.host_game(pname, room_name) != OK:
		status_label.text = "建房失败:端口 %d 被占用?" % Protocol.GAME_PORT
		Discovery.start_listening()


func _on_join_ip_pressed() -> void:
	_join(ip_edit.text.strip_edges())


func _join(ip: String) -> void:
	var pname := _validated_name()
	if pname == "":
		return
	if not ip.is_valid_ip_address():
		status_label.text = "IP 地址无效"
		return
	status_label.text = "连接中..."
	Net.join_game(pname, ip)


func _on_join_failed(reason: String) -> void:
	status_label.text = reason


func _validated_name() -> String:
	var pname := name_edit.text.strip_edges()
	if pname == "":
		status_label.text = "请先输入昵称"
		return ""
	_save_name(pname)
	return pname


func _load_saved_name() -> String:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		return config.get_value("player", "name", "")
	return ""


func _save_name(pname: String) -> void:
	var config := ConfigFile.new()
	config.set_value("player", "name", pname)
	config.save(SETTINGS_PATH)
```

- [ ] **Step 2: 手动验证主菜单渲染**

Run: `$GODOT --path . &`(打开窗口,看到标题、昵称框、建房按钮、房间列表、IP 输入;关闭窗口)
Expected: 无脚本报错。

- [ ] **Step 3: Commit**

```bash
git add src/ui/main_menu/main_menu.gd
git commit -m "feat: 主菜单(昵称持久化/建房/房间发现列表/手输IP)"
```

### Task 3: 等待厅

**Files:**
- Modify: `src/ui/lobby/lobby.gd`(替换占位内容)

- [ ] **Step 1: 实现 `src/ui/lobby/lobby.gd`**

```gdscript
extends Control
# 等待厅:玩家列表 / 准备切换(客) / 开始与踢人(房主) / 离开。


var list_box: VBoxContainer
var ready_button: Button = null
var start_button: Button = null
var is_ready := false


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "等待厅(%d-%d 人,全员准备后房主开局)" % [Protocol.MIN_PLAYERS, Protocol.MAX_PLAYERS]
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	list_box = VBoxContainer.new()
	box.add_child(list_box)

	if Net.is_host:
		start_button = Button.new()
		start_button.text = "开始游戏"
		start_button.disabled = true
		start_button.pressed.connect(_on_start_pressed)
		box.add_child(start_button)
	else:
		ready_button = Button.new()
		ready_button.text = "准备"
		ready_button.pressed.connect(_on_ready_toggled)
		box.add_child(ready_button)

	var leave_button := Button.new()
	leave_button.text = "离开房间"
	leave_button.pressed.connect(_on_leave_pressed)
	box.add_child(leave_button)

	Net.lobby_updated.connect(_refresh)
	if Net.is_host:
		_refresh(Net.lobby_view())


func _on_start_pressed() -> void:
	Net.start_game()


func _on_ready_toggled() -> void:
	is_ready = not is_ready
	ready_button.text = "取消准备" if is_ready else "准备"
	Net.set_ready(is_ready)


func _on_leave_pressed() -> void:
	Net.leave()
	Net.left_lobby.emit("")


func _refresh(players: Array) -> void:
	for child in list_box.get_children():
		child.queue_free()
	for player in players:
		var row := HBoxContainer.new()
		var label := Label.new()
		var tags := []
		if player["is_host"]:
			tags.append("房主")
		tags.append("已准备" if player["ready"] else "未准备")
		label.text = "%s(%s)" % [player["name"], "、".join(tags)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		if Net.is_host and not player["is_host"]:
			var kick_button := Button.new()
			kick_button.text = "踢出"
			kick_button.pressed.connect(Net.kick.bind(player["pid"]))
			row.add_child(kick_button)
		list_box.add_child(row)
	if start_button != null:
		start_button.disabled = not Net.can_start()
```

- [ ] **Step 2: 双实例手动验收**

```bash
$GODOT --path . &
$GODOT --path . &
```

清单:
1. 实例 A 输入昵称"甲",建房 → 进等待厅,显示"甲(房主、已准备)"。
2. 实例 B 输入昵称"乙",手输 `127.0.0.1` 加入 → 双方列表都显示两人。
3. 乙点"准备" → 甲端开始按钮变为可用;乙点"取消准备" → 按钮变灰。
4. 甲点"踢出"乙 → 乙弹窗"与房主断开连接"回主菜单。
5. 乙重进,甲点"开始游戏" → 双方进入"牌桌开发中(M4)"占位屏。
6. 关闭甲实例 → 乙弹窗回主菜单。

Expected: 全部符合,无脚本报错。

- [ ] **Step 3: 跑测试确认全绿,Commit**

```bash
git add src/ui/lobby/lobby.gd
git commit -m "feat: 等待厅(准备/开始/踢人/离开)"
```
