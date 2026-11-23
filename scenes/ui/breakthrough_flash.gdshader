shader_type canvas_item;

void fragment() {
	vec2 at = (UV - vec2(0.5, 0.40)) * vec2(1.0, 1.15);
	float core = 1.0 - smoothstep(0.02, 0.72, length(at));
	vec3 warm_gold = vec3(1.0, 0.71, 0.25);
	vec3 bright_gold = vec3(1.0, 0.96, 0.79);
	COLOR = vec4(mix(warm_gold, bright_gold, core), COLOR.a * mix(0.72, 1.0, core));
}
