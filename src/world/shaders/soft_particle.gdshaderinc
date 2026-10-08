// 柔和粒子的公共代码:公告板朝向相机,径向衰减,颜色与透明度来自粒子 COLOR。
// 混合模式是编译期 render_mode,由 soft_particle(普通混合)/ soft_particle_add(加色)各自声明后 #include 本文件。
// 枪口焰另用三个参数(默认值下火星的代码路径与输出不变;这里不引用深度纹理,火星一直可见,引用会让每帧多一次深度拷贝):
// shape 1 = 星形火核(6 道带噪声的尖刺),2 = 冠状(沿枪管的十字面片:枪口点最亮,垂直枪管喷开);
// billboard = false 时按网格自己的朝向画;view_offset 把公告板沿视线朝相机推近;实例参数 spin 每枪随机旋转。

uniform float softness = 1.0;
uniform float emission_boost = 1.0;
uniform int shape = 0;
uniform bool billboard = true;
uniform float view_offset = 0.0;
uniform float crown_origin = 0.12;   // 冠状:枪口点在面片 UV.x 上的位置
instance uniform float spin = 0.0;

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		if (view_offset != 0.0) {
			MODELVIEW_MATRIX[3].xyz -= normalize(MODELVIEW_MATRIX[3].xyz) * view_offset;
		}
	}
}

void fragment() {
	float a;
	if (shape == 0) {
		float r = length(UV - 0.5) * 2.0;
		a = pow(clamp(1.0 - r, 0.0, 1.0), softness);
	} else if (shape == 1) {
		vec2 p = UV - 0.5;
		if (spin != 0.0) {
			p = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * p;
		}
		float r = length(p) * 2.0;
		float ang = atan(p.y, p.x);
		float jitter = 0.75 + 0.25 * sin(ang * 5.0 + spin * 7.0) * sin(ang * 3.0 - spin * 3.0);
		float spikes = pow(abs(cos(ang * 3.0)), 6.0) * jitter;
		float reach = 0.28 + 0.72 * spikes;
		a = pow(clamp(1.0 - r / reach, 0.0, 1.0), softness) + pow(clamp(1.0 - r * 2.2, 0.0, 1.0), 2.0);
		a = clamp(a, 0.0, 1.0);
	} else {
		float along = UV.x - crown_origin;
		float radial = abs(UV.y - 0.5) * 2.0;
		float tongue = 0.55 + 0.45 * sin(UV.y * 31.0 + spin * 5.0) * sin(UV.y * 13.0 - spin * 2.0);
		// 枪口点最亮,往后(沿枪身)渐淡,往前(朝头)很快没了;径向喷出的长度带噪声
		float plume = exp(-max(along, 0.0) * 6.0 - max(-along, 0.0) * 30.0);
		a = clamp(plume * pow(clamp(1.0 - radial / max(tongue, 0.2), 0.0, 1.0), softness), 0.0, 1.0);
	}
	ALBEDO = COLOR.rgb * emission_boost;
	ALPHA = a * COLOR.a;
}
