shader_type canvas_item;

uniform vec2 button_extent = vec2(0.0);
uniform float press_scale = 1.0;

void vertex() {
	// 仅移动绘制顶点，不改变 Control 边界或触屏命中范围。
	vec2 center = button_extent * 0.5;
	VERTEX = (VERTEX - center) * press_scale + center;
}
