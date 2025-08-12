shader_type canvas_item;

uniform sampler2D density_tex;
uniform vec2 tex_size;   // grid size in tiles
uniform float tile_size = 16.0;

vec3 heatmap(float t) {
    // Simple gradient: blue -> green -> yellow -> red
    if (t < 0.25) return mix(vec3(0.0, 0.0, 1.0), vec3(0.0, 1.0, 1.0), t / 0.25);
    if (t < 0.5)  return mix(vec3(0.0, 1.0, 1.0), vec3(0.0, 1.0, 0.0), (t - 0.25) / 0.25);
    if (t < 0.75) return mix(vec3(0.0, 1.0, 0.0), vec3(1.0, 1.0, 0.0), (t - 0.5) / 0.25);
    return mix(vec3(1.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), (t - 0.75) / 0.25);
}

void fragment() {
    vec2 density_uv = UV; // UV in [0,1]
    float density = texture(density_tex, density_uv).r;

    vec3 col = heatmap(clamp(density, 0.0, 1.0));
    COLOR = vec4(col, density * 0.8);
    COLOR = vec4(col, 1);
}
