// 道具共享材质:钢、黄铜、铁、蜡等合进同一个 surface,颜色、粗糙度、金属度来自 MeshForge 顶点数据。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/vertex_pbr.gdshaderinc"

void fragment() {
	ALBEDO = vp_srgb_to_linear(COLOR.rgb);
	ROUGHNESS = UV2.x;
	METALLIC = UV2.y;
}
