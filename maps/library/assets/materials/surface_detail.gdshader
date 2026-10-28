shader_type spatial;
render_mode cull_back;

// Expanded Library surface detail (phase B polish): the material of the batched boxes
// (shared/scripts/level/batched_boxes.gd). A box is drawn in its own flat colour, as
// with the plain vertex-colour material before, times a subtle tileable texture when a
// rule matches: the box's colour, the face's direction (floor faces up, or walls) and
// where it is. The textures average 1 (each rule divides by its texture's mean), so the
// colours are unchanged; only fine detail is added. Rules and textures are set in
// surface_detail.tres, written by maps/library/tools/expansion/make_surface_detail.gd.

// rule_color: rgb = the box colour to match; a = strength (0 = off).
// rule_rect: x0, z0, x1, z1 (world) the rule applies within.
// rule_y: y0, y1 (world) the rule applies within; z, w unused.
// rule_kind: x = texture (0..7), y = face (0 floor, faces up; 1 wall, vertical faces),
//            z = metres per texture tile, w = the texture's mean.
uniform vec4 rule_color[16];
uniform vec4 rule_rect[16];
uniform vec4 rule_y[16];
uniform vec4 rule_kind[16];
uniform int rule_count = 0;
uniform sampler2D tex0 : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex1 : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex2 : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex3 : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex4 : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex5 : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex6 : filter_linear_mipmap, repeat_enable;
uniform sampler2D tex7 : filter_linear_mipmap, repeat_enable;
uniform float roughness_value = 0.9;

varying vec3 world_pos;
varying vec3 world_nrm;
varying vec4 box_colour;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	box_colour = COLOR;
}

float sample_tex(int t, vec2 uv) {
	if (t == 0) return texture(tex0, uv).r;
	if (t == 1) return texture(tex1, uv).r;
	if (t == 2) return texture(tex2, uv).r;
	if (t == 3) return texture(tex3, uv).r;
	if (t == 4) return texture(tex4, uv).r;
	if (t == 5) return texture(tex5, uv).r;
	if (t == 6) return texture(tex6, uv).r;
	return texture(tex7, uv).r;
}

void fragment() {
	vec3 c = box_colour.rgb;
	float detail = 1.0;
	for (int i = 0; i < rule_count; i++) {
		vec4 rc = rule_color[i];
		if (rc.a <= 0.0 || distance(c, rc.rgb) > 0.004) continue;
		vec4 rr = rule_rect[i];
		if (world_pos.x < rr.x || world_pos.x > rr.z || world_pos.z < rr.y || world_pos.z > rr.w) continue;
		vec4 ry = rule_y[i];
		if (world_pos.y < ry.x || world_pos.y > ry.y) continue;
		vec4 k = rule_kind[i];
		vec2 uv;
		if (k.y < 0.5) {
			if (world_nrm.y < 0.9) continue;
			uv = world_pos.xz / k.z;
		} else {
			if (abs(world_nrm.y) > 0.1) continue;
			uv = (abs(world_nrm.x) > 0.5 ? world_pos.zy : world_pos.xy) / k.z;
		}
		detail = mix(1.0, sample_tex(int(k.x), uv) / k.w, rc.a);
		break;
	}
	ALBEDO = c * detail;
	ROUGHNESS = roughness_value;
}
