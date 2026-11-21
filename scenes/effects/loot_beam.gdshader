shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

varying float height;

void vertex() {
	height = clamp(VERTEX.y / 84.0 + 0.5, 0.0, 1.0);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * (1.0 - smoothstep(0.05, 1.0, height));
}
