# M1a:项目脚手架与基础逻辑(牌/牌堆/左轮/规则)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 Godot 项目与 GUT 测试环境,TDD 实现四个无依赖的核心模块。

**Architecture:** `src/core/` 下全部为 `class_name` 静态类/RefCounted,不依赖节点树,GUT 直接单测。

**Tech Stack:** Godot 4.7 headless、GUT 9.x。

前置:`export GODOT="/Applications/Godot.app/Contents/MacOS/Godot"`;工作目录 `/Users/murphy/Desktop/dev/LiarsTavern`。

---

### Task 1: 项目脚手架

**Files:**
- Create: `project.godot`
- Create: `.gitignore`

- [ ] **Step 1: 写 project.godot**

```ini
; Engine configuration file.
config_version=5

[application]
config/name="骗子酒馆"

[display]
window/size/viewport_width=1280
window/size/viewport_height=720
```

- [ ] **Step 2: 写 .gitignore**

```gitignore
.godot/
.DS_Store
```

- [ ] **Step 3: 首次导入,验证工程可被 Godot 识别**

Run: `$GODOT --headless --path . --import`
Expected: 正常退出(退出码 0),生成 `.godot/` 目录。

- [ ] **Step 4: Commit**

```bash
git add project.godot .gitignore
git commit -m "chore: Godot 4 项目脚手架"
```

### Task 2: 引入 GUT 测试框架

**Files:**
- Create: `addons/gut/`(vendored)
- Create: `tests/test_smoke.gd`

- [ ] **Step 1: 下载并复制 GUT**

```bash
git clone --depth 1 https://github.com/bitwes/Gut.git /private/tmp/claude-501/-Users-murphy-Desktop-dev-NoteBook/be62b607-7770-4784-af34-121a56e56f84/scratchpad/gut-checkout
mkdir -p addons
cp -r /private/tmp/claude-501/-Users-murphy-Desktop-dev-NoteBook/be62b607-7770-4784-af34-121a56e56f84/scratchpad/gut-checkout/addons/gut addons/gut
rm -rf /private/tmp/claude-501/-Users-murphy-Desktop-dev-NoteBook/be62b607-7770-4784-af34-121a56e56f84/scratchpad/gut-checkout
$GODOT --headless --path . --import
```

- [ ] **Step 2: 写冒烟测试 `tests/test_smoke.gd`**

```gdscript
extends GutTest


func test_gut_works():
	assert_true(true)
```

- [ ] **Step 3: 跑测试**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: `1 passed`,退出码 0。

- [ ] **Step 4: Commit**

```bash
git add addons tests
git commit -m "chore: 引入 GUT 测试框架并跑通冒烟测试"
```

### Task 3: 牌面常量 Card + 牌堆 Deck(TDD)

**Files:**
- Create: `src/core/card.gd`
- Create: `src/core/deck.gd`
- Test: `tests/test_deck.gd`

- [ ] **Step 1: 写失败测试 `tests/test_deck.gd`**

```gdscript
extends GutTest


func test_card_matches_target_or_joker():
	assert_true(Card.matches(Card.QUEEN, Card.QUEEN))
	assert_true(Card.matches(Card.JOKER, Card.QUEEN))
	assert_false(Card.matches(Card.KING, Card.QUEEN))


func test_deck_composition():
	var cards := Deck.build()
	assert_eq(cards.size(), 20)
	assert_eq(cards.count(Card.QUEEN), 6)
	assert_eq(cards.count(Card.KING), 6)
	assert_eq(cards.count(Card.ACE), 6)
	assert_eq(cards.count(Card.JOKER), 2)


func test_deal_gives_five_cards_each_and_uses_whole_deck_for_four():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var hands := Deck.deal([1, 2, 3, 4], rng)
	assert_eq(hands.size(), 4)
	var all_cards := []
	for pid in hands:
		assert_eq(hands[pid].size(), 5)
		all_cards.append_array(hands[pid])
	all_cards.sort()
	var full := Array(Deck.build())
	full.sort()
	assert_eq(all_cards, full)


func test_pick_target_is_never_joker():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		var target := Deck.pick_target(rng)
		assert_true(target in [Card.QUEEN, Card.KING, Card.ACE])
```

- [ ] **Step 2: 跑测试验证失败**

Run: 跑测试命令。
Expected: FAIL(解析错误:`Card`/`Deck` 未定义)。

- [ ] **Step 3: 实现 `src/core/card.gd`**

```gdscript
class_name Card
# 牌面常量:用 int 表示,便于 RPC 序列化。


const QUEEN := 0
const KING := 1
const ACE := 2
const JOKER := 3

const NAMES := {QUEEN: "Q", KING: "K", ACE: "A", JOKER: "鬼"}


static func matches(card: int, target: int) -> bool:
	return card == target or card == JOKER
```

- [ ] **Step 4: 实现 `src/core/deck.gd`**

```gdscript
class_name Deck
# 牌堆:Q/K/A 各 6 张 + 鬼牌 2 张,共 20 张。


const HAND_SIZE := 5
const COMPOSITION := {Card.QUEEN: 6, Card.KING: 6, Card.ACE: 6, Card.JOKER: 2}


static func build() -> Array[int]:
	var cards: Array[int] = []
	for card_type in COMPOSITION:
		for i in COMPOSITION[card_type]:
			cards.append(card_type)
	return cards


static func deal(player_ids: Array, rng: RandomNumberGenerator) -> Dictionary:
	# 返回 {player_id: Array 五张手牌},Fisher-Yates 洗牌。
	var cards := build()
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	var hands := {}
	var idx := 0
	for pid in player_ids:
		hands[pid] = Array(cards.slice(idx, idx + HAND_SIZE))
		idx += HAND_SIZE
	return hands


static func pick_target(rng: RandomNumberGenerator) -> int:
	return [Card.QUEEN, Card.KING, Card.ACE][rng.randi_range(0, 2)]
```

- [ ] **Step 5: 跑测试验证通过**

Expected: test_deck 4 个用例 PASS。

- [ ] **Step 6: Commit**

```bash
git add src/core/card.gd src/core/deck.gd tests/test_deck.gd
git commit -m "feat: 牌面常量与牌堆(构建/洗牌/发牌/抽目标)"
```

### Task 4: 左轮手枪 Revolver(TDD)

**Files:**
- Create: `src/core/revolver.gd`
- Test: `tests/test_revolver.gd`

- [ ] **Step 1: 写失败测试 `tests/test_revolver.gd`**

```gdscript
extends GutTest


func test_exactly_one_hit_in_six_pulls():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var revolver := Revolver.new(rng)
		var hits := 0
		for pull in 6:
			if revolver.pull_trigger():
				hits += 1
		assert_eq(hits, 1)


func test_shots_fired_counts_pulls():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var revolver := Revolver.new(rng)
	assert_eq(revolver.shots_fired(), 0)
	revolver.pull_trigger()
	assert_eq(revolver.shots_fired(), 1)


func test_bullet_in_chamber_one_hits_immediately():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var revolver := Revolver.new(rng)
	revolver.bullet_chamber = 1
	revolver.next_chamber = 1
	assert_true(revolver.pull_trigger())
```

- [ ] **Step 2: 跑测试验证失败**

Expected: FAIL(`Revolver` 未定义)。

- [ ] **Step 3: 实现 `src/core/revolver.gd`**

```gdscript
class_name Revolver
# 六膛左轮:整局装 1 发子弹于随机膛位,空枪后弹巢前进。


const CHAMBERS := 6

var bullet_chamber: int
var next_chamber := 1


func _init(rng: RandomNumberGenerator) -> void:
	bullet_chamber = rng.randi_range(1, CHAMBERS)


func pull_trigger() -> bool:
	var hit := next_chamber == bullet_chamber
	next_chamber += 1
	return hit


func shots_fired() -> int:
	return next_chamber - 1
```

- [ ] **Step 4: 跑测试验证通过**

Expected: test_revolver 3 个用例 PASS。

- [ ] **Step 5: Commit**

```bash
git add src/core/revolver.gd tests/test_revolver.gd
git commit -m "feat: 六膛左轮模型"
```

### Task 5: 规则判定 Rules(TDD)

**Files:**
- Create: `src/core/rules.gd`
- Test: `tests/test_rules.gd`

- [ ] **Step 1: 写失败测试 `tests/test_rules.gd`**

```gdscript
extends GutTest


func test_play_must_be_one_to_three_cards():
	assert_false(Rules.is_play_valid(5, []))
	assert_true(Rules.is_play_valid(5, [0]))
	assert_true(Rules.is_play_valid(5, [0, 2, 4]))
	assert_false(Rules.is_play_valid(5, [0, 1, 2, 3]))


func test_play_indices_must_be_in_hand_and_unique():
	assert_false(Rules.is_play_valid(5, [-1]))
	assert_false(Rules.is_play_valid(5, [5]))
	assert_false(Rules.is_play_valid(5, [1, 1]))
	assert_false(Rules.is_play_valid(5, [1.5]))
	assert_true(Rules.is_play_valid(2, [0, 1]))


func test_honesty_all_target_or_joker():
	assert_true(Rules.is_honest([Card.QUEEN, Card.QUEEN], Card.QUEEN))
	assert_true(Rules.is_honest([Card.QUEEN, Card.JOKER], Card.QUEEN))
	assert_true(Rules.is_honest([Card.JOKER, Card.JOKER], Card.ACE))
	assert_false(Rules.is_honest([Card.QUEEN, Card.KING], Card.QUEEN))
	assert_false(Rules.is_honest([Card.KING], Card.QUEEN))
```

- [ ] **Step 2: 跑测试验证失败**

Expected: FAIL(`Rules` 未定义)。

- [ ] **Step 3: 实现 `src/core/rules.gd`**

```gdscript
class_name Rules
# 出牌合法性与质疑诚实判定。


const MIN_PLAY := 1
const MAX_PLAY := 3


static func is_play_valid(hand_size: int, indices: Array) -> bool:
	if indices.size() < MIN_PLAY or indices.size() > MAX_PLAY:
		return false
	var seen := {}
	for i in indices:
		if typeof(i) != TYPE_INT or i < 0 or i >= hand_size:
			return false
		if seen.has(i):
			return false
		seen[i] = true
	return true


static func is_honest(cards: Array, target: int) -> bool:
	for card in cards:
		if not Card.matches(card, target):
			return false
	return true
```

- [ ] **Step 4: 跑测试验证通过**

Expected: test_rules 3 个用例 PASS,且此前所有测试仍 PASS。

- [ ] **Step 5: Commit**

```bash
git add src/core/rules.gd tests/test_rules.gd
git commit -m "feat: 出牌合法性与诚实判定规则"
```
