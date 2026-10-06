// 柔和圆形粒子的公共代码:公告板朝向相机,径向衰减,颜色与透明度来自粒子 COLOR。
// 混合模式是编译期 render_mode,由 soft_particle(普通混合)/ soft_particle_add(加色)各自声明后 #include 本文件。

uniform float softness = 1.0;
uniform float emission_boost = 1.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - r, 0.0, 1.0), softness);
	ALBEDO = COLOR.rgb * emission_boost;
	ALPHA = a * COLOR.a;
}
