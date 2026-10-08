// 酒客共享材质:颜色、粗糙度、金属度来自 MeshForge 顶点数据(COLOR = sRGB albedo + AO,UV2 = 粗糙度/金属度),
// CUSTOM0 = (材质类, 尾巴摆动权重, 部件种子, 薄片透光)。所有酒客共用一份;出局褪色、尾巴摆动都是实例参数。
// 材质类:0 毛 1 布 2 皮革 3 金属 4 鳞 5 甲 6 格纹 7 草编 8 针织 9 光滑皮毛(脖子:拉长也不出条纹)
// 动森式软胶玩具质感(2026-10-08):共享的柔和卡通光照(toon_light.gdshaderinc),哑光;材质类的花纹幅度很小、尺度放大,
// 远看是干净的色块,近看有一点点手绘感(没有细毛丝、细织纹)。格纹、条纹按大印花画。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/vertex_pbr.gdshaderinc"
#include "res://src/world/shaders/noise.gdshaderinc"
// 角色:过渡带更宽、暗面更亮(像打了柔光的软胶玩具),边光淡淡一圈
#define TOON_WRAP 0.5
#define TOON_SHADOW 0.32
#define TOON_RIM 0.22
#define TOON_SHADOW_TINT vec3(0.9, 0.86, 1.0)   // 暗面一点暖紫,和场景(prop / wood)一致
#include "res://src/world/shaders/toon_light.gdshaderinc"

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
	if (kind == 0) {
		// 毛:几块很淡的大色斑(±3%),不画毛丝
		float n = value_noise(vec2(p.x * 7.0 + p.z * 5.0, p.y * 6.0) + part_seed * 13.0);
		c *= 0.97 + n * 0.06;
	} else if (kind == 1) {
		// 布:几乎纯色,只有极淡的大块明暗(±2%)
		float n = value_noise(vec2(p.x * 5.0 + p.z * 4.0, p.y * 5.0) + part_seed * 7.0);
		c *= 0.98 + n * 0.04;
	} else if (kind == 2) {
		// 皮革:大块斑驳(±5%),粗糙度低一点(缎面)
		float n = fbm(p.xy * 6.0 + p.z * 3.0 + part_seed);
		c *= 0.95 + n * 0.1;
		rough = max(rough - 0.08, 0.45);
	} else if (kind == 4 || kind == 5) {
		// 鳞 / 甲:放大的格子,缝只压暗一点点、边缘柔和
		vec2 cell = vec2(p.x * 13.0 + p.y * 3.0, p.z * 13.0 + p.y * 10.0);
		vec2 g = abs(fract(cell) - 0.5);
		float edge = smoothstep(0.3, 0.5, max(g.x, g.y));
		c *= 1.0 - edge * (kind == 4 ? 0.12 : 0.08);
	} else if (kind == 6) {
		// 格纹:大格子印花(一格约 7 cm),横竖两组宽条叠暗
		float a = stripes(p.x * 7.0 + p.z * 7.0, 0.55);
		float b = stripes(p.y * 7.0, 0.55);
		c *= 0.74 + 0.26 * max(a, b) * (0.75 + 0.25 * min(a, b));
	} else if (kind == 7) {
		// 草编:放大的斜向交织,幅度小
		c *= 0.9 + 0.1 * stripes(p.x * 30.0 + p.y * 30.0, 0.4) * stripes(p.x * 30.0 - p.y * 30.0 + p.z * 20.0, 0.4);
	} else if (kind == 8) {
		// 针织:粗的竖直罗纹
		c *= 0.93 + 0.07 * stripes(p.x * 40.0 + p.z * 40.0, 0.5);
	}
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));             // = Color.get_luminance()
	c = mix(c, GREY * lum * 1.6, 0.85 * fade * step(metal, 0.5)); // 金属件(铜扣)不褪色,与旧版一致
	ALBEDO = vp_srgb_to_linear(c);
	AO = COLOR.a;
	AO_LIGHT_AFFECT = 0.3;
	// 软胶玩具:整体哑光(粗糙度不低于 0.55);金属件也是缎面,只按顶点数据略亮一点
	ROUGHNESS = max(rough, mix(0.55, 0.4, metal));
	METALLIC = metal * 0.7;
	BACKLIGHT = ALBEDO * 0.3 * thin;   // 薄片(耳廓)被壁炉逆光照透
}
