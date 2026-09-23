shader_type canvas_item;
uniform float trauma = 0.0;
uniform float health = 1.0;
uniform float intensity = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float vignette = smoothstep(0.3, 1.3, length(p * vec2(0.8, 1.0)));
	float danger = max(0.0, 0.35 - health) * (0.7 + sin(TIME * 3.0) * 0.2);
	float red = trauma * 0.32 + danger;
	COLOR = vec4(mix(vec3(0.015, 0.009, 0.019), vec3(0.4, 0.005, 0.025), clamp(red * 3.0, 0.0, 1.0)), vignette * (0.24 + red) * intensity);
}
