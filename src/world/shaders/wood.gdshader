// 程序化木纹 v2:年轮 + 纤维纹理,可选木板拼接(地板/天花板)或框芯护墙板。纹理在物体空间计算,无需 UV。
// 噪声取自 SurfaceNoise 烘焙的可平铺贴图(surface.gdshaderinc),不再逐像素算 fbm;
// 新增参数的默认值保持旧行为(椅子、牌桌、握把等不开这些开关)。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"
#include "res://src/world/shaders/surface.gdshaderinc"

uniform vec3 color_dark : source_color = vec3(0.16, 0.08, 0.04);
uniform vec3 color_light : source_color = vec3(0.42, 0.24, 0.12);
uniform float scale = 1.0;
uniform float ring_frequency = 9.0;
uniform float grain_strength = 0.35;
uniform int grain_axis = 0;      // 纤维方向:0=X 1=Y 2=Z
uniform int across_axis = 2;     // 木板排列方向
uniform float plank_width = 0.0; // >0 启用木板拼接
uniform float plank_length = 1.6;
uniform float roughness_base = 0.62;
uniform float varnish = 0.0;
uniform float wear = 0.0;
// 合并网格(MeshForge)里木纹按部件自己的局部坐标算:CUSTOM0.xyz = 部件原始顶点,w = 部件种子;
// 不合并的网格不开,和原来完全一样
uniform bool use_part_space = false;
// —— v2 ——
uniform float stagger = 1.0;          // 板端错缝(0 = 每行板端对齐,天花板的板端藏在梁下)
uniform float plank_tint = 0.0;       // 逐板明度 / 色相差
uniform float bevel = 0.0;            // 板缝倒角凹凸
uniform float nails = 0.0;            // 钉头(每根龙骨每板 2 颗,板端 2 颗)
uniform float joist_spacing = 0.6;
uniform vec4 wear_ring = vec4(0.0);   // 踩出来的磨损环 (x, z, 半径, 宽度);半径 0 = 不用
uniform vec4 wear_seg_a = vec4(0.0);  // 磨损走道 (x0, z0, x1, z1)
uniform vec4 wear_seg_b = vec4(0.0);
uniform float wear_seg_width = 0.5;
uniform float stains = 0.0;           // 酒渍
uniform vec3 stain_focus_a = vec3(0.0, 0.0, 0.001);   // (x, z, 半径):酒渍集中的地方
uniform vec3 stain_focus_b = vec3(0.0, 0.0, 0.001);
uniform int pattern = 0;              // 1 = 框芯护墙板
uniform vec3 panel = vec3(0.08, 0.10, 0.045);   // 竖梃宽、横档宽、芯板斜面宽
uniform float panel_pitch = 0.62;
uniform float panel_height = 1.1;

varying vec3 obj_pos;
varying float part_seed;

void vertex() {
	obj_pos = (use_part_space ? CUSTOM0.xyz : VERTEX) * scale;
	part_seed = use_part_space ? CUSTOM0.w : 0.0;
}

float axis_component(vec3 v, int axis) {
	return axis == 0 ? v.x : (axis == 1 ? v.y : v.z);
}

float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	float along = axis_component(obj_pos, grain_axis);
	float across = axis_component(obj_pos, across_axis);
	float depth = axis_component(obj_pos, 3 - grain_axis - across_axis);
	float plank_id = 0.0;
	float seam = 0.0;
	float height = 1.0;        // 解析凹凸的高度(米,相对)
	float junction = 0.0;      // 框芯交界的压暗
	float nail = 0.0;
	if (pattern == 1) {
		// 框芯护墙板:u = across(沿墙),v = along(离地);竖梃与芯板竖纹,横档横纹
		float u = across;
		float v = along;
		float cell = floor(u / panel_pitch);
		float lu = u - cell * panel_pitch;
		float half_stile = panel.x * 0.5;
		float bottom = 0.14 + panel.y;        // 踢脚线盖住 0..0.14
		float top = panel_height - panel.y * 1.2;
		float dpx = min(lu - half_stile, panel_pitch - half_stile - lu);
		float dpy = min(v - bottom, top - v);
		float dp = min(dpx, dpy);
		bool in_rail = dpy < 0.0 && dpx > -half_stile * 0.5 && (v < bottom || v > top);
		if (dp < 0.0) {
			height = 1.0;
			plank_id = in_rail ? (v < bottom ? 401.0 : 409.0) + cell * 3.0 : cell * 7.0 + 211.0;
			if (in_rail) {
				// 横档横纹:交换纹理轴
				float t = along;
				along = across;
				across = t;
			}
		} else {
			height = mix(0.3, 0.8, smoothstep(0.0, panel.z, dp));
			plank_id = cell * 13.0 + 5.0;
			junction = 1.0 - smoothstep(0.0, 0.008, dp);
		}
		// 像素宽度取连续坐标的导数(dp 在线上有折角,直接求导会在 2×2 像素块之间跳变,出虚线)
		float fw = max(max(fwidth(u), fwidth(v)), 1e-5);
		seam = (1.0 - smoothstep(0.0, max(0.0015, fw * 1.2), abs(dp))) * (1.0 - smoothstep(0.004, 0.02, fw));
		height = mix(0.8, height, 1.0 - smoothstep(0.003, 0.008, fw));
	} else if (plank_width > 0.0) {
		float row = floor(across / plank_width);
		float offset = stagger * hash12(vec2(row, 3.7)) * plank_length;
		float segment = floor((along + offset) / plank_length);
		plank_id = row + segment * 57.0;
		float fa = fract(across / plank_width);
		float fl = fract((along + offset) / plank_length);
		float e_across = min(fa, 1.0 - fa) * plank_width;
		float e_along = min(fl, 1.0 - fl) * plank_length;
		float edge = min(e_across, e_along);
		float fw = max(max(fwidth(across), fwidth(along)), 1e-5);
		seam = 1.0 - smoothstep(0.0, max(0.0025, 1.2 * fw), edge);
		seam *= 1.0 - 0.7 * smoothstep(0.004, 0.03, fw);    // 远处板缝淡出,不出摩尔纹
		// 倒角凹凸:窄到一两个像素时淡出(否则导数凹凸在板缝上出虚线)
		height = mix(1.0, smoothstep(0.0, 0.007, edge), 1.0 - smoothstep(0.0015, 0.004, fw));
		if (nails > 0.0) {
			float da = min(abs(fa - 0.25), abs(fa - 0.75)) * plank_width;
			float j = floor(along / joist_spacing + 0.5);
			float d1 = length(vec2(along - j * joist_spacing, da));
			float d2 = length(vec2(e_along - 0.035, da));
			float d = min(d1, d2);
			float fd = fw;
			nail = (1.0 - smoothstep(0.0035, 0.0045, d)) * (1.0 - smoothstep(0.5, 1.0, fd / 0.0045)) * nails;
		}
	}
	float rnd = hash12(vec2(plank_id, 1.3) + part_seed * 31.7);
	float warp = n_lo(vec2(along * 0.45, across * 1.6) + rnd * 10.0);
	vec2 ring_p = vec2(across + rnd * 13.0, depth * 0.6 + rnd * 7.0);
	float rings = fract(length(ring_p) * ring_frequency + warp * 1.1);
	rings = smoothstep(0.0, 0.75, rings) * (1.0 - smoothstep(0.75, 1.0, rings));
	float grain = n_hi(vec2(along * 1.8, across * 80.0 + rnd * 20.0));
	float fibre = n_hi(vec2(along * 6.0 + 31.0, across * 400.0));
	// 磨损:环形与走道;斑驳一层,磨过的地方木纹淡、颜色亮、更粗糙
	float worn = 0.0;
	vec2 xz = obj_pos.xz;
	if (wear_ring.z > 0.0) {
		worn = max(worn, 1.0 - smoothstep(0.0, wear_ring.w, abs(length(xz - wear_ring.xy) - wear_ring.z)));
	}
	if (dot(wear_seg_a, wear_seg_a) > 0.0) {
		worn = max(worn, 1.0 - smoothstep(0.0, wear_seg_width, seg_dist(xz, wear_seg_a.xy, wear_seg_a.zw)));
	}
	if (dot(wear_seg_b, wear_seg_b) > 0.0) {
		worn = max(worn, 1.0 - smoothstep(0.0, wear_seg_width, seg_dist(xz, wear_seg_b.xy, wear_seg_b.zw)));
	}
	worn *= smoothstep(0.35, 0.65, n_lo(xz * 2.3 + 7.0));
	float grain_mix = grain_strength * (1.0 - worn * 0.6);
	float t = clamp(rings * 0.32 + grain * grain_mix + fibre * 0.15 + (rnd - 0.5) * 0.3, 0.0, 1.0);
	vec3 col = mix(color_dark, color_light, t);
	float blotch = n_lo(vec2(along, across) * 1.7 + 4.0);
	col *= mix(1.0, 0.7 + 0.6 * blotch, wear);
	// 逐板色差(明度 ± plank_tint,色相略偏红或偏黄)
	float tint_r = hash12(vec2(plank_id, 8.1) + part_seed);
	col *= 1.0 + (tint_r - 0.5) * 2.0 * plank_tint;
	col.r *= 1.0 + (hash12(vec2(plank_id, 2.9)) - 0.5) * plank_tint * 0.5;
	col *= 1.0 + worn * 0.3;
	// 酒渍:阈值斑块,内部暗、边缘一圈更暗,釉面更亮
	float stain = 0.0;
	if (stains > 0.0) {
		float focus = max(1.0 - smoothstep(0.0, stain_focus_a.z, length(xz - stain_focus_a.xy)),
			1.0 - smoothstep(0.0, stain_focus_b.z, length(xz - stain_focus_b.xy)));
		float sn = n_lo(xz * 0.9 + 13.0);
		float th = 0.62 - focus * 0.1;
		float inside = smoothstep(th, th + 0.02, sn);
		float rim = inside * (1.0 - smoothstep(th + 0.02, th + 0.05, sn));
		stain = inside * focus * stains;
		col *= 1.0 - stain * 0.35 - rim * focus * stains * 0.3;
	}
	col *= mix(1.0, 0.2, seam);
	col *= 1.0 - junction * 0.4;
	col = mix(col, vec3(0.045, 0.043, 0.042), nail);
	ALBEDO = col;
	float rough = roughness_base - varnish * 0.45 + grain * 0.18 + seam * 0.3;
	rough += (tint_r - 0.5) * 0.08 * step(0.001, plank_tint) + worn * 0.12 - stain * 0.3;
	ROUGHNESS = clamp(mix(rough, 0.35, nail), 0.06, 1.0);
	METALLIC = nail * 0.6;
	SPECULAR = 0.45;
	if (bevel > 0.0 && (plank_width > 0.0 || pattern == 1)) {
		float relief = pattern == 1 ? 0.012 : 0.0018;
		NORMAL = bump_normal(NORMAL, VERTEX, height * relief * bevel, 1.0);
	}
}
