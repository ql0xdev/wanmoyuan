shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 edge = abs(UV * 2.0 - 1.0);
	float shade = smoothstep(0.32, 1.34, length(edge));
	COLOR = vec4(0.014, 0.024, 0.039, shade * 0.64);
}
