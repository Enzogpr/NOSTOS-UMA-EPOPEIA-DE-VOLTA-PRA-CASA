extends "res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewellCutscene.gd"
## The same layered stage as Athena's farewell, with campaign-specific direction.
## Story controllers still own decisions, timers, inventory and scene transitions.

signal advance_requested

const DIRECTIONS := "res://Assets/cinematics/direction.json"
@export var silent_soundtrack: bool = false
var library: Dictionary = {}
var active: bool = false
var pages: Array[Dictionary] = []
var page_index: int = 0
var current_direction: Dictionary = {}
var source_slide: Dictionary = {}
var sequence_key: String = ""
var sequence_index: int = 0
var image_path: String = ""
var camera_target: float = 1.0
var camera_pan := Vector2.ZERO
var image_age: float = 0.0
var backdrop_tween: Tween
var reveal_tween: Tween
var background_material: ShaderMaterial
var previous_cave: Sprite2D
var caption_text: String = ""

func _ready() -> void:
	library = JSON.parse_string(FileAccess.get_file_as_string(DIRECTIONS))
	resized.connect(_fit_stage)
	_fit_stage()
	can_advance = false
	presence = 1.0
	black.color.a = 0.0
	$Stage/Opening.visible = false
	$Stage/Controls/SkipButton.visible = false
	$Stage/Controls/InputHint.text = "ESPAÇO / ENTER / CLIQUE  ·  ESC: PAUSA"
	auto_button.pressed.connect(_toggle_auto)
	next_button.pressed.connect(_advance_requested)
	_update_auto_button()
	previous_cave = Sprite2D.new()
	previous_cave.name = "PreviousBackground"
	previous_cave.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	$Stage/World.add_child(previous_cave)
	$Stage/World.move_child(previous_cave, 0)
	background_material = ShaderMaterial.new()
	background_material.shader = load("res://Assets/cinematics/environment.gdshader")
	$Stage/World/Cave.material = background_material
	if silent_soundtrack:
		previous_music_volume = AudioManager.music_player.volume_db
		music_ducked = true
		AudioManager.music_player.volume_db = -80.0
	else:
		_start_ambience()
	$MindAmbience.stop()
	suspend()

func present(slide: Dictionary, sequence: String, index: int) -> void:
	source_slide = slide.duplicate(true)
	sequence_key = sequence
	sequence_index = index
	var spec: Dictionary = library.sequences[sequence]
	current_direction = spec.beats[index].duplicate(true)
	$Stage/TopTitle.text = str(spec.title)
	$Stage/TopTitle.show()
	$Stage/TopBar.show()
	$Stage/BottomShade.show()
	$Stage/Captions.visible = true
	$Stage/Controls.visible = true
	active = true
	if silent_soundtrack:
		$MindAmbience.stop()
		AudioManager.music_player.volume_db = -80.0
	else:
		$MindAmbience.play()
		if music_ducked:
			AudioManager.music_player.volume_db = previous_music_volume - 14.0
	get_parent().set_meta("cinematic_active", true)
	input_cooldown = 0.22
	image_age = 0.0
	var background: String = str(current_direction.get("background", slide.get("image", "")))
	_set_background(background)
	_apply_actors()
	if reveal_tween and reveal_tween.is_running():
		reveal_tween.kill()
	presence = 1.0
	if current_direction.get("manifest", false):
		presence = 0.0
		reveal_tween = create_tween()
		reveal_tween.tween_property(self, "presence", 1.0, 1.4)
	pages = _make_pages(str(slide.get("text", "")), str(slide.get("speaker", current_direction.get("speaker", "Narrador"))))
	page_index = 0
	_show_page()
	if current_direction.has("impact"):
		shake = float(current_direction.impact)
		_flash(Color(1.0, 0.67, 0.39, 0.08))
	if current_direction.get("burst", false):
		atmosphere.burst()
	background_material.set_shader_parameter("water", float(current_direction.get("water", 0.0)))
	background_material.set_shader_parameter("fire", float(current_direction.get("fire", 0.0)))
	background_material.set_shader_parameter("dream", float(current_direction.get("dream", 0.0)))
	$MindAmbience.volume_db = -19.0 if current_direction.get("quiet", false) else -15.0

func present_silent(sequence: String, index: int = 0) -> void:
	present({}, sequence, index)
	suspend()
	$Stage/TopTitle.hide()
	$Stage/TopBar.hide()
	$Stage/BottomShade.hide()
	if music_ducked:
		AudioManager.music_player.volume_db = previous_music_volume - 20.0

func _process(delta: float) -> void:
	super._process(delta)
	var spectral: bool = current_direction.get("right", "") in ["athena", "deities"]
	$Stage/World/MindLight.visible = spectral
	atmosphere.presence = presence if spectral else 0.0
	if not visible:
		return
	image_age += delta
	var drift: float = minf(image_age / 20.0, 1.0)
	camera_zoom = lerpf(camera_zoom, camera_target + drift * 0.018, minf(delta * 1.8, 1.0))
	camera_offset = camera_offset.lerp(camera_pan + Vector2(sin(elapsed * 0.15) * 2.0, 0), minf(delta * 1.7, 1.0))
	if current_direction.get("water", 0.0) > 0.0:
		$Stage/World/Cave.position.y = sin(elapsed * 0.9) * 1.5
	else:
		$Stage/World/Cave.position.y = 0.0
	if not active:
		return
	type_elapsed += delta * playback_speed
	var count: int = dialogue.get_total_character_count()
	dialogue.visible_characters = mini(int(type_elapsed * characters_per_second), count)
	if dialogue.visible_characters >= count:
		next_button.text = "CONTINUAR  ›"
		hold_elapsed += delta * playback_speed
		var pause: float = float(current_direction.get("hold", 1.2)) + float(count) / 70.0
		if autoplay and hold_elapsed >= pause:
			_advance_requested()
	else:
		next_button.text = "MOSTRAR FALA  ›"

func _set_background(path: String) -> void:
	if path == image_path:
		return
	image_path = path
	var cave := $Stage/World/Cave as Sprite2D
	var texture := resolve_texture(path)
	if texture == null:
		push_error("Imagem ausente na narrativa: " + path)
		cave.texture = null
		return
	if backdrop_tween and backdrop_tween.is_running():
		backdrop_tween.kill()
	previous_cave.texture = cave.texture
	previous_cave.scale = cave.scale
	previous_cave.modulate = cave.modulate
	previous_cave.position = cave.position
	cave.texture = texture
	# Wide images cover the stage. Portrait compositions fit without losing action.
	var ratio: float = float(texture.get_width()) / float(texture.get_height())
	var factor: float = maxf(DESIGN_SIZE.x / texture.get_width(), DESIGN_SIZE.y / texture.get_height()) if ratio > 1.4 else DESIGN_SIZE.y / texture.get_height()
	cave.scale = Vector2.ONE * factor
	cave.modulate = Color(0.84, 0.87, 0.94, 0.0)
	backdrop_tween = create_tween().set_parallel(true)
	backdrop_tween.tween_property(previous_cave, "modulate:a", 0.0, 0.55)
	backdrop_tween.tween_property(cave, "modulate:a", 1.0, 0.55)

func resolve_texture(path: String) -> Texture2D:
	var stem: String = path.get_basename() if not path.get_extension().is_empty() else path
	for candidate in [path, stem + ".png", stem + ".jpg", stem + ".jpeg", stem + ".webp"]:
		if ResourceLoader.exists(candidate):
			return load(candidate) as Texture2D
	return null

func _apply_actors() -> void:
	_set_actor(odysseus, str(current_direction.get("left", "")), int(current_direction.get("left_pose", 0)))
	_set_actor(athena, str(current_direction.get("right", "")), int(current_direction.get("right_pose", 0)))
	odysseus_offset = Vector2.ZERO
	athena_offset = Vector2.ZERO
	var giant: bool = str(current_direction.get("right", "")).begins_with("polyphemus")
	$Stage/World/Athena.position = Vector2(292, -44 if giant else -18)
	$Stage/World/Odysseus.position = Vector2(-292, 10)
	agitation = float(current_direction.get("intensity", 0.2))

func _set_actor(actor: Node2D, key: String, frame: int) -> void:
	actor.get_parent().visible = not key.is_empty()
	if key.is_empty():
		return
	var definition: Dictionary = library.actors[key]
	if definition.has("poses"):
		_set_portrait_pose(actor, definition, frame)
		return
	var portrait := actor.get_node("Portrait") as Sprite2D
	var old := actor.get_node("PreviousPose") as Sprite2D
	var texture := resolve_texture(str(definition.texture))
	var atlas_changed: bool = portrait.texture != texture
	if atlas_changed and pose_tweens.has(actor) and pose_tweens[actor].is_running():
		pose_tweens[actor].kill()
	for sprite in [portrait, old]:
		if atlas_changed:
			sprite.frame = 0
		sprite.texture = texture
		sprite.hframes = int(definition.get("columns", 2))
		sprite.vframes = int(definition.get("rows", 2))
		sprite.flip_h = bool(definition.get("flip", false))
		if definition.has("height"):
			sprite.scale = Vector2.ONE * float(definition.height) / (float(texture.get_height()) / sprite.vframes)
		else:
			var width: float = float(definition.get("width", 520.0))
			sprite.scale = Vector2.ONE * width / (float(texture.get_width()) / sprite.hframes)
		var material := sprite.material as ShaderMaterial
		material.set_shader_parameter("spectral", float(definition.get("spectral", 0.0)))
		material.set_shader_parameter("presence", 1.0)
		material.set_shader_parameter("atlas_grid", Vector2(sprite.hframes, sprite.vframes))
	if atlas_changed:
		portrait.frame = frame
		portrait.modulate.a = 1.0
		old.modulate.a = 0.0
	else:
		_change_pose(actor, frame)
	# Full-body sheets keep their feet planted even when gesture margins differ.
	# Apply to both sprites so a pose crossfade doesn't move the previous feet.
	for sprite in [portrait, old]:
		sprite.offset = Vector2.ZERO
		if definition.has("anchors"):
			var anchor: Array = definition.anchors[sprite.frame]
			var cell_size := Vector2(float(texture.get_width()) / sprite.hframes, float(texture.get_height()) / sprite.vframes)
			var foot := Vector2(float(anchor[0]), float(anchor[1]))
			if sprite.flip_h:
				foot.x = cell_size.x - foot.x
			sprite.offset = cell_size * 0.5 - foot

func _set_portrait_pose(actor: Node2D, definition: Dictionary, frame: int) -> void:
	var portrait := actor.get_node("Portrait") as Sprite2D
	var old := actor.get_node("PreviousPose") as Sprite2D
	var texture: Texture2D = definition.poses[frame]
	if portrait.texture == texture:
		return
	if pose_tweens.has(actor) and pose_tweens[actor].is_running():
		pose_tweens[actor].kill()
	old.frame = 0
	old.hframes = portrait.hframes
	old.vframes = portrait.vframes
	old.texture = portrait.texture
	old.frame = portrait.frame
	old.scale = portrait.scale
	old.offset = portrait.offset
	old.flip_h = portrait.flip_h
	old.modulate.a = portrait.modulate.a if portrait.hframes == 1 else 0.0
	portrait.frame = 0
	portrait.hframes = 1
	portrait.vframes = 1
	portrait.texture = texture
	portrait.flip_h = bool(definition.get("flip", false))
	portrait.scale = Vector2.ONE * float(definition.get("height", 520.0)) / texture.get_height()
	portrait.offset = definition.pose_offsets[frame]
	for sprite in [portrait, old]:
		var material := sprite.material as ShaderMaterial
		material.set_shader_parameter("atlas_grid", Vector2.ONE)
		material.set_shader_parameter("spectral", 0.0)
		material.set_shader_parameter("presence", 1.0)
	portrait.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(old, "modulate:a", 0.0, 0.22)
	tween.tween_property(portrait, "modulate:a", 1.0, 0.22)
	pose_tweens[actor] = tween

func _show_page() -> void:
	var page: Dictionary = pages[page_index]
	dialogue.text = str(page.text)
	caption_text = dialogue.text
	dialogue.visible_characters = 0
	type_elapsed = 0.0
	hold_elapsed = 0.0
	input_cooldown = 0.18
	var name: String = str(page.speaker)
	speaker.text = name.to_upper()
	var left_speaks: bool = name.begins_with("Odisseu")
	var narration: bool = name == "Narrador" or name == "Narração"
	var tint := Color(0.76, 0.85, 1.0) if not left_speaks else Color(1.0, 0.73, 0.43)
	if narration:
		tint = Color(0.87, 0.84, 0.76)
	speaker.add_theme_color_override("font_color", tint)
	$Stage/Captions/Accent.color = tint
	speaker_context.text = str(current_direction.get("context", ""))
	if pages.size() > 1:
		speaker_context.text += "   %d / %d" % [page_index + 1, pages.size()]
	speaker_context.position.x = maxf(220.0, speaker.get_minimum_size().x + 35.0)
	speaker.size.x = speaker.get_minimum_size().x
	var focus: String = str(current_direction.get("focus", "wide"))
	if str(source_slide.get("speaker", "")).contains("&"):
		focus = "left" if left_speaks else "right"
	camera_target = 1.0 if focus == "wide" else 1.07
	camera_pan = Vector2(30, 13) if focus == "left" else Vector2(-30, 13) if focus == "right" else Vector2.ZERO
	if current_direction.has("pan"):
		camera_pan += Vector2(current_direction.pan[0], current_direction.pan[1])
	$Stage/World/Odysseus.modulate = Color.WHITE if left_speaks or narration else Color(0.75, 0.78, 0.85)
	$Stage/World/Athena.modulate = Color.WHITE if not left_speaks else Color(0.78, 0.83, 0.92)
	if current_direction.get("right", "") == "deities":
		$Stage/World/Athena.modulate.a = 0.70

func _make_pages(text: String, default_speaker: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var font: Font = dialogue.get_theme_font("normal_font")
	var font_size: int = dialogue.get_theme_font_size("normal_font_size")
	# Two measured lines fit the caption area. No sentence or word is discarded.
	for paragraph in text.split("\n\n", false):
		var name: String = default_speaker
		var body: String = paragraph
		if body.begins_with("(Odisseu "):
			name = "Narrador"
		for prefix in ["Euríloco", "Odisseu", "Ancião dos Lotófagos"]:
			if body.begins_with(prefix + ": "):
				name = prefix
				body = body.substr(prefix.length() + 2)
		var buffer := ""
		var line := ""
		var line_count := 1
		for word in body.split(" ", false):
			var candidate: String = word if line.is_empty() else line + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > dialogue.size.x - 10.0:
				line_count += 1
				line = word
			else:
				line = candidate
			if line_count > 2 and not buffer.is_empty():
				result.append({"speaker": name, "text": buffer})
				buffer = word
				line = word
				line_count = 1
			else:
				buffer += (" " if not buffer.is_empty() else "") + word
		if not buffer.is_empty():
			result.append({"speaker": name, "text": buffer})
	if result.is_empty():
		result.append({"speaker": default_speaker, "text": text})
	return result

func _advance_requested() -> void:
	if not active or input_cooldown > 0.0:
		return
	input_cooldown = 0.20
	if dialogue.visible_characters < dialogue.get_total_character_count():
		type_elapsed = float(dialogue.get_total_character_count()) / characters_per_second + 0.01
		dialogue.visible_characters = dialogue.get_total_character_count()
		hold_elapsed = 0.0
	elif page_index + 1 < pages.size():
		page_index += 1
		_show_page()
	else:
		active = false
		advance_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event.is_pressed() or event.is_echo():
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	if event is InputEventKey and event.keycode == KEY_A:
		viewport.set_input_as_handled()
		_toggle_auto()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or event is InputEventScreenTouch:
		# Advancing can synchronously remove this scene from its viewport.
		viewport.set_input_as_handled()
		_advance_requested()

func suspend(keep_captions: bool = false) -> void:
	active = false
	$MindAmbience.stop()
	if music_ducked:
		AudioManager.music_player.volume_db = previous_music_volume
	$Stage/Captions.visible = keep_captions
	$Stage/Controls.visible = false
	get_parent().set_meta("cinematic_active", false)

func fade_out(duration: float = 0.6) -> Tween:
	suspend()
	var tween := create_tween()
	tween.tween_property(black, "color:a", 1.0, duration)
	return tween

func transition_to(path: String) -> void:
	if is_ending:
		return
	is_ending = true
	await fade_out().finished
	get_tree().change_scene_to_file(path)

func _finish() -> void:
	# The campaign owner decides whether the next step is a choice or a minigame.
	_advance_requested()
