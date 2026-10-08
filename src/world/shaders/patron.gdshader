// 酒客共享材质:颜色、粗糙度、金属度来自 MeshForge 顶点数据(COLOR = sRGB albedo,UV2 = 粗糙度/金属度),
// 所有酒客共用一份;出局褪色是实例参数 fade(Patron.die 补间),不再给每个酒客复制材质。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/vertex_pbr.gdshaderinc"

instance uniform float fade = 0.0;   // 0 正常 → 1 褪成灰
const vec3 GREY = vec3(0.42);        // = Patron.GREY(sRGB)

void fragment() {
	vec3 c = COLOR.rgb;
	float metal = UV2.y;
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));             // = Color.get_luminance()
	c = mix(c, GREY * lum * 1.6, 0.85 * fade * step(metal, 0.5)); // 金属件(铜扣)不褪色,与旧版一致
	ALBEDO = vp_srgb_to_linear(c);
	ROUGHNESS = UV2.x;
	METALLIC = metal;
	RIM = 0.3 * (1.0 - metal);   // 布料与皮毛有卡通边光(旧材质 rim 0.3 / tint 0.5),金属件没有
	RIM_TINT = 0.5;
}
