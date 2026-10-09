// 酒客材质:所有酒客共用这一个着色器,每名酒客一份材质实例(出局时单独褪色)。
// 一个合批表面里混着毛皮、布料、缎面、黄铜、眼睛等部件:顶点色 alpha 存槽位编号(PatronSkin 的槽位),
// 颜色取自本酒客的调色板,质感按槽位的类型选用——所以每个动画枢轴只需一次绘制调用,不必按材质拆表面。
// 顶点色 rgb:r = 烘焙的明暗(1 为不变),g = 往浅色(口鼻色)混合,b = 往深色混合,毛皮斑纹与渐变都烘在顶点里。
// CUSTOM0 = 部件自身坐标(MeshBatch 写入,眼珠、眼白按单位球建模,图案与网格大小无关);UV = 布料图案坐标(米)。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

const int SLOTS = 32;
// 质感类型(与 PatronSkin 的 KIND_* 一致)
const int K_FUR = 0;
const int K_SKIN = 1;
const int K_GLOSS = 2;
const int K_EYE = 3;
const int K_IRIS = 4;
const int K_CLOTH = 5;
const int K_SATIN = 6;
const int K_METAL = 7;
// 布料图案(look.z)
const int P_PINSTRIPE = 1;
const int P_CHECK = 2;
const int P_TWEED = 3;
const int P_STRIPES = 4;
const int P_VELVET = 5;
const int P_DOTS = 6;
const int P_STRAW = 7;
const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

uniform vec4 palette[SLOTS];       // 与 StandardMaterial3D 的 albedo_color 同样原样使用(实测本引擎下两者像素一致)
uniform vec4 look[SLOTS];          // x 粗糙度  y 绒面光泽(边缘光)  z 布料图案  w 图案密度(每米几条)
uniform int kinds[SLOTS];
uniform int light_slot = 1;        // 毛皮往浅色、深色混合时取的调色板槽位
uniform int dark_slot = 2;
uniform vec4 ink : source_color = vec4(0.1, 0.08, 0.06, 1.0);   // 格纹、条纹的线色
uniform int pupil_shape = 0;       // 0 圆瞳  1 竖缝(猫)  2 横条
uniform float pupil_size = 0.42;   // 瞳孔半径占虹膜半径的比例
uniform float death : hint_range(0.0, 1.0) = 0.0;   // 出局褪色:0 → 1 在 1.4 秒内补间

varying flat int v_slot;
varying flat int v_kind;
varying flat float v_seed;
varying vec3 v_tag;
varying vec3 v_local;
varying vec2 v_uv;

void vertex() {
	v_slot = clamp(int(COLOR.a * 255.0 + 0.5), 0, SLOTS - 1);
	v_kind = kinds[v_slot];
	v_tag = COLOR.rgb;
	bool batched = CUSTOM1.x >= 2.0;
	v_local = batched ? CUSTOM0.xyz : VERTEX;
	v_seed = batched ? fract(CUSTOM1.x) : 0.0;
	v_uv = UV;
}

// 抗锯齿的细线:coord 每过 1 一条线,宽 width(占周期比例);远处线条小于一个像素时淡成平均色
float lines(float coord, float width) {
	float d = abs(fract(coord) - 0.5);
	float w = max(fwidth(coord), 1e-4);
	float line = smoothstep(0.5 - width - w, 0.5 - width + w, d);
	return mix(line, width * 2.0, clamp(w * 2.0 - 0.6, 0.0, 1.0));
}

vec3 marked(vec3 base) {
	// 毛色斑纹:顶点色 g 往浅色(口鼻色)、b 往深色混合
	return mix(mix(base, palette[light_slot].rgb, v_tag.g), palette[dark_slot].rgb, v_tag.b);
}

vec3 fur(vec3 base) {
	// 毛皮:大团的柔和明暗 + 顺着部件纵向(Y)拉长的细毛丝;毛丝小于一个像素时按像素尺寸淡出,远处不闪烁
	float clump = value_noise3(v_local * 26.0 + v_seed * 17.0);
	vec3 strand_p = v_local * vec3(240.0, 60.0, 240.0) + v_seed * 31.0;
	float fade = clamp(1.5 - length(fwidth(strand_p)) * 0.5, 0.0, 1.0);
	float strand = (value_noise3(strand_p) - 0.5) * fade;
	return base * (0.92 + clump * 0.12 + strand * 0.18);
}

vec3 cloth(vec3 base, vec4 lk) {
	int pattern = int(lk.z + 0.5);
	vec2 p = v_uv * lk.w;
	float weave_fade = clamp(1.5 - length(fwidth(v_uv * 700.0)), 0.0, 1.0);
	float weave = sin(v_uv.x * 700.0) * sin(v_uv.y * 700.0) * 0.035 * weave_fade;
	base *= 1.0 + weave;
	if (pattern == P_PINSTRIPE) {
		base = mix(base, base * 1.9 + 0.02, (1.0 - lines(p.x, 0.47)) * 0.75);
	} else if (pattern == P_CHECK) {
		float l = max(1.0 - lines(p.x, 0.42), 1.0 - lines(p.y, 0.42));
		float fine = max(1.0 - lines(p.x * 2.0 + 0.5, 0.47), 1.0 - lines(p.y * 2.0 + 0.5, 0.47));
		base = mix(base, ink.rgb, l * 0.38 + fine * 0.12);
	} else if (pattern == P_TWEED) {
		float fleck = value_noise(v_uv * 900.0 + v_seed * 40.0);
		float herring = abs(fract(p.y + abs(fract(p.x) - 0.5)) - 0.5);
		base *= 0.85 + fleck * 0.3 + (herring - 0.25) * 0.25 * weave_fade;
	} else if (pattern == P_STRIPES) {
		base = mix(base, ink.rgb, (1.0 - lines(p.x, 0.36)) * 0.8);
	} else if (pattern == P_VELVET) {
		base *= 0.85 + value_noise(v_uv * 60.0) * 0.15;
	} else if (pattern == P_DOTS) {
		// 波点(领巾):错行排列的圆点,远处按像素尺寸淡成平均色
		vec2 cell = vec2(p.x + 0.5 * floor(p.y), p.y);
		float d = length(fract(cell) - 0.5);
		float w = max(fwidth(p.x), 1e-4);
		float dot_mask = mix(smoothstep(0.24 + w, 0.24 - w, d), 0.18, clamp(w * 2.0 - 0.6, 0.0, 1.0));
		base = mix(base, vec3(0.93, 0.9, 0.82), dot_mask);
	} else if (pattern == P_STRAW) {
		// 草编:一圈圈压扁的草辫(沿 V)+ 斜向编纹
		float braid = abs(fract(p.y) - 0.5) * 2.0;
		float twill = lines(p.x * 2.0 + p.y * 2.0, 0.4);
		base *= 0.78 + 0.22 * smoothstep(0.0, 0.6, braid) + (twill - 0.5) * 0.12 * weave_fade;
	}
	return base;
}

vec3 iris(vec3 base, out vec3 emit) {
	// 虹膜按单位圆建模:瞳孔 + 由上到下变亮的虹膜 + 放射纹 + 深色外圈 + 两点高光
	vec2 q = v_local.xy;
	float r = length(q);
	float d = r;
	if (pupil_shape == 1) {
		d = length(q * vec2(3.2, 1.0 - 0.18 * q.y * q.y));
	} else if (pupil_shape == 2) {
		d = length(q * vec2(0.55, 2.6));
	}
	float rays = 0.9 + 0.1 * sin(atan(q.y, q.x) * 22.0 + value_noise(q * 6.0) * 6.0);
	vec3 col = base * (0.45 + 0.75 * smoothstep(0.6, -0.9, q.y)) * rays;
	col *= mix(1.0, 0.35, smoothstep(0.72, 0.97, r));
	col = mix(col, vec3(0.012, 0.01, 0.012), smoothstep(pupil_size + 0.04, pupil_size - 0.02, d));
	float glint = smoothstep(0.24, 0.17, length(q - vec2(-0.3, 0.34)));
	glint = max(glint, smoothstep(0.1, 0.06, length(q - vec2(0.3, -0.32))) * 0.7);
	emit = vec3(glint) * 1.3;
	return mix(col, vec3(1.0), glint);
}

void fragment() {
	vec4 lk = look[v_slot];
	vec3 base = palette[v_slot].rgb;
	vec3 emit = vec3(0.0);
	float metal = 0.0;
	float spec = 0.4;
	float rough = lk.x;
	if (v_kind == K_FUR) {
		base = fur(marked(base));
		spec = 0.22;
	} else if (v_kind == K_SKIN) {
		base = marked(base) * (0.95 + value_noise3(v_local * 60.0) * 0.08);
		spec = 0.35;
	} else if (v_kind == K_GLOSS) {
		spec = 0.6;
	} else if (v_kind == K_EYE) {
		// 眼白按单位球建模:往边缘(陷进眼窝处)和上眼睑下压暗,眼珠显得嵌在脸里
		float front = smoothstep(0.15, 0.9, -v_local.z);
		base *= mix(0.62, 1.0, front) * mix(1.0, 0.78, smoothstep(0.35, 0.95, v_local.y));
		spec = 0.7;
	} else if (v_kind == K_IRIS) {
		base = iris(base, emit);
		spec = 0.8;
	} else if (v_kind == K_CLOTH) {
		base = cloth(base, lk);
		spec = 0.3;
	} else if (v_kind == K_SATIN) {
		base *= 0.92 + 0.12 * sin(v_uv.y * 260.0 + v_uv.x * 90.0) * clamp(1.2 - length(fwidth(v_uv * 260.0)), 0.0, 1.0);
		spec = 0.6;
	} else if (v_kind == K_METAL) {
		metal = 1.0;
		base *= 0.85 + value_noise3(v_local * 240.0) * 0.2;
		spec = 0.5;
	}
	base *= v_tag.r;
	vec3 grey = vec3(dot(base, LUMA) * 0.672);
	ALBEDO = mix(base, grey, 0.85 * death);
	ROUGHNESS = rough;
	METALLIC = metal * (1.0 - death);
	SPECULAR = spec;
	RIM = lk.y;
	RIM_TINT = 0.65;
	EMISSION = emit * (1.0 - death);
}
