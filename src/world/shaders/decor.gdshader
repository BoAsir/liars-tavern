// 墙饰共享材质(DecorAtlas 图集 + SurfaceNoise):模式写在顶点 UV2.x 上,参数在 UV2.y,所以纸面、外景、烟熏镜、
// 地毯、布料、余烬可以合进同一个 surface。COLOR.rgb = sRGB 色调,COLOR.a = 烘焙 AO。
// 0 纸 / 画布:ALBEDO = 图集 × 色调 × AO(夹到 ≤ 0.8),纸纤维 ±4%
// 1 外景:不受光,EMISSION = 图集 × 参数(最亮处——月亮、灯笼——再加一点,够得着辉光)
// 2 烟熏镜:近黑的金属面,烟熏斑驳的粗糙度、四周暗角、离边 4 cm 的金线、自下而上的暖色微光
// 3 纳瓦霍地毯:UV 是地毯局部米制坐标,参数是地毯编号;锯齿外框、沿长轴三个阶梯菱形、两端流苏
// 4 布料:色调 × 织纹,边缘一点绒光
// 5 余烬:炭黑底,细胞边线上滚动的橙红辉光
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

#include "res://src/world/shaders/vertex_pbr.gdshaderinc"
#include "res://src/world/shaders/surface.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 rug_sizes[2];
uniform vec2 mirror_size = vec2(3.08, 1.67);

varying flat int mode;
varying flat float param;
varying vec3 world_pos;

void vertex() {
	mode = int(UV2.x + 0.5);
	param = UV2.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// —— 纳瓦霍地毯 ——
// 甘纳多配色(sRGB,用前转线性)
const vec3 RUG_RED = vec3(0.29, 0.08, 0.055);
const vec3 RUG_CHAR = vec3(0.07, 0.06, 0.055);
const vec3 RUG_CREAM = vec3(0.56, 0.49, 0.37);
const vec3 RUG_TAUPE = vec3(0.30, 0.25, 0.20);

vec3 rug_color(vec2 uv, vec2 size, float fringe) {
	// uv:地毯局部米制坐标,原点在左下角(x 宽,y 长,不含流苏)
	float weave = 0.02;
	vec2 cell = floor(uv / weave) * weave + weave * 0.5;
	// 织格小于 2 像素时用原坐标(平滑边),否则量化成织格
	float px = max(fwidth(uv.x), fwidth(uv.y));
	vec2 q = mix(cell, uv, smoothstep(weave * 0.35, weave * 0.6, px));
	vec2 d_edge = min(q, size - q);
	float edge = min(d_edge.x, d_edge.y);
	vec3 col = RUG_RED;
	// 外框:炭黑细边 + 奶油锯齿带
	if (edge < 0.04) {
		col = RUG_CHAR;
	} else if (edge < 0.18) {
		float along = d_edge.x < d_edge.y ? q.y : q.x;
		float zig = abs(fract(along / 0.12) - 0.5) * 0.12;   // 锯齿
		float band = edge - 0.04;
		col = band < 0.03 + zig ? RUG_CREAM : (band < 0.11 ? RUG_TAUPE : RUG_CHAR);
		if (band > 0.125) {
			col = RUG_CREAM;
		}
	} else {
		// 红底上隔 0.36 m 一道暗色细纹,打散大块平涂
		float band = abs(fract((q.y - 0.18) / 0.36) - 0.5) * 0.36;
		col = band < 0.012 ? RUG_RED * 0.62 : RUG_RED;
		// 中间沿长轴排 3 个阶梯菱形
		vec2 c = size * 0.5;
		float span = (size.y - 0.36) / 3.0;
		float k = clamp(floor((q.y - 0.18) / span), 0.0, 2.0);
		vec2 center = vec2(c.x, 0.18 + span * (k + 0.5));
		vec2 r = abs(q - center);
		float step_r = floor((r.x / max(size.x * 0.5 - 0.25, 0.1) + r.y / (span * 0.48)) * 5.0) / 5.0;
		if (step_r < 0.2) {
			col = RUG_CHAR;
		} else if (step_r < 0.4) {
			col = RUG_CREAM;
		} else if (step_r < 0.6) {
			col = RUG_TAUPE;
		} else if (step_r < 0.8) {
			col = RUG_CREAM;
		} else if (step_r < 1.0) {
			col = RUG_CHAR;
		}
		// 菱形之间的小十字
		vec2 rr = abs(q - vec2(c.x, 0.18 + span * (k + (q.y - 0.18 - span * k > span * 0.5 ? 1.0 : 0.0))));
		if (k < 2.5 && min(rr.x, rr.y) < 0.025 && max(rr.x, rr.y) < 0.09 && step_r >= 1.0) {
			col = RUG_CREAM;
		}
	}
	return col;
}

void fragment() {
	vec3 tint = vp_srgb_to_linear(COLOR.rgb);
	float ao = COLOR.a;
	vec3 albedo = vec3(0.5);
	float rough = 0.88;
	float metal = 0.0;
	float spec = 0.5;
	vec3 emission = vec3(0.0);
	if (mode == 0) {
		vec3 tex = texture(atlas, UV).rgb;
		float fibre = n_hi(world_pos.xy * 160.0 + world_pos.zz * 160.0) - 0.5;
		albedo = min(tex * tint * ao * (1.0 + fibre * 0.08), vec3(0.8));
	} else if (mode == 1) {
		vec3 tex = texture(atlas, UV).rgb;
		albedo = vec3(0.0);
		spec = 0.0;
		rough = 1.0;
		float boost = 1.0 + 5.0 * smoothstep(0.55, 0.9, luma(tex));
		emission = tex * tint * param * boost;
	} else if (mode == 2) {
		// UV:镜面局部米制坐标(原点在一角)
		vec2 d = min(UV, mirror_size - UV);
		float edge = min(d.x, d.y);
		float smoke = n_lo(UV * 3.0 + 11.0) * 0.7 + n_lo(UV * 9.0) * 0.3;
		float vignette = smoothstep(0.0, 0.45, edge);
		albedo = vec3(0.02, 0.022, 0.025);
		metal = 0.85;
		rough = 0.12 + 0.25 * smoke + (1.0 - vignette) * 0.2;
		float gold = 1.0 - smoothstep(0.0075, 0.0075 + max(max(fwidth(UV.x), fwidth(UV.y)), 0.001), abs(edge - 0.04 - 0.0075));
		albedo = mix(albedo * (0.6 + 0.4 * vignette), vec3(0.62, 0.45, 0.2), gold);
		rough = mix(rough, 0.3, gold);
		metal = mix(metal, 1.0, gold);
		float warm = (1.0 - smoothstep(0.0, mirror_size.y, UV.y)) * vignette * (0.6 + 0.4 * smoke);
		// 假反光:几道斜向的柔和亮带,读得出是镜面
		float streak = smoothstep(0.35, 0.0, abs(fract((UV.x + UV.y * 0.7) / 1.3) - 0.5)) * 0.5 + 0.5;
		emission = vec3(0.10, 0.055, 0.025) * warm * 0.55 * streak * (1.0 - gold);
	} else if (mode == 3) {
		int id = int(param + 0.5);
		vec4 rs = rug_sizes[id];
		vec2 size = rs.xy;
		float fringe = rs.z;
		vec2 uv = UV;
		float weave = n_hi(world_pos.xz * 60.0);
		if (uv.y < 0.0 || uv.y > size.y) {
			// 流苏:奶油色细绳,绳间暗缝
			float strand = abs(fract(uv.x / 0.018) - 0.5);
			float tail = uv.y < 0.0 ? -uv.y : uv.y - size.y;
			albedo = RUG_CREAM * (1.0 - 0.55 * smoothstep(0.3, 0.48, strand));
			albedo *= 1.0 - smoothstep(fringe * 0.7, fringe, tail) * 0.4;
		} else {
			albedo = rug_color(uv, size, fringe);
		}
		albedo *= 0.88 + 0.24 * weave;
		albedo = vp_srgb_to_linear(clamp(albedo, vec3(0.06), vec3(0.62)));
		rough = 0.95;
		spec = 0.3;
	} else if (mode == 4) {
		float weave = n_hi(vec2(world_pos.x + world_pos.z, world_pos.y) * 60.0);
		albedo = tint * ao * (0.85 + 0.3 * weave);
		rough = 0.9;
		float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0) * 0.35;
		albedo += tint * sheen;
	} else if (mode == 5) {
		vec2 p = world_pos.xz * 9.0 + vec2(TIME * 0.05, -TIME * 0.03);
		float cell = n_cell(p);
		float pulse = 0.7 + 0.3 * n_lo(world_pos.xz * 4.0 + vec2(TIME * 0.35, TIME * 0.2));
		float glow = pow(1.0 - cell, 6.0) * pulse;
		albedo = vec3(0.03, 0.025, 0.02) * ao;
		rough = 0.95;
		emission = vec3(1.0, 0.32, 0.06) * glow * 3.0 * param;
	}
	ALBEDO = albedo;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = spec;
	EMISSION = emission;
}
