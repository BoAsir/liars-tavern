// 石砌/灰泥墙面 v2:block_size > 0 时为错缝石块 + 灰缝(网格原点对齐壁炉,奇数行错半块),否则为灰泥:
// 双尺度污渍、颗粒、压条上方的手印带、顶部烟熏、壁灯上方的熏痕、露砖斑块与细裂缝。
// 噪声取自 SurfaceNoise 烘焙的可平铺贴图;凹凸只取解析形状。COLOR.rgb(sRGB)乘到底色上(MeshForge 网格的炉膛熏黑)。
shader_type spatial;
render_mode diffuse_burley;

#include "res://src/world/shaders/noise.gdshaderinc"
#include "res://src/world/shaders/surface.gdshaderinc"
#include "res://src/world/shaders/vertex_pbr.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.32, 0.28, 0.24);
uniform vec3 color_b : source_color = vec3(0.20, 0.17, 0.15);
uniform vec3 mortar_color : source_color = vec3(0.12, 0.10, 0.09);
uniform float block_size = 0.0;      // 行高(米);块宽 = 1.6 × 行高
uniform float soot = 0.0;            // 自下而上的烟熏(壁炉口)
uniform float soot_height = 1.0;
// —— v2 ——
uniform vec3 grid_origin = vec3(0.0);   // 石砌网格原点:正面 u = x − x0,侧面 u = z − z0
uniform float brick_amount = 0.0;    // 灰泥:露砖斑块的多少
uniform float crack_amount = 0.0;    // 灰泥:细裂缝
uniform float rail_y = 1.13;         // 墙裙压条顶
uniform float ceiling_y = 3.4;
uniform float top_soot = 0.0;        // 天花板下的烟熏
uniform vec4 halos[8];               // 壁灯熏痕中心 (x, y, z, 未用)
uniform int halo_count = 0;
uniform vec3 brick_color : source_color = vec3(0.34, 0.20, 0.14);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 墙面坐标:取世界坐标中变化最大的两轴
	vec3 n = abs(world_normal);
	vec3 rel = world_pos - grid_origin;
	vec2 p = n.x > 0.5 ? rel.zy : (n.z > 0.5 ? rel.xy : rel.xz);
	// 每面墙按法线方向取不同种子
	vec2 wall_seed = world_normal.xz * 37.0 + world_normal.y * 11.0;
	float stain = n_lo(p * 1.3 + wall_seed);
	float stain2 = n_lo(p * 0.35 + wall_seed * 0.3 + 5.0);
	float speck = n_hi(p * 90.0 + wall_seed);
	vec3 col = mix(color_b, color_a, smoothstep(0.25, 0.75, stain * 0.65 + stain2 * 0.35));
	float height = 0.0;       // 解析凹凸(米)
	float mortar = 0.0;
	if (block_size > 0.0) {
		vec2 cell = vec2(block_size * 1.6, block_size);
		float row = floor(p.y / cell.y);
		vec2 q = vec2(p.x / cell.x + mod(row, 2.0) * 0.5, p.y / cell.y);
		vec2 id = floor(q);
		vec2 f = fract(q);
		vec2 jitter = (vec2(n_hi(p * 7.0), n_hi(p * 7.0 + 3.0)) - 0.5) * 0.06;
		vec2 e = min(f + jitter, 1.0 - f - jitter);
		float edge = min(e.x * cell.x, e.y * cell.y);
		mortar = 1.0 - smoothstep(0.004, 0.012, edge);
		col *= 0.75 + 0.5 * hash12(id + 5.0 + row * 0.37);
		col *= 0.9 + 0.2 * n_lo(p * 6.0 + id);
		// 灰缝凹 6 mm;灰缝窄到一两个像素时凹凸淡出(导数凹凸在细线上会出虚线)
		float fwp = max(fwidth(p.x), fwidth(p.y));
		height = -0.006 * mortar * (1.0 - smoothstep(0.002, 0.006, fwp));
	} else {
		float y = world_pos.y;
		// 手印带:压条上方 0.35 m 暗一些
		float hands = (1.0 - smoothstep(0.0, 0.35, y - rail_y)) * step(rail_y, y);
		col *= 1.0 - 0.2 * hands * (0.5 + n_lo(p * 4.0 + 3.0));
		// 顶部烟熏:离天花板 1.3 m 内
		float topsoot = top_soot * smoothstep(ceiling_y - 1.3, ceiling_y, y) * (0.6 + 0.6 * stain2);
		col *= 1.0 - clamp(topsoot, 0.0, 0.85);
		// 壁灯上方的熏痕
		for (int i = 0; i < halo_count; i++) {
			vec3 d = world_pos - halos[i].xyz;
			float up = clamp(d.y / 0.75, 0.0, 1.0);
			float side = length(vec2(dot(d.xz, vec2(world_normal.z, -world_normal.x)), 0.0));
			float r = mix(0.10, 0.32, up);
			float h = (1.0 - smoothstep(r * 0.4, r, side)) * step(-0.05, d.y) * (1.0 - smoothstep(0.35, 0.8, d.y));
			col *= 1.0 - 0.45 * h * (0.7 + 0.3 * stain);
		}
		// 露砖:压条以上 0.35 m 到天花板以下 0.6 m 的带里,用减法收边(带外不出)
		if (brick_amount > 0.0) {
			float band = smoothstep(rail_y + 0.35, rail_y + 0.6, y) * (1.0 - smoothstep(ceiling_y - 0.9, ceiling_y - 0.6, y));
			// 破口按整块砖取样(边缘呈台阶状,读得出是砖);破口外一圈灰泥碎边提亮
			vec2 bq = vec2(p.x / 0.22 + mod(floor(p.y / 0.075), 2.0) * 0.5, p.y / 0.075);
			vec2 bid = floor(bq);
			vec2 bc = vec2((bid.x + 0.5 - mod(bid.y, 2.0) * 0.5) * 0.22, (bid.y + 0.5) * 0.075);
			float bband = smoothstep(rail_y + 0.35, rail_y + 0.6, bc.y) * (1.0 - smoothstep(ceiling_y - 0.9, ceiling_y - 0.6, bc.y));
			float pn_c = n_lo(bc * 0.9 + wall_seed + 21.0) * 0.75 + n_lo(bc * 3.1 + 2.0) * 0.25;
			float open = step(0.0, pn_c - (1.0 - brick_amount) - (1.0 - bband) * 0.5);
			float pn = n_lo(p * 0.9 + wall_seed + 21.0) * 0.75 + n_lo(p * 3.1 + 2.0) * 0.25;
			float pm = pn - (1.0 - brick_amount) - (1.0 - band) * 0.5;
			float lip = (1.0 - smoothstep(0.0, 0.05, abs(pm + 0.02))) * (1.0 - open);
			vec2 bf = fract(bq);
			vec2 be = min(bf, 1.0 - bf) * vec2(0.22, 0.075);
			float bmortar = 1.0 - smoothstep(0.003, 0.008, min(be.x, be.y));
			vec3 brick = brick_color * (0.7 + 0.45 * hash12(bid + 3.0)) * (0.85 + 0.3 * speck);
			brick = mix(brick, mortar_color * 1.4, bmortar);
			col = mix(col, brick, open);
			col *= 1.0 + lip * 0.12;
			height = mix(height, -0.0028 - 0.003 * bmortar * (1.0 - smoothstep(0.002, 0.006, max(fwidth(p.x), fwidth(p.y)))), open);
		}
		// 细裂缝:细胞边线,只在噪声选中的区域
		if (crack_amount > 0.0) {
			float cellv = n_cell(p * 1.6 + wall_seed);
			float w = max(fwidth(cellv), 0.004);
			float line = 1.0 - smoothstep(0.0, w * 1.5, cellv);
			float sel = smoothstep(0.55, 0.7, n_lo(p * 0.7 + 40.0)) * crack_amount;
			col *= 1.0 - 0.6 * line * sel;
			height -= 0.0012 * line * sel;
		}
	}
	col *= vp_srgb_to_linear(COLOR.rgb);
	col *= 0.85 + speck * 0.3;
	col = mix(col, mortar_color, mortar);
	float soot_mask = soot * (1.0 - smoothstep(0.0, soot_height, world_pos.y)) * (0.6 + 0.4 * stain);
	col = mix(col, vec3(0.02), clamp(soot_mask, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.9 - speck * 0.1;
	SPECULAR = 0.25;
	NORMAL = bump_normal(NORMAL, VERTEX, height, 1.0);   // 不放进分支:导数要在统一的控制流里算
}
