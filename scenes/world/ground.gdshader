shader_type canvas_item;
render_mode unshaded;

uniform vec4 ground_tint : source_color = vec4(0.055, 0.067, 0.090, 1.0);
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float grain(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 grid = abs(fract(world_position / 64.0 + 0.5) - 0.5) * 64.0;
	float line = 1.0 - smoothstep(0.35, 1.8, min(grid.x, grid.y));
	vec2 coarse = abs(fract(world_position / 256.0 + 0.5) - 0.5) * 256.0;
	float seam = 1.0 - smoothstep(0.35, 2.0, min(coarse.x, coarse.y));
	vec2 tile = floor(world_position / 64.0);
	float patch = grain(floor(world_position / 256.0));
	vec2 p = fract(world_position / 64.0) - vec2(0.2 + grain(tile + 6.0) * 0.57, 0.2 + grain(tile + 17.0) * 0.57);
	float chips = (1.0 - smoothstep(0.018, 0.052, abs(p.x) + 1.45 * abs(p.y))) * step(0.82, grain(tile));
	float mark = (1.0 - smoothstep(1.0, 3.2, coarse.x + coarse.y)) * 0.65;
	vec3 base = ground_tint.rgb + (patch - 0.45) * vec3(0.010, 0.023, 0.022);
	base += line * vec3(0.024, 0.038, 0.045) + seam * vec3(0.010, 0.035, 0.039);
	base += (chips * 0.75 + mark) * vec3(0.12, 0.14, 0.17);
	vec2 distance_to_center = (SCREEN_UV - vec2(0.5, 0.55)) * vec2(1.55, 1.50);
	float shade = smoothstep(0.40, 0.99, length(distance_to_center));
	COLOR = vec4(mix(base, vec3(0.027, 0.030, 0.047), shade * 0.89), 1.0);
}
