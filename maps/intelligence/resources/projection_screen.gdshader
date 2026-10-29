shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;
uniform sampler2D image : source_color, filter_linear, repeat_disable;
uniform mat4 projector_view;
uniform mat4 projector_projection;
uniform bool enabled = false;
varying vec3 world_point;
void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec4 clip = projector_projection * projector_view * vec4(world_point, 1.0);
    vec2 point = clip.xy / max(clip.w, 0.001) * 0.5 + 0.5;
    point.y = 1.0 - point.y;
    ALBEDO = enabled ? texture(image, point).rgb : vec3(0.045, 0.07, 0.065);
}
