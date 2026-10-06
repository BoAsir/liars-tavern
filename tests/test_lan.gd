extends GutTest


func test_private_ranges():
	for ip in ["10.1.2.3", "172.16.0.1", "172.31.255.9", "192.168.0.5"]:
		assert_true(Lan.is_private_ipv4(ip), ip)
	for ip in ["172.15.0.1", "172.32.0.1", "8.8.8.8", "127.0.0.1", "169.254.1.1", "fe80::1", "abc"]:
		assert_false(Lan.is_private_ipv4(ip), ip)


func test_private_ipv4s_filters_sorts_and_dedupes():
	var out := Lan.private_ipv4s(["fe80::1", "192.168.1.9", "127.0.0.1", "10.0.0.2", "192.168.1.9"])
	assert_eq(out, ["10.0.0.2", "192.168.1.9"])


func test_broadcast_targets_include_global_directed_and_loopback():
	var targets := Lan.broadcast_targets(["192.168.1.9", "10.0.0.2", "8.8.8.8"])
	assert_eq(targets[0], "255.255.255.255")
	assert_has(targets, "192.168.1.255")
	assert_has(targets, "10.0.0.255")
	assert_has(targets, "127.0.0.1")
	assert_does_not_have(targets, "8.8.8.255")


func test_broadcast_targets_without_interfaces_still_has_global_and_loopback():
	assert_eq(Lan.broadcast_targets([]), ["255.255.255.255", "127.0.0.1"])
