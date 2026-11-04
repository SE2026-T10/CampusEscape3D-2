extends SceneTree

## Development tool (phase B polish, approved): writes the Expanded Library's surface
## detail material, res://maps/library/assets/materials/surface_detail.tres, the
## material of the level's and the expansion's plain batched boxes (fixes_x22.gd points
## the level at it; build_expansion.gd uses it). It holds the shader's textures and its
## rules: which box colour, which faces and where gets which texture.
##   godot --headless --path . --script res://maps/library/tools/expansion/make_surface_detail.gd
## Run after changing a rule or a texture. Exits with 0 on success.

const OUT := "res://maps/library/assets/materials/surface_detail.tres"
const SHADER := "res://maps/library/assets/materials/surface_detail.gdshader"
const DIR := "res://maps/library/assets/textures/surface/"
## The textures (code-made, grey, tileable, 512 px), their slots and their means.
const TEXTURES := [["terrazzo", 0.8859], ["plaster", 0.9249], ["wood_grain", 0.8981], ["wood_planks", 0.8830],
	["carpet_weave", 0.8980], ["speckle", 0.8961], ["concrete", 0.9005], ["stone_blocks", 0.8438]]
const FLOOR := 0
const WALL := 1
const ALL := [-100.0, -100.0, 100.0, 100.0]
const GROUND := [-0.5, 1.0]
const UPPER := [4.0, 5.5]
const ANY_Y := [-10.0, 20.0]
## [box colour, strength, rect x0 z0 x1 z1, y range, texture, face, metres per tile, what]
const RULES := [
	["807a73", 1.0, [-12.2, 9.8, 12.2, 28.2], GROUND, "terrazzo", FLOOR, 1.2, "lobby floor"],
	["9e998f", 1.0, [-5.2, 27.8, 5.2, 34.2], GROUND, "stone_blocks", FLOOR, 2.4, "porch floor"],
	["664d38", 1.0, [-12.2, -14.2, 12.2, 10.2], GROUND, "wood_planks", FLOOR, 2.4, "reading hall floor"],
	["666966", 1.0, [-6.2, -8.2, 12.2, 10.2], UPPER, "wood_planks", FLOOR, 2.4, "staff balcony floor"],
	["57616b", 1.0, [-12.2, -28.2, 12.2, -13.8], GROUND, "carpet_weave", FLOOR, 1.0, "study room floors"],
	["545c66", 1.0, [-6.2, -28.2, 12.2, -13.8], UPPER, "carpet_weave", FLOOR, 1.0, "office floors"],
	["8f918c", 1.0, [11.8, -28.2, 17.2, 28.2], GROUND, "speckle", FLOOR, 1.5, "service corridor floor"],
	["666661", 1.0, [16.8, -28.2, 36.2, 12.0], GROUND, "speckle", FLOOR, 1.5, "processing and storage floors"],
	["666661", 1.0, [16.8, 12.0, 36.2, 28.2], GROUND, "concrete", FLOOR, 3.0, "loading dock floor"],
	["707370", 1.0, ALL, ANY_Y, "concrete", FLOOR, 3.0, "basement, tunnel and west landing floors"],
	["4d5461", 1.0, ALL, ANY_Y, "concrete", FLOOR, 3.0, "pump and electrical room floors"],
	["8c8780", 1.0, ALL, ANY_Y, "stone_blocks", FLOOR, 2.4, "storm drain floor"],
	["c7b89e", 1.0, ALL, ANY_Y, "plaster", WALL, 3.0, "cream walls everywhere"],
	["5c3d24", 1.0, ALL, ANY_Y, "wood_grain", WALL, 1.5, "oak wainscot panelling"],
	["999991", 1.0, ALL, ANY_Y, "concrete", WALL, 3.0, "basement concrete walls"],
]


func _init() -> void:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER)
	var slot := {}
	for i in TEXTURES.size():
		m.set_shader_parameter("tex%d" % i, load(DIR + TEXTURES[i][0] + ".png"))
		slot[TEXTURES[i][0]] = i
	var colour := PackedVector4Array()
	var rect := PackedVector4Array()
	var ys := PackedVector4Array()
	var kind := PackedVector4Array()
	for r in RULES:
		var c := Color.html(r[0])
		var t: int = slot[r[4]]
		colour.append(Vector4(c.r, c.g, c.b, r[1]))
		rect.append(Vector4(r[2][0], r[2][1], r[2][2], r[2][3]))
		ys.append(Vector4(r[3][0], r[3][1], 0, 0))
		kind.append(Vector4(t, r[5], r[6], TEXTURES[t][1]))
	assert(RULES.size() <= 16, "the shader holds 16 rules")
	while colour.size() < 16:
		colour.append(Vector4.ZERO)
		rect.append(Vector4.ZERO)
		ys.append(Vector4.ZERO)
		kind.append(Vector4.ZERO)
	m.set_shader_parameter("rule_color", colour)
	m.set_shader_parameter("rule_rect", rect)
	m.set_shader_parameter("rule_y", ys)
	m.set_shader_parameter("rule_kind", kind)
	m.set_shader_parameter("rule_count", RULES.size())
	m.set_shader_parameter("roughness_value", 0.9)
	var err := ResourceSaver.save(m, OUT)
	print("make_surface_detail: wrote %s (%d rules): %s" % [OUT, RULES.size(), "ok" if err == OK else error_string(err)])
	quit(0 if err == OK else 1)
