class_name Lan
# 本机局域网地址工具:私网 IPv4 过滤、广播目标推导(网卡掩码不可得,按常见的 /24 推导)。


const GLOBAL_BROADCAST := "255.255.255.255"
const LOOPBACK := "127.0.0.1"


static func is_private_ipv4(ip: String) -> bool:
	var octets := ip.split(".")
	if octets.size() != 4:
		return false
	for octet in octets:
		if not octet.is_valid_int():
			return false
	var a := octets[0].to_int()
	var b := octets[1].to_int()
	return a == 10 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168)


static func private_ipv4s(addresses: Array) -> Array:
	var seen := {}
	for ip in addresses:
		if is_private_ipv4(ip):
			seen[ip] = true
	var out := seen.keys()
	out.sort()
	return out


static func broadcast_targets(addresses: Array) -> Array:
	# 全局广播只走默认网卡;再补各私网网卡的定向广播;回环保证同机实例必达
	var targets := [GLOBAL_BROADCAST]
	for ip in private_ipv4s(addresses):
		var octets: PackedStringArray = ip.split(".")
		var directed := "%s.%s.%s.255" % [octets[0], octets[1], octets[2]]
		if not targets.has(directed):
			targets.append(directed)
	targets.append(LOOPBACK)
	return targets


static func local_private_ipv4s() -> Array:
	return private_ipv4s(Array(IP.get_local_addresses()))
