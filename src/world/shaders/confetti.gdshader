// 礼炮彩纸 / 彩带的画法:不打光的粉彩纯色,按纸面朝向镜头的程度明暗(翻滚时一闪一闪,像纸片反光);
// 不投影、不透明(缩没代替淡出,几百片不用排序)。颜色来自粒子 COLOR。
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float brightness = 0.92;
varying float facing;

void vertex() {
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	facing = abs(n.z);
}

void fragment() {
	ALBEDO = COLOR.rgb * brightness * (0.45 + 0.6 * facing);
}
