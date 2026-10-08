extends GutTest
# PerfBudget:性能探针按机位核对预算,超出的每项给一条中文说明(--assert-budget 据此返回非零)。

const PerfBudget := preload("res://tools/perf_budget.gd")


func test_within_budget_reports_nothing():
	var stats := {"draw_calls": 400, "frame_ms": 9.0, "cpu_ms": 0.7, "lights": 16}
	assert_eq(PerfBudget.violations("seat", stats).size(), 0)


func test_each_exceeded_limit_reports_one_message():
	var stats := {"draw_calls": 1799, "frame_ms": 11.0, "cpu_ms": 0.5, "lights": 18}
	var messages := PerfBudget.violations("seat", stats)
	assert_eq(messages.size(), 3)
	assert_string_contains(messages[0] + messages[1] + messages[2], "draw_calls")


func test_menu_and_other_views_have_their_own_draw_call_limits():
	assert_eq(PerfBudget.LIMITS["seat"]["draw_calls"], 450)
	assert_eq(PerfBudget.LIMITS["menu"]["draw_calls"], 470)
	for view in ["opponent", "closeup", "gun", "bar", "window", "fireplace", "overhead", "selfshot"]:
		assert_eq(PerfBudget.LIMITS[view]["draw_calls"], 500, view)


func test_missing_stats_are_not_violations():
	assert_eq(PerfBudget.violations("seat", {"draw_calls": 100}).size(), 0)


func test_unknown_view_reports_nothing():
	assert_eq(PerfBudget.violations("nowhere", {"draw_calls": 99999}).size(), 0)
