extends GutTest
# 更新相关的界面判断:横幅在各状态下的文字与按钮、房间列表何时给出"更新"按钮。


const MenuScript := preload("res://src/ui/main_menu/main_menu.gd")
const MANIFEST := {"version": "0.6.0", "notes": "修了些小毛病"}


func test_banner_hidden_when_idle():
	assert_false(UpdateBanner.describe(Updater.State.IDLE, {}, "", "", 0.0)["visible"])


func test_banner_offers_update_then_restart():
	var available := UpdateBanner.describe(Updater.State.AVAILABLE, MANIFEST, "房主 老王", "", 0.0)
	assert_string_contains(available["title"], "0.6.0")
	assert_string_contains(available["detail"], "房主 老王")
	assert_eq(available["action"], "更新")
	var downloading := UpdateBanner.describe(Updater.State.DOWNLOADING, MANIFEST, "", "", 0.456)
	assert_string_contains(downloading["title"], "46%")
	assert_eq(downloading["action"], "", "下载中不能再点")
	assert_eq(UpdateBanner.describe(Updater.State.READY, MANIFEST, "", "", 1.0)["action"], "重启")


func test_banner_explains_why_not():
	var blocked := UpdateBanner.describe(Updater.State.BLOCKED, {}, "", "需要重新下载完整安装包", 0.0)
	assert_eq(blocked["detail"], "需要重新下载完整安装包")
	assert_true(blocked["closable"])
	assert_eq(blocked["action"], "")


func test_room_offers_update_only_when_host_serves_a_newer_build():
	var room := {"update": true, "build": 5, "plat": "macos"}
	assert_true(MenuScript.offers_update(room, 4, "macos"))
	assert_false(MenuScript.offers_update(room, 5, "macos"), "同版本")
	assert_false(MenuScript.offers_update(room.merged({"update": false}, true), 4, "macos"), "房主没提供更新文件")
	assert_false(MenuScript.offers_update(room, 4, "windows"), "别的系统的更新包用不了")
	assert_false(MenuScript.offers_update({}, 4, "macos"), "旧房主的报文没有这些字段")


func test_lan_source_url():
	assert_eq(Updater.lan_source("192.168.1.8", 47810), "http://192.168.1.8:47810/%s/" % BuildInfo.platform())
