shader_type spatial;

uniform vec3 grass_color = vec3(0.25, 0.7, 0.2);
uniform vec3 dirt_color = vec3(0.2, 0.15, 0.08);

float random(vec2 uv){
    return fract(sin(dot(uv, vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {

    // Размер пикселей шума
    vec2 pixel_uv = floor(UV * 128.0) / 128.0;

    float noise = random(pixel_uv);

    vec3 color = grass_color;

    // Темные пятна
    if(noise > 0.7){
        color *= 0.8;
    }

    // Коричневые вкрапления земли
    if(noise > 0.9){
        color = mix(color, dirt_color, 0.7);
    }
	if(noise < 0.33)
    color *= 0.9;
else if(noise < 0.66)
    color *= 1.0;
else
    color *= 1.1;

    ALBEDO = color;
    ROUGHNESS = 1.0;
}