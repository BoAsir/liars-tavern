// 酒瓶:不透明的风格化假玻璃(MultiMesh 绘制,半透明物体既不能实例化也不进深度预通道)。
// 顶点 COLOR.a 是部件:0 玻璃、0.5 标签、1 瓶塞;MultiMesh 实例色(乘进 COLOR.rgb)是玻璃色;
// INSTANCE_CUSTOM.x 是液面高度(瓶高比例),.y 是标签色调。网格按单位瓶高建,实例 Y 缩放成真实高度。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/vertex_pbr.gdshaderinc"

const float BODY_TOP = 0.62;   // 瓶身到这里为止,液体只在瓶身里

varying float bottle_y;
varying float part;
varying vec2 inst;

void vertex() {
	bottle_y = VERTEX.y;
	part = COLOR.a;
	inst = INSTANCE_CUSTOM.xy;
}

void fragment() {
	vec3 tint = vp_srgb_to_linear(COLOR.rgb);
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	if (part > 0.75) {
		// 软木塞
		ALBEDO = vp_srgb_to_linear(vec3(0.45, 0.31, 0.18));
		ROUGHNESS = 0.9;
		SPECULAR = 0.2;
	} else if (part > 0.25) {
		// 纸标签:米色底 + 一道按色调变化的色带
		vec3 accent = vp_srgb_to_linear(0.42 + 0.14 * cos(6.2832 * (inst.y + vec3(0.0, 0.33, 0.67))));
		float band = smoothstep(0.32, 0.335, bottle_y) * (1.0 - smoothstep(0.375, 0.39, bottle_y));
		ALBEDO = mix(vp_srgb_to_linear(vec3(0.72, 0.65, 0.5)), accent * 0.7, band);
		ROUGHNESS = 0.85;
		SPECULAR = 0.25;
	} else {
		// 玻璃:深色瓶身,液面以下颜色更饱满;边缘菲涅尔提亮,读得出玻璃的轮廓
		float liquid = step(bottle_y, inst.x) * step(bottle_y, BODY_TOP);
		vec3 glass = mix(tint * 0.22, tint * 0.6 + vec3(0.04, 0.025, 0.0), liquid);
		ALBEDO = glass;
		ROUGHNESS = 0.06;
		SPECULAR = 0.9;
		EMISSION = tint * (0.03 + 0.35 * fresnel);
	}
}
