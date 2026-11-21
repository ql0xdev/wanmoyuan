shader_type spatial;
render_mode shadows_disabled;

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 grid = world_xz / 96.0;
	vec2 line_distance = abs(fract(grid + 0.5) - 0.5);
	vec2 aa = max(fwidth(grid), vec2(0.001));
	vec2 line = 1.0 - smoothstep(vec2(0.006), vec2(0.006) + aa, line_distance);
	ALBEDO = mix(vec3(0.11, 0.16, 0.15), vec3(0.18, 0.24, 0.22), max(line.x, line.y));
	ROUGHNESS = 1.0;
}
