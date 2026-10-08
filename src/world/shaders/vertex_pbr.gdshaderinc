// 顶点 PBR 共用函数:MeshForge 合并网格的 COLOR.rgb 存 sRGB albedo(8 位存线性色暗部误差太大),着色器里转线性。
vec3 vp_srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
