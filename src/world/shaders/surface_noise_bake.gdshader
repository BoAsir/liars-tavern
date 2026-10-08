// 启动时烘焙一次的可平铺噪声贴图(SurfaceNoise):墙地木纹、灰泥、地毯等按 mip 采样它,代替逐像素的 ALU fbm。
// R:5 层值噪声 fbm,第 k 层格点数 16·2^k(整张图 = 16 个单位);G:2 层细值噪声(整张图 = 128 个单位);
// B:细胞噪声 F2−F1,12×12 格回绕。每层格点按周期取模,所以整张图上下左右无缝。
shader_type canvas_item;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float periodic_value(vec2 p, float period, vec2 offset) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(mod(i, period) + offset);
	float b = hash12(mod(i + vec2(1.0, 0.0), period) + offset);
	float c = hash12(mod(i + vec2(0.0, 1.0), period) + offset);
	float d = hash12(mod(i + vec2(1.0, 1.0), period) + offset);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

vec2 cell_point(vec2 cell) {
	vec2 c = mod(cell, 12.0);
	return vec2(hash12(c + 71.3), hash12(c + 13.9)) * 0.8 + 0.1;
}

float cell_edge(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			float d = length(o + cell_point(i + o) - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return clamp(d2 - d1, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;
	float r = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int k = 0; k < 5; k++) {
		float period = 16.0 * pow(2.0, float(k));
		r += amp * periodic_value(uv * period, period, vec2(float(k) * 17.0, float(k) * 9.0));
		norm += amp;
		amp *= 0.5;
	}
	r /= norm;
	float g = periodic_value(uv * 128.0, 128.0, vec2(3.0, 41.0)) * 0.65
		+ periodic_value(uv * 256.0, 256.0, vec2(29.0, 7.0)) * 0.35;
	float b = cell_edge(uv * 12.0);
	COLOR = vec4(r, g, b, 1.0);
}
