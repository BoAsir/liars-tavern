extends GutTest


func _iface(iface_name: String, addresses: Array, friendly := "") -> Dictionary:
	# 与 IP.get_local_interfaces() 的结构一致(macOS/Linux 上 friendly 与 name 相同)
	return {"name": iface_name, "friendly": friendly if friendly != "" else iface_name, "addresses": addresses}


func test_private_ranges():
	for ip in ["10.1.2.3", "172.16.0.1", "172.31.255.9", "192.168.0.5"]:
		assert_true(Lan.is_private_ipv4(ip), ip)
	for ip in ["172.15.0.1", "172.32.0.1", "8.8.8.8", "127.0.0.1", "169.254.1.1", "fe80::1", "abc", "10.999.1.1"]:
		assert_false(Lan.is_private_ipv4(ip), ip)


func test_ipv4_int_roundtrip_and_validation():
	assert_eq(Lan.int_to_ipv4(Lan.ipv4_to_int("10.20.0.42")), "10.20.0.42")
	assert_eq(Lan.ipv4_to_int("0.0.0.1"), 1)
	assert_eq(Lan.int_to_ipv4(Lan.ipv4_to_int("255.255.255.255")), "255.255.255.255")
	for bad in ["", "1.2.3", "1.2.3.4.5", "256.1.1.1", "1.2.3.x", "fe80::1", "-1.2.3.4"]:
		assert_eq(Lan.ipv4_to_int(bad), -1, bad)


# —— 广播目标 ——

func test_broadcast_targets_include_global_directed_and_loopback():
	var targets := Lan.broadcast_targets(["192.168.1.9", "10.0.0.2", "8.8.8.8"])
	assert_eq(targets[0], "255.255.255.255")
	assert_eq(targets[-1], "127.0.0.1")
	assert_has(targets, "192.168.1.255")
	assert_has(targets, "10.0.0.255")
	assert_does_not_have(targets, "8.8.8.255")


func test_broadcast_targets_cover_non_24_subnets():
	# 实测开发机:10.20.0.42/21 的子网广播是 10.20.7.255,按 /24 推的 10.20.0.255 只是一台主机地址
	var targets := Lan.broadcast_targets(["10.20.0.42"])
	for expected in ["10.20.0.255", "10.20.1.255", "10.20.3.255", "10.20.7.255", "10.20.15.255",
			"10.20.255.255", "10.255.255.255"]:
		assert_has(targets, expected)


func test_broadcast_targets_use_block_wide_prefix_for_172_16():
	var targets := Lan.broadcast_targets(["172.20.5.6"])
	assert_has(targets, "172.20.5.255")
	assert_has(targets, "172.31.255.255")


func test_broadcast_targets_include_link_local_subnet():
	# 两台电脑网线直连、没有 DHCP 时只有 169.254/16 地址
	assert_has(Lan.broadcast_targets(["169.254.3.4"]), "169.254.255.255")


func test_broadcast_targets_are_deduped():
	var targets := Lan.broadcast_targets(["192.168.1.9", "192.168.1.10", "fe80::1", "127.0.0.1"])
	var seen := {}
	for target in targets:
		assert_false(seen.has(target), "duplicate %s" % target)
		seen[target] = true
	assert_eq(targets.count("127.0.0.1"), 1)


func test_broadcast_targets_without_interfaces_still_has_global_and_loopback():
	assert_eq(Lan.broadcast_targets([]), ["255.255.255.255", "127.0.0.1"])


func test_primary_targets_are_global_and_loopback_only():
	# 其余定向广播都是推测目标:发送失败属正常,发现模块不必告警
	assert_eq(Lan.primary_broadcast_targets(), ["255.255.255.255", "127.0.0.1"])
	for target in Lan.primary_broadcast_targets():
		assert_has(Lan.broadcast_targets(["10.20.0.42"]), target)


# —— 房主地址排序 ——

func test_rank_puts_virtual_adapters_last():
	# Windows:WSL2/Hyper-V 的 vEthernet 排在真实 Wi-Fi 后面
	var interfaces := [
		_iface("{6B0A}", ["172.23.96.1", "fe80::1"], "vEthernet (WSL)"),
		_iface("{9C1D}", ["192.168.1.20", "fe80::2"], "Wi-Fi"),
		_iface("{0001}", ["127.0.0.1"], "Loopback Pseudo-Interface 1"),
	]
	assert_eq(Lan.rank_lan_addresses(interfaces), ["192.168.1.20", "172.23.96.1"])


func test_rank_mac_with_parallels_and_vpn():
	var interfaces := [
		_iface("lo0", ["127.0.0.1", "::1"]),
		_iface("vnic0", ["10.211.55.2"]),
		_iface("vnic1", ["10.37.129.2"]),
		_iface("utun3", ["fe80::3"]),
		_iface("en0", ["fe80::4", "192.168.1.8"]),
	]
	assert_eq(Lan.rank_lan_addresses(interfaces), ["192.168.1.8", "10.211.55.2", "10.37.129.2"])


func test_rank_orders_physical_ranges_192_then_10_then_172():
	var interfaces := [
		_iface("en1", ["172.16.5.5"]),
		_iface("en2", ["10.1.1.1"]),
		_iface("en3", ["192.168.0.2"]),
	]
	assert_eq(Lan.rank_lan_addresses(interfaces), ["192.168.0.2", "10.1.1.1", "172.16.5.5"])


func test_rank_detects_virtual_names_case_insensitively():
	for label in ["VirtualBox Host-Only Ethernet Adapter", "vboxnet0", "VMware Network Adapter VMnet8",
			"vmnet1", "docker0", "bridge100", "utun4", "Tailscale", "ZeroTier One [8056c2e21c]",
			"Hyper-V Virtual Ethernet Adapter", "Parallels Shared Networking"]:
		var interfaces := [_iface("x0", ["10.9.9.9"], label), _iface("en0", ["172.18.0.5"])]
		assert_eq(Lan.rank_lan_addresses(interfaces)[0], "172.18.0.5", label)


func test_rank_falls_back_to_non_private_addresses_but_never_loopback():
	# 网线直连(169.254)、运营商级 NAT 组网(100.64/10)或非 RFC1918 的局域网
	var interfaces := [
		_iface("lo0", ["127.0.0.1"]),
		_iface("eth1", ["203.0.113.7"]),
		_iface("tailscale0", ["100.101.102.103"]),
		_iface("en0", ["169.254.10.20"]),
	]
	assert_eq(Lan.rank_lan_addresses(interfaces), ["169.254.10.20", "203.0.113.7", "100.101.102.103"])


func test_rank_skips_fallback_when_a_physical_private_address_exists():
	var interfaces := [_iface("en5", ["169.254.7.7"]), _iface("en0", ["192.168.1.8"])]
	assert_eq(Lan.rank_lan_addresses(interfaces), ["192.168.1.8"])


func test_rank_keeps_physical_fallback_when_private_addresses_are_all_virtual():
	# 只有 docker0 有私网地址时,它连不上;网线直连的实体网卡地址要排在前面
	var interfaces := [_iface("docker0", ["172.17.0.1"]), _iface("eth0", ["169.254.4.4"])]
	assert_eq(Lan.rank_lan_addresses(interfaces), ["169.254.4.4", "172.17.0.1"])


func test_rank_dedupes_and_handles_empty_input():
	assert_eq(Lan.rank_lan_addresses([]), [])
	assert_eq(Lan.rank_lan_addresses([_iface("lo0", ["127.0.0.1", "::1"])]), [])
	var interfaces := [_iface("en0", ["192.168.1.8"]), _iface("en1", ["192.168.1.8"])]
	assert_eq(Lan.rank_lan_addresses(interfaces), ["192.168.1.8"])
