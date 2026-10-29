extends Node3D
## A finite presentation, independently pausable from the frozen actors.
const C := preload("res://maps/intelligence/resources/layout/k17_sabotage.gd")
var active := false
var elapsed := 0.0
var run_id := -1
var starts := 0
var effects_played := false
var _camera: Camera3D
var _smoke: CPUParticles3D
var _sparks: CPUParticles3D
var _fire: CPUParticles3D
var _flash: OmniLight3D
var _sound: AudioStreamPlayer3D
var _overlay: CanvasLayer
var _sound_caption: Label
var _hidden: Array[CanvasLayer] = []
var _warmup: SubViewport
var _warm_view: SubViewport
var _warm_camera: Camera3D
var _warm_frames := 0

func _ready() -> void:
	_camera = Camera3D.new()
	_camera.fov = 62
	add_child(_camera)
	_smoke = _particles(88, 3.0, Color(.19,.21,.20,.8), .6, 1.7)
	_smoke.position = C.SMOKE
	_sparks = _particles(36, .7, Color(1,.42,.12,.9), .08, .2)
	_sparks.position = C.SMOKE
	_sparks.initial_velocity_min = 3
	_sparks.initial_velocity_max = 6
	_sparks.gravity = Vector3(0,-3,0)
	_fire = _particles(24, .55, Color(1,.48,.1,.9), .4, 1.1)
	_fire.position = C.SMOKE
	(_fire.mesh.material as StandardMaterial3D).emission_enabled = true
	(_fire.mesh.material as StandardMaterial3D).emission = Color(1,.3,.04)
	_flash = OmniLight3D.new()
	_flash.position = C.SMOKE
	_flash.light_color = Color(1,.45,.15)
	_flash.omni_range = 10
	_flash.light_energy = 0
	_flash.shadow_enabled = false
	add_child(_flash)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = preload("res://maps/intelligence/assets/audio/sabotage_blast.wav")
	_sound.bus = &"Master"
	_sound.position = C.SMOKE
	_sound.max_distance = 90
	_sound.unit_size = 12
	_sound.volume_db = -8
	add_child(_sound)
	_overlay = CanvasLayer.new()
	_overlay.layer = 12
	add_child(_overlay)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top: bar.offset_bottom = 48
		else: bar.offset_top = -72
		_overlay.add_child(bar)
	var caption := Label.new()
	caption.text = "ĐÃ RÚT KHỎI K17 · KÍCH HOẠT PHÁ HOẠI\nEnter: bỏ qua cảnh · Esc/P: tạm dừng"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -61
	caption.add_theme_font_size_override("font_size", 18)
	_overlay.add_child(caption)
	_sound_caption = Label.new()
	_sound_caption.text = "[Âm thanh] Vụ nổ từ khu thiết bị tình báo dự phòng"
	_sound_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sound_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_sound_caption.offset_top = -112
	_sound_caption.add_theme_color_override("font_color", Color(1,.9,.7))
	_sound_caption.add_theme_constant_override("outline_size", 5)
	_sound_caption.hide()
	_overlay.add_child(_sound_caption)
	_overlay.hide()
	var flow := GameFlow.find(self)
	if flow: flow.state_changed.connect(_flow_changed)
	_warm_effect_materials()

func _warm_effect_materials() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	# Draw the exact particle materials once during level loading, away from the
	# playable world. Preloading a texture alone does not compile its GPU variant.
	_warmup = SubViewport.new()
	_warmup.size = Vector2i(16,16)
	_warmup.own_world_3d = true
	_warmup.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_warmup)
	var camera := Camera3D.new()
	camera.position = Vector3(0,0,3)
	_warmup.add_child(camera)
	camera.make_current()
	for source in [_smoke,_sparks,_fire]:
		var particle := source.duplicate() as CPUParticles3D
		particle.position = Vector3.ZERO
		particle.amount = 1
		particle.lifetime = 1
		particle.initial_velocity_min = 0
		particle.initial_velocity_max = 0
		particle.gravity = Vector3.ZERO
		_warmup.add_child(particle)
		particle.emitting = true
	# Warm the two exterior shots too: the first wide view otherwise uploads
	# previously unseen roof batches at the moment the cinematic cuts to them.
	_warm_view = SubViewport.new()
	_warm_view.size = Vector2i(32,32)
	_warm_view.world_3d = get_world_3d()
	_warm_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_warm_view)
	_warm_camera = Camera3D.new()
	_warm_view.add_child(_warm_camera)
	_warm_camera.position = C.VIEWS[&"maintenance"][0]
	_warm_camera.look_at(C.VIEWS[&"maintenance"][1])
	_warm_camera.make_current()

func _process(_delta: float) -> void:
	if not is_instance_valid(_warmup):
		set_process(false)
		return
	_warm_frames += 1
	if _warm_frames == 4:
		_warm_camera.position = C.VIEWS[&"courtyard"][0]
		_warm_camera.look_at(C.VIEWS[&"courtyard"][1])
	if _warm_frames >= 8:
		_warmup.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_warmup.queue_free()
		_warmup = null
		_warm_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_warm_view.queue_free()
		_warm_view = null
		set_process(false)

func _particles(amount: int, lifetime: float, colour: Color, minimum: float, maximum: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = .9
	p.direction = Vector3.UP
	p.spread = 28
	p.gravity = Vector3(0,.6,0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.2
	p.scale_amount_min = minimum
	p.scale_amount_max = maximum
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = .4
	# Soft radial billboards avoid solid low-poly balls masquerading as smoke.
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0,.3,1])
	gradient.colors = PackedColorArray([Color.WHITE,Color(1,1,1,.7),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(.5,.5)
	texture.fill_to = Vector2(1,.5)
	mat.albedo_texture = texture
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0,.12,.7,1])
	fade.colors = PackedColorArray([Color(1,1,1,0),Color.WHITE,Color(1,1,1,.8),Color(1,1,1,0)])
	p.color_ramp = fade
	mesh.material = mat
	p.mesh = mesh
	add_child(p)
	return p

func _mission() -> K17MissionController:
	return get_parent().get_node_or_null("Mission") as K17MissionController

func start(route: StringName, token: int) -> bool:
	var m := _mission()
	if active or m == null or not m.escaped or token != m.run_id: return false
	active = true
	run_id = token
	elapsed = 0
	starts += 1
	effects_played = false
	_sound_caption.hide()
	var view: Array = C.VIEWS.get(route, C.VIEWS[&"maintenance"])
	_camera.position = view[0]
	_camera.look_at(view[1])
	_camera.make_current()
	var hud := get_parent().get_parent().get_node_or_null("ObjectiveHud") as ObjectiveHud
	if hud and hud.is_journal_open(): hud.close_journal()
	for name in ["ObjectiveHud", "StealthHud"]:
		var layer := get_parent().get_parent().get_node_or_null(name) as CanvasLayer
		if layer and layer.visible:
			_hidden.append(layer)
			layer.hide()
	_overlay.show()
	return true

func _physics_process(delta: float) -> void:
	if not active: return
	var m := _mission()
	var flow := GameFlow.find(self)
	if m == null or m.run_id != run_id or flow == null or flow.is_leaving():
		cancel()
		return
	if flow.state != GameStateMachine.State.PLAYING: return
	elapsed += delta
	_sound_caption.visible = effects_played and GameSettings.captions
	if elapsed >= C.DETONATE_AT and not effects_played:
		effects_played = true
		if m.detonate_sabotage(run_id):
			_smoke.restart()
			_smoke.emitting = true
			_sparks.restart()
			_sparks.emitting = true
			_fire.restart()
			_fire.emitting = true
			_sound.play()
			SoundCaptions.cue(self, "k17_sabotage", "Vụ nổ từ khu thiết bị tình báo dự phòng")
	_flash.light_energy = maxf(0, 3.5 * (1.0 - (elapsed-C.DETONATE_AT)/.35)) if effects_played else 0.0
	if elapsed >= C.FINALE_SECONDS: finish()

func _unhandled_input(event: InputEvent) -> void:
	if active and elapsed >= .5 and event.is_action_pressed("ui_accept") and not event.is_echo():
		var flow := GameFlow.find(self)
		if flow and flow.state == GameStateMachine.State.PLAYING:
			get_viewport().set_input_as_handled()
			finish()

func finish() -> void:
	if not active: return
	var flow := GameFlow.find(self)
	if flow == null or flow.is_leaving() or flow.state != GameStateMachine.State.PLAYING: return
	var token := run_id
	var m := _mission()
	cancel()
	if m: m.complete_finale(token)

func cancel() -> void:
	active = false
	if _sound: _sound.stop()
	if _smoke: _smoke.emitting = false
	if _sparks: _sparks.emitting = false
	if _fire: _fire.emitting = false
	if _flash: _flash.light_energy = 0
	if _overlay: _overlay.hide()
	for layer in _hidden:
		if is_instance_valid(layer): layer.show()
	_hidden.clear()
	if _camera and _camera.current:
		_camera.clear_current()
		var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
		if player: player.camera.make_current()

func _flow_changed(_from: GameStateMachine.State, to: GameStateMachine.State) -> void:
	if _sound: _sound.stream_paused = to == GameStateMachine.State.PAUSED
