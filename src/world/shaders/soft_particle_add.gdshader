// 柔和圆形粒子·加色混合(火星/枪口焰/火花):重叠处亮度相加而发光,不受绘制顺序影响。
// 公共代码见 soft_particle.gdshaderinc。
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/world/shaders/soft_particle.gdshaderinc"
