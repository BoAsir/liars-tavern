class_name Lan
# 本机局域网地址工具:IPv4 解析与网段判断、广播目标推导、房主地址排序。
# 网卡掩码拿不到,子网广播只能按常见前缀推测;地址排序只看网卡名与网段。


const GLOBAL_BROADCAST := "255.255.255.255"
const LOOPBACK := "127.0.0.1"
const IPV4_MAX := 0xFFFFFFFF

# 网段 = [网络地址, 前缀长度]
const BLOCK_192_168 := ["192.168.0.0", 16]
const BLOCK_10 := ["10.0.0.0", 8]
const BLOCK_172_16 := ["172.16.0.0", 12]
const BLOCK_LINK_LOCAL := ["169.254.0.0", 16]
const BLOCK_CGNAT := ["100.64.0.0", 10]
# 私网段按「最可能是玩家所在局域网」排序:家用路由 → 公司网络 → 常被虚拟网卡占用的 172.16
const PRIVATE_BLOCKS := [BLOCK_192_168, BLOCK_10, BLOCK_172_16]
# 实体网卡都没有私网地址时的退路:网线直连 → 运营商级 NAT(组网 VPN)→ 其他
const FALLBACK_BLOCKS := [BLOCK_LINK_LOCAL, BLOCK_CGNAT]
# 回环、"本网络"、组播与保留段:不是能给别人连的地址
const UNUSABLE_BLOCKS := [["127.0.0.0", 8], ["0.0.0.0", 8], ["224.0.0.0", 3]]

# 推测子网广播时尝试的前缀;另加私网段自身的前缀(10/8、172.16/12 整段可能就是一个子网)
const COMMON_PREFIXES := [24, 23, 22, 21, 20, 16]

# 网卡名/友好名里出现这些词(不区分大小写)就当作虚拟网卡,地址排到最后
const VIRTUAL_HINTS := [
	"vethernet", "wsl", "hyper-v", "virtualbox", "vboxnet", "vmware", "vmnet", "parallels",
	"vnic", "docker", "bridge", "virbr", "utun", "tailscale", "zerotier",
]


# —— IPv4 解析 ——

static func ipv4_to_int(ip: String) -> int:
	# 非法(含 IPv6)返回 -1
	var octets := ip.split(".")
	if octets.size() != 4:
		return -1
	var value := 0
	for octet in octets:
		if not octet.is_valid_int():
			return -1
		var part := octet.to_int()
		if part < 0 or part > 255:
			return -1
		value = (value << 8) | part
	return value


static func int_to_ipv4(value: int) -> String:
	return "%d.%d.%d.%d" % [(value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]


static func in_block(ip: String, block: Array) -> bool:
	var value := ipv4_to_int(ip)
	if value < 0:
		return false
	var mask := _prefix_mask(block[1])
	return (value & mask) == (ipv4_to_int(block[0]) & mask)


static func is_private_ipv4(ip: String) -> bool:
	return _first_block(ip, PRIVATE_BLOCKS) >= 0


static func _prefix_mask(prefix: int) -> int:
	return (IPV4_MAX << (32 - prefix)) & IPV4_MAX


static func _first_block(ip: String, blocks: Array) -> int:
	for i in blocks.size():
		if in_block(ip, blocks[i]):
			return i
	return -1


# —— 广播目标 ——

static func broadcast_targets(addresses: Array) -> Array:
	# 全局广播只走默认网卡;再补各私网/链路本地网卡的推测子网广播;回环保证同机实例必达
	var targets := [GLOBAL_BROADCAST]
	for ip in addresses:
		for target in directed_broadcasts(ip):
			if not targets.has(target):
				targets.append(target)
	targets.append(LOOPBACK)
	return targets


static func primary_broadcast_targets() -> Array:
	# 必定有效的目标;broadcast_targets 里其余的都是推测,发送失败属正常
	return [GLOBAL_BROADCAST, LOOPBACK]


static func directed_broadcasts(ip: String) -> Array:
	# 对每个可能的前缀把主机位全置 1:真实子网的广播地址必在其中,
	# 其余要么不在本子网(网关会丢弃),要么恰是某台主机(发现端口上的一条无害报文)
	var value := ipv4_to_int(ip)
	var out := []
	for prefix in _plausible_prefixes(ip):
		var target := int_to_ipv4(value | (~_prefix_mask(prefix) & IPV4_MAX))
		if not out.has(target):
			out.append(target)
	return out


static func _plausible_prefixes(ip: String) -> Array:
	var private_index := _first_block(ip, PRIVATE_BLOCKS)
	if private_index >= 0:
		return COMMON_PREFIXES + [PRIVATE_BLOCKS[private_index][1]]
	if in_block(ip, BLOCK_LINK_LOCAL):
		return [BLOCK_LINK_LOCAL[1]]
	return []  # 公网/回环/非法地址不发定向广播


# —— 房主地址(给其他玩家 IP 直连)——

static func local_private_ipv4s() -> Array:
	# 本机可供直连的地址,最可能连上的排最前(等待厅显示、复制第一个)
	return rank_lan_addresses(IP.get_local_interfaces())


static func rank_lan_addresses(interfaces: Array) -> Array:
	# interfaces 与 IP.get_local_interfaces() 同构:[{"name", "friendly", "addresses"}]。
	# 实体网卡排在虚拟网卡前,同类里按网段优先级;实体网卡有私网地址时不列退路地址;永不含回环
	var candidates := _address_candidates(interfaces)
	var has_physical_private := candidates.any(func(c): return not c["virtual"] and c["private"])
	var kept := candidates.filter(func(c): return c["private"] or not has_physical_private)
	kept.sort_custom(_better_candidate)
	var out := []
	for candidate in kept:
		if not out.has(candidate["ip"]):
			out.append(candidate["ip"])
	return out


static func looks_virtual(iface: Dictionary) -> bool:
	var label := ("%s %s" % [iface.get("name", ""), iface.get("friendly", "")]).to_lower()
	for hint in VIRTUAL_HINTS:
		if label.contains(hint):
			return true
	return false


static func _address_candidates(interfaces: Array) -> Array:
	var out := []
	for iface in interfaces:
		var is_virtual := looks_virtual(iface)
		for ip in iface.get("addresses", []):
			var rank := _address_rank(ip)
			if rank >= 0:
				out.append({"ip": ip, "virtual": is_virtual, "rank": rank,
					"private": rank < PRIVATE_BLOCKS.size(), "order": out.size()})
	return out


static func _address_rank(ip: String) -> int:
	# 数值越小越可能是局域网地址;-1 = 不可用(非 IPv4、回环、组播等)
	if ipv4_to_int(ip) < 0 or _first_block(ip, UNUSABLE_BLOCKS) >= 0:
		return -1
	var private_index := _first_block(ip, PRIVATE_BLOCKS)
	if private_index >= 0:
		return private_index
	var fallback_index := _first_block(ip, FALLBACK_BLOCKS)
	if fallback_index >= 0:
		return PRIVATE_BLOCKS.size() + fallback_index
	return PRIVATE_BLOCKS.size() + FALLBACK_BLOCKS.size()


static func _better_candidate(a: Dictionary, b: Dictionary) -> bool:
	if a["virtual"] != b["virtual"]:
		return not a["virtual"]
	if a["rank"] != b["rank"]:
		return a["rank"] < b["rank"]
	return a["order"] < b["order"]
