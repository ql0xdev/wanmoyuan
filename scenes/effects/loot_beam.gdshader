shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0);
varying float height;

void vertex() {
	height = clamp(VERTEX.y / 84.0 + 0.5, 0.0, 1.0);
}

void fragment() {
	ALBEDO = tint.rgb;
	ALPHA = 0.88 * (1.0 - smoothstep(0.10, 1.0, height));
}
