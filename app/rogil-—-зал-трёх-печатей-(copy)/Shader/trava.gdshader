shader_type spatial;
render_mode cull_disabled;

uniform float wind_strength = 0.25;
uniform float wind_speed = 2.0;
uniform vec3 wind_direction = vec3(1.0, 0.0, 0.5);

void vertex() {
    // Чем выше вершина, тем сильнее качается
    float height_factor = UV.y;

    float wave =
        sin(TIME * wind_speed +
            VERTEX.x * 2.0 +
            VERTEX.z * 2.0);

    vec3 offset =
        normalize(wind_direction) *
        wave *
        wind_strength *
        height_factor;

    VERTEX += offset;
}

void fragment() {
    ALBEDO = vec3(0.25, 0.8, 0.2);

    // Немного затемняем низ травы
    ALBEDO *= mix(0.7, 1.0, UV.y);

    ROUGHNESS = 1.0;
}