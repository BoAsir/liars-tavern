// 礼炮彩纸的运动(粒子着色器,全局坐标):从礼炮口沿发射器 +Y 方向的圆锥喷出,受重力、受很大的空气阻力,
// 往下飘时左右晃(纸片的飘)、一路翻滚;落到桌面(桌心 table_center、半径 table_radius 之内)或地板上就平躺不动,
// 生命最后一段缩没。streamer = 1 时是卷曲的彩带:阻力更大、翻得慢、落地也平躺。
// 颜色从一组粉彩里随机挑;每粒的固定随机量由 CUSTOM.y 里存的种子现算(不占别的通道)。
shader_type particles;
render_mode disable_velocity, disable_force;

uniform vec3 table_center = vec3(0.0);
uniform float table_radius = 0.95;
uniform float table_top = 0.782;
uniform float floor_y = 0.0;
uniform vec2 speed = vec2(3.0, 5.5);
uniform float spread = 0.4;         // 圆锥半角(弧度)
uniform float gravity = 2.6;
uniform float drag = 1.6;           // 往上冲时的线性阻力(1/秒)
uniform float drag_fall = 4.0;      // 往下飘时的阻力:纸片张开兜住风,终端速度 = gravity / drag_fall ≈ 0.65 米/秒
uniform float flutter = 0.5;        // 往下飘时左右晃的速度幅度(米/秒)
uniform vec2 size = vec2(0.034, 0.052);
uniform float strip_chance = 0.4;   // 长纸条的比例(其余是方片)
uniform float spin = 11.0;          // 翻滚角速度上限(弧度/秒)
uniform float streamer = 0.0;
uniform float fade_time = 0.7;      // 生命最后这么久缩没

// 粉彩但要够艳:酒馆夜里的暖光与色调映射会把太淡的颜色冲成一片白
const vec3 PALETTE[8] = vec3[8](
	vec3(1.0, 0.32, 0.52), vec3(1.0, 0.78, 0.16), vec3(0.2, 0.8, 0.72), vec3(0.32, 0.58, 1.0),
	vec3(0.66, 0.42, 1.0), vec3(1.0, 0.5, 0.22), vec3(1.0, 0.94, 0.82), vec3(0.5, 0.86, 0.3));

uint hash_u(uint x) {
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	x = ((x >> 16u) ^ x) * 0x45d9f3bu;
	return (x >> 16u) ^ x;
}

float rnd(inout uint s) {
	s = hash_u(s + 0x9e3779b9u);
	return float(s & 0xffffffu) / 16777215.0;
}

void start() {
	uint s = hash_u(NUMBER * 7919u + RANDOM_SEED);
	float seed = float(s & 0xffffu) / 65535.0;
	// 圆锥里随机一个方向(发射器局部 +Y 为轴)
	float a = rnd(s) * TAU;
	float c = mix(cos(spread), 1.0, rnd(s));
	float r = sqrt(max(1.0 - c * c, 0.0));
	vec3 dir_local = vec3(cos(a) * r, c, sin(a) * r);
	vec3 dir = normalize((EMISSION_TRANSFORM * vec4(dir_local, 0.0)).xyz);
	float v = mix(speed.x, speed.y, rnd(s)) * mix(1.0, 0.8, streamer);
	VELOCITY = dir * v;
	TRANSFORM = mat4(1.0);
	TRANSFORM[3].xyz = EMISSION_TRANSFORM[3].xyz + (vec3(rnd(s), rnd(s), rnd(s)) - 0.5) * 0.03;
	COLOR = vec4(PALETTE[int(rnd(s) * 7.999)], 1.0);
	CUSTOM = vec4(0.0, seed, 0.0, rnd(s) * TAU);   // x 年龄、y 种子、z 落地、w 落地后的朝向
}

void process() {
	uint s = hash_u(uint(CUSTOM.y * 65535.0) + 17u);
	float age = CUSTOM.x + DELTA;
	CUSTOM.x = age;
	vec3 pos = TRANSFORM[3].xyz;
	// 每粒的固定随机量
	vec3 axis = normalize(vec3(rnd(s), rnd(s), rnd(s)) - 0.5 + vec3(0.0, 0.0, 0.001));
	float spin_rate = mix(0.35, 1.0, rnd(s)) * spin * mix(1.0, 0.25, streamer);
	float sway_freq = mix(2.2, 4.2, rnd(s));
	float sway_phase = rnd(s) * TAU;
	bool strip = rnd(s) < strip_chance;
	float sz = mix(size.x, size.y, rnd(s));
	float fade_at = LIFETIME - fade_time * mix(1.0, 2.2, rnd(s));
	float lift = mix(0.001, 0.005, rnd(s));   // 落地后离表面的高度:错开,避免几片叠在一起闪
	vec3 scale = streamer > 0.5 ? vec3(mix(0.8, 1.25, rnd(s))) : (strip ? vec3(sz * 0.4, sz * 2.1, 1.0) : vec3(sz, sz, 1.0));
	if (CUSTOM.z < 0.5) {
		float falling = smoothstep(0.0, -0.4, VELOCITY.y);
		float k = mix(drag, drag_fall, falling) * mix(1.0, 1.4, streamer);
		VELOCITY.y -= gravity * DELTA;
		VELOCITY *= exp(-k * DELTA);
		vec3 sway = vec3(sin(age * sway_freq + sway_phase), 0.0, cos(age * sway_freq * 0.8 + sway_phase * 1.7)) * flutter * falling;
		pos += (VELOCITY + sway) * DELTA;
		bool over_table = length(pos.xz - table_center.xz) < table_radius && pos.y > table_top - 0.02;
		float ground = over_table ? table_top : floor_y;
		if (pos.y <= ground + lift && VELOCITY.y < 0.0) {
			pos.y = ground + lift;
			CUSTOM.z = 1.0;
			VELOCITY = vec3(0.0);
		}
	}
	mat3 basis;
	if (CUSTOM.z > 0.5) {
		// 平躺:面片法线(+Z)转成朝上,再绕竖直轴转个随机朝向
		float yaw = CUSTOM.w;
		mat3 flat_m = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, -1.0), vec3(0.0, 1.0, 0.0));
		mat3 turn = mat3(vec3(cos(yaw), 0.0, -sin(yaw)), vec3(0.0, 1.0, 0.0), vec3(sin(yaw), 0.0, cos(yaw)));
		basis = turn * flat_m;
	} else {
		// 绕随机轴翻滚(罗德里格斯公式)
		float ang = age * spin_rate + sway_phase;
		float cs = cos(ang);
		float sn = sin(ang);
		float t = 1.0 - cs;
		basis = mat3(
			vec3(t * axis.x * axis.x + cs, t * axis.x * axis.y + sn * axis.z, t * axis.x * axis.z - sn * axis.y),
			vec3(t * axis.x * axis.y - sn * axis.z, t * axis.y * axis.y + cs, t * axis.y * axis.z + sn * axis.x),
			vec3(t * axis.x * axis.z + sn * axis.y, t * axis.y * axis.z - sn * axis.x, t * axis.z * axis.z + cs));
	}
	float pop = smoothstep(0.0, 0.06, age);
	float shrink = 1.0 - smoothstep(fade_at, fade_at + fade_time, age);
	scale *= max(pop * shrink, 0.0001);
	TRANSFORM[0].xyz = basis[0] * scale.x;
	TRANSFORM[1].xyz = basis[1] * scale.y;
	TRANSFORM[2].xyz = basis[2] * scale.z;
	TRANSFORM[3].xyz = pos;
	if (shrink <= 0.0) {
		ACTIVE = false;
	}
}
