// 酒客共享材质:颜色、粗糙度、金属度来自 MeshForge 顶点数据(COLOR = sRGB albedo + AO,UV2 = 粗糙度/金属度),
// CUSTOM0 = (材质类, 尾巴摆动权重, 部件种子, 薄片透光)。所有酒客共用一份;出局褪色、尾巴摆动都是实例参数。
// 材质类:0 毛 1 布 2 皮革 3 金属 4 鳞 5 甲 6 格纹 7 草编 8 针织 9 光滑皮毛(脖子:拉长也不出条纹)
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/vertex_pbr.gdshaderinc"
#include "res://src/world/shaders/noise.gdshaderinc"

instance uniform float fade = 0.0;          // 0 正常 → 1 褪成灰
instance uniform vec4 tail = vec4(0.0);     // x 相位、y 摆幅(弧度)、z 下垂(0..1,出局)
instance uniform vec3 tail_root = vec3(0.0);
const vec3 GREY = vec3(0.42);               // = Patron.GREY(sRGB)

varying vec3 local_pos;
varying float mat_class;
varying float part_seed;
varying float thin;

void vertex() {
	mat_class = CUSTOM0.x;
	part_seed = CUSTOM0.z;
	thin = CUSTOM0.w;
	float w = CUSTOM0.y;
	if (w > 0.0) {
		// 尾巴:绕尾根的竖轴来回摆;出局时摆幅收掉、整条往下垂,但不压到地面以下(Legs 原点在地面)
		float ang = sin(TIME * 1.3 + tail.x) * tail.y * w * w * (1.0 - tail.z);
		float c = cos(ang);
		float s = sin(ang);
		vec3 p = VERTEX - tail_root;
		VERTEX = vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z) + tail_root;
		NORMAL = vec3(c * NORMAL.x + s * NORMAL.z, NORMAL.y, -s * NORMAL.x + c * NORMAL.z);
		float droop = tail.z * w * w * 0.08;
		VERTEX.y = max(VERTEX.y - droop, min(VERTEX.y, 0.01));
	}
	local_pos = VERTEX;
}

float stripes(float x, float width) {
	// 抗锯齿的方波条纹:返回 0..1
	float f = abs(fract(x) - 0.5) * 2.0;
	float aa = max(fwidth(x) * 2.0, 1e-4);
	return smoothstep(width - aa, width + aa, f);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float rough = UV2.x;
	float metal = UV2.y;
	int kind = int(round(mat_class));
	vec3 p = local_pos;
	float rim = 0.3;
	if (kind == 0) {
		// 毛:顺着竖直方向的细纹,亮度 ±6%
		float n = value_noise(vec2(p.x * 160.0 + p.z * 130.0, p.y * 28.0) + part_seed * 13.0);
		c *= 0.94 + n * 0.12;
	} else if (kind == 1) {
		// 布:细织纹 + 更宽的边光近似绒面光泽
		float weave = stripes(p.x * 420.0 + p.z * 420.0, 0.5) * stripes(p.y * 420.0, 0.5);
		c *= 0.95 + weave * 0.06;
		rim = 0.45;
	} else if (kind == 2) {
		// 皮革:大块斑驳,粗糙度低一点
		float n = fbm(p.xy * 18.0 + p.z * 7.0 + part_seed);
		c *= 0.86 + n * 0.24;
		rough = max(rough - 0.12, 0.2);
	} else if (kind == 4 || kind == 5) {
		// 鳞 / 甲:格子缝压暗
		vec2 cell = vec2(p.x * 38.0 + p.y * 9.0, p.z * 38.0 + p.y * 30.0);
		vec2 g = abs(fract(cell) - 0.5);
		float edge = smoothstep(0.38, 0.5, max(g.x, g.y));
		c *= 1.0 - edge * (kind == 4 ? 0.25 : 0.18);
	} else if (kind == 6) {
		// 格纹衬衫:横竖两组条纹叠暗
		float a = stripes(p.x * 18.0 + p.z * 18.0, 0.55);
		float b = stripes(p.y * 18.0, 0.55);
		c *= 0.62 + 0.38 * max(a, b) * (0.7 + 0.3 * min(a, b));
	} else if (kind == 7) {
		// 草编:斜向交织
		c *= 0.82 + 0.18 * stripes(p.x * 90.0 + p.y * 90.0, 0.4) * stripes(p.x * 90.0 - p.y * 90.0 + p.z * 60.0, 0.4);
	} else if (kind == 8) {
		// 针织:竖直罗纹
		c *= 0.88 + 0.12 * stripes(p.x * 120.0 + p.z * 120.0, 0.5);
	}
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));             // = Color.get_luminance()
	c = mix(c, GREY * lum * 1.6, 0.85 * fade * step(metal, 0.5)); // 金属件(铜扣)不褪色,与旧版一致
	ALBEDO = vp_srgb_to_linear(c);
	AO = COLOR.a;
	AO_LIGHT_AFFECT = 0.3;
	ROUGHNESS = rough;
	METALLIC = metal;
	RIM = rim * (1.0 - metal);   // 布料与皮毛有卡通边光,金属件没有
	RIM_TINT = 0.5;
	BACKLIGHT = ALBEDO * 0.3 * thin;   // 薄片(耳廓)被壁炉逆光照透
}
