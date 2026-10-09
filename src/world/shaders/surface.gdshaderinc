// 墙地着色器的噪声采样(SurfaceNoise 烘焙的可平铺贴图,按 mip 采样,远处自然抗锯齿)与解析凹凸。
// 统计上与 noise.gdshaderinc 的 fbm / value_noise 相近:参数 p 的单位与原来的 fbm(p) / value_noise(p) 一致。
// 凹凸只取解析形状(板缝、倒角、灰缝、裂缝),不用噪声:8 位贴图量化后在法线上会出色带。

uniform sampler2D surface_noise : filter_linear_mipmap_anisotropic, repeat_enable;

float n_lo(vec2 p) {     // 5 层 fbm,对应 fbm(p);整张图 16 个单位
	return texture(surface_noise, p / 16.0).r;
}

float n_hi(vec2 p) {     // 细值噪声,对应 value_noise(p);整张图 128 个单位
	return texture(surface_noise, p / 128.0).g;
}

float n_cell(vec2 p) {   // 细胞 F2−F1:0 在细胞边线上;每单位一个细胞
	return texture(surface_noise, p / 12.0).b;
}

vec3 bump_normal(vec3 n, vec3 pos, float h, float strength) {
	// 屏幕导数凹凸(Mikkelsen):n、pos 都在视图空间,h 的单位是米;不需要切线
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - strength * grad);
}

float aa_step(float edge, float x) {
	// 抗锯齿阶跃:过渡宽度跟着屏幕导数走
	float w = max(fwidth(x), 1e-5);
	return smoothstep(edge - w, edge + w, x);
}
