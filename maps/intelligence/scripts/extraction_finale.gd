extends Node3D
## A finite presentation, independently pausable from the frozen actors.
const C := preload("res://maps/intelligence/resources/layout/k17_sabotage.gd")
const WORKSHOP_SHADOW_DISTANCE := 24.0
const WORKSHOP_RENDER_HEIGHT := 900.0
const WORKSHOP_EFFECT_HEIGHT := 720.0
const WORKSHOP_RESULTS_LEAD := .25
const WORKSHOP_RESULTS_TINT := Color(.27, .42, .33)
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
var _warm_cover: CanvasLayer
var _workshop_view: SubViewport
var _workshop_layer: CanvasLayer
var _workshop_backdrop: TextureRect
var _workshop_effects: SubViewport
var _workshop_effect_image: TextureRect
var _workshop_particles: Array[CPUParticles3D] = []
var _workshop_glow: Sprite3D
var _workshop_intro_ready := false
var _previous_disable_3d := false
var _warm_frames := 0
var _shot_moon: DirectionalLight3D
var _previous_shadow_distance: float

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
	# A keeps the inexpensive offscreen warm-up.
	_warm_view = SubViewport.new()
	_warm_view.size = Vector2i(32, 32)
	_warm_view.world_3d = get_world_3d()
	_warm_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_warm_view)
	var courtyard := Camera3D.new()
	courtyard.fov = _camera.fov
	_warm_view.add_child(courtyard)
	_position_camera(courtyard, &"courtyard")
	courtyard.make_current()
	_setup_workshop_view()
	RenderingServer.frame_pre_draw.connect(_warm_workshop, CONNECT_ONE_SHOT)

func _setup_workshop_view() -> void:
	var viewport := get_viewport()
	_workshop_view = SubViewport.new()
	_workshop_view.world_3d = get_world_3d()
	# The moon draws the foreground shadows. The yard lights still light the shot.
	_workshop_view.positional_shadow_atlas_size = 0
	_workshop_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_workshop_view)
	var camera := Camera3D.new()
	camera.fov = _camera.fov
	_workshop_view.add_child(camera)
	_position_camera(camera, &"maintenance")
	camera.make_current()
	_workshop_layer = CanvasLayer.new()
	_workshop_layer.layer = 10
	_workshop_layer.hide()
	add_child(_workshop_layer)
	_workshop_backdrop = _add_workshop_image(_workshop_view)
	_setup_workshop_effects()
	_resize_workshop_view()
	viewport.size_changed.connect(_resize_workshop_view)

func _add_workshop_image(viewport: SubViewport) -> TextureRect:
	var image := TextureRect.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture = viewport.get_texture()
	_workshop_layer.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return image

func _setup_workshop_effects() -> void:
	# Draw the moving effects at the same angle in an otherwise empty world.
	_workshop_effects = SubViewport.new()
	_workshop_effects.own_world_3d = true
	_workshop_effects.transparent_bg = true
	_workshop_effects.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_workshop_effects)
	var camera := Camera3D.new()
	camera.fov = _camera.fov
	_workshop_effects.add_child(camera)
	_position_camera(camera, &"maintenance")
	camera.make_current()
	for source in [_smoke, _sparks, _fire]:
		var particle := source.duplicate() as CPUParticles3D
		_workshop_effects.add_child(particle)
		_workshop_particles.append(particle)
	_workshop_glow = Sprite3D.new()
	_workshop_glow.position = C.SMOKE
	_workshop_glow.texture = (_fire.mesh.material as StandardMaterial3D).albedo_texture
	_workshop_glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_workshop_glow.pixel_size = .045
	_workshop_glow.modulate = Color(1, .50, .21, .5)
	_workshop_effects.add_child(_workshop_glow)
	_workshop_effect_image = _add_workshop_image(_workshop_effects)
	_workshop_effect_image.hide()

func _resize_workshop_view() -> void:
	# The result card can scale its final image without drawing the scene again.
	if _workshop_layer.visible and not active: return
	var size := get_viewport().get_texture().get_size().max(Vector2(2, 2))
	var backdrop_size := Vector2i((size * minf(1.0, WORKSHOP_RENDER_HEIGHT / size.y)).round())
	if _workshop_view.size != backdrop_size:
		_workshop_view.size = backdrop_size
		_workshop_intro_ready = false
		if _workshop_layer.visible:
			_workshop_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_workshop_effects.size = Vector2i((size * minf(1.0, WORKSHOP_EFFECT_HEIGHT / size.y)).round())

func _warm_workshop() -> void:
	if active or not is_inside_tree(): return
	# Preserve this viewport's render targets until the shot plays.
	_warm_cover = CanvasLayer.new()
	_warm_cover.layer = 128
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warm_cover.add_child(cover)
	add_child(_warm_cover)
	_apply_workshop_shadows()
	_overlay.show()
	_workshop_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_workshop_effects.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_finish_workshop_warmup, CONNECT_ONE_SHOT)

func _finish_workshop_warmup() -> void:
	_workshop_intro_ready = true
	_restore_workshop_shadows()
	_overlay.hide()
	_warm_cover.queue_free()
	_warm_cover = null

func _process(_delta: float) -> void:
	if not is_instance_valid(_warmup):
		set_process(false)
		return
	_warm_frames += 1
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

func _position_camera(camera: Camera3D, route: StringName) -> void:
	var view: Array = C.VIEWS.get(route, C.VIEWS[&"maintenance"])
	camera.position = view[0]
	camera.look_at(view[1])

func _apply_workshop_shadows() -> void:
	var environment := get_node("../../K17Environment")
	_shot_moon = environment.get_node("Moon")
	_previous_shadow_distance = _shot_moon.directional_shadow_max_distance
	_shot_moon.directional_shadow_max_distance = minf(_previous_shadow_distance, WORKSHOP_SHADOW_DISTANCE)

func _restore_workshop_shadows() -> void:
	if _shot_moon:
		_shot_moon.directional_shadow_max_distance = _previous_shadow_distance
		_shot_moon = null

func start(route: StringName, token: int) -> bool:
	var m := _mission()
	if active or m == null or not m.escaped or token != m.run_id: return false
	active = true
	run_id = token
	elapsed = 0
	starts += 1
	effects_played = false
	_sound_caption.hide()
	_position_camera(_camera, route)
	if route == &"maintenance":
		_apply_workshop_shadows()
		if _workshop_view:
			_resize_workshop_view()
			_previous_disable_3d = get_viewport().disable_3d
			get_viewport().disable_3d = true
			# The fixed exterior is ready before the cut.
			if not _workshop_intro_ready:
				_workshop_view.render_target_update_mode = SubViewport.UPDATE_ONCE
			_workshop_intro_ready = false
			_workshop_layer.show()
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
			_play_effects()
			_sound.play()
			SoundCaptions.cue(self, "k17_sabotage", "Vụ nổ từ khu thiết bị tình báo dự phòng")
	var flash := clampf(1.0 - (elapsed - C.DETONATE_AT) / .35, 0.0, 1.0) if effects_played else 0.0
	if _workshop_layer and _workshop_layer.visible:
		_workshop_glow.modulate.a = .5 * flash
		if elapsed >= C.FINALE_SECONDS - WORKSHOP_RESULTS_LEAD \
				and flow.applied_mouse_mode == Input.MOUSE_MODE_CAPTURED and OS.get_name() == "Windows":
			# Actors are frozen. Prepare the interactive card before changing the game state.
			flow._apply_mouse(Input.MOUSE_MODE_VISIBLE)
			var menus := get_parent().get_parent().get_node_or_null("GameMenus")
			if menus and menus.has_method("prepare_workshop_summary"):
				menus.prepare_workshop_summary()
	else:
		_flash.light_energy = 3.5 * flash
	if elapsed >= C.FINALE_SECONDS: finish()

func _play_effects() -> void:
	var particles: Array[CPUParticles3D] = [_smoke, _sparks, _fire]
	if _workshop_layer and _workshop_layer.visible:
		particles = _workshop_particles
		_workshop_effects.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		_workshop_effect_image.show()
	for particle in particles:
		particle.restart()
		particle.emitting = true

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
	var m := _mission()
	if m: m.complete_finale(run_id)

func tint_workshop_result() -> bool:
	if not _workshop_layer or not _workshop_layer.visible: return false
	# Dim the fixed shot with the existing canvas material in one draw.
	_workshop_backdrop.self_modulate = WORKSHOP_RESULTS_TINT
	return true

func end_shot() -> void:
	active = false
	if _sound: _sound.stop()
	if _smoke: _smoke.emitting = false
	if _sparks: _sparks.emitting = false
	if _fire: _fire.emitting = false
	if _flash: _flash.light_energy = 0
	if _overlay: _overlay.hide()
	if _workshop_layer and _workshop_layer.visible:
		for particle in _workshop_particles: particle.emitting = false
		_workshop_effects.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_workshop_effect_image.hide()

func cancel() -> void:
	end_shot()
	if _workshop_layer and _workshop_layer.visible:
		var flow := GameFlow.find(self)
		if flow and flow.state == GameStateMachine.State.PLAYING and not flow.is_leaving() \
				and flow.applied_mouse_mode == Input.MOUSE_MODE_VISIBLE:
			flow._apply_mouse(Input.MOUSE_MODE_CAPTURED)
	_discard_workshop_view()
	_restore_workshop_shadows()
	for layer in _hidden:
		if is_instance_valid(layer): layer.show()
	_hidden.clear()
	if _camera and _camera.current:
		_camera.clear_current()
		var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
		if player: player.camera.make_current()

func _discard_workshop_view() -> void:
	if _workshop_layer and _workshop_layer.visible:
		_workshop_layer.hide()
		_workshop_backdrop.self_modulate = Color.WHITE
		_workshop_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		get_viewport().disable_3d = _previous_disable_3d

func _exit_tree() -> void:
	_discard_workshop_view()

func _flow_changed(_from: GameStateMachine.State, to: GameStateMachine.State) -> void:
	if _sound: _sound.stream_paused = to == GameStateMachine.State.PAUSED
