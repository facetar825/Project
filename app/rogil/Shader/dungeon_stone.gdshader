shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_position;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}
void fragment() {
	bool floor_surface = abs(world_normal.y) > 0.7;
	vec2 uv = floor_surface ? world_position.xz / 2.0 : vec2(abs(world_normal.x) > 0.7 ? world_position.z : world_position.x, world_position.y) / vec2(2.5, 1.15);
	if (!floor_surface) { uv.x += mod(floor(uv.y), 2.0) * 0.5; }
	vec2 cell = floor(uv);
	vec2 edge = min(fract(uv), 1.0 - fract(uv));
	float seam = smoothstep(0.012, 0.038, min(edge.x, edge.y));
	float grain = hash(floor(world_position.xz * 45.0) + world_position.y);
	float shade = hash(cell);
	vec3 stone = floor_surface ? mix(vec3(0.20,0.25,0.27), vec3(0.30,0.34,0.34), shade) : mix(vec3(0.18,0.22,0.25), vec3(0.28,0.32,0.34), shade);
	ALBEDO = mix(vec3(0.07,0.09,0.10), stone, seam) * (0.98 + grain * 0.04);
	ROUGHNESS = 0.92;
}
