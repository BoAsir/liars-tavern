// 道具共享材质:钢、黄铜、铁、蜡、珐琅等合进同一个 surface,颜色、粗糙度、金属度来自 MeshForge 顶点数据。
// UV = MeshForge.glow:x 自发光强度(灯泡 1.0、灯罩内壁 0.12、蜡烛顶端渐亮到 0.06),y 透光(蜡 0.35);
// 没写 UV 的网格读到 0,和原来一样。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/vertex_pbr.gdshaderinc"

uniform vec3 emission_color : source_color = vec3(1.0, 0.78, 0.5);
uniform float emission_energy = 4.0;
uniform vec3 backlight_color : source_color = vec3(0.9, 0.55, 0.3);

void fragment() {
	ALBEDO = vp_srgb_to_linear(COLOR.rgb);
	AO = COLOR.a;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = UV2.x;
	METALLIC = UV2.y;
	EMISSION = emission_color * emission_energy * UV.x;
	BACKLIGHT = backlight_color * UV.y;
}
