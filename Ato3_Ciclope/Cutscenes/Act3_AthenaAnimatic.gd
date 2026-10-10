extends Node2D
## Shot staging for the user-supplied animatic. Dialogue and input stay in the
## existing scene; no reference video frames or audio are used by the game.

const REGIONS := "res://Assets/act3_athena_farewell/animatic_regions.json"
const SHADER := preload("res://Assets/act3_athena_farewell/animatic_presence.gdshader")
const SHOTS := [
	"wide", "wide", "athena_foreground", "athena_foreground", "odysseus_close",
	"athena_close", "divine", "athena_close", "reprimand", "athena_departure",
	"odysseus_close", "odysseus_close", "odysseus_grief", "odysseus_heart",
	"odysseus_pleading", "odysseus_close", "athena_shoulder", "athena_shoulder",
	"athena_shoulder", "odysseus_close", "athena_close", "two_medium",
	"reprimand", "confrontation", "confrontation", "defiance", "odysseus_close",
	"athena_hurt", "athena_hurt", "athena_close", "athena_memories",
	"athena_departure", "odysseus_memories", "farewell"
]

var odysseus: Sprite2D
var athena: Sprite2D
var echoes: Array[Sprite2D] = []
var assets: Dictionary = {}
var presence: float = 0.0
var agitation: float = 0.0
var elapsed: float = 0.0
var shot_elapsed: float = 0.0
var current_shot: String = "wide"
var current_index: int = 0
var ending: bool = false
var homes: Dictionary = {}
var heights: Dictionary = {}

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGIONS))
	if not parsed is Dictionary:
		push_error("Não foi possível carregar o enquadramento do animatic.")
		return
	assets = parsed
	for i in 6:
		var echo := _actor("Memory%d" % i, false)
		echo.z_index = 0
		echo.modulate = Color(0.30, 0.55, 0.67, 0.0)
		echoes.append(echo)
	odysseus = _actor("Odysseus", false)
	athena = _actor("Athena", true)

func _actor(actor_name: String, spectral: bool) -> Sprite2D:
	var actor := Sprite2D.new()
	actor.name = actor_name
	actor.region_enabled = true
	actor.region_filter_clip_enabled = true
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("spectral", 1.0 if spectral else 0.0)
	actor.material = material
	add_child(actor)
	return actor

func _pose(actor: Sprite2D, asset: String, frame: int, height: float, foot: Vector2, flip: bool = false, depth: int = 0) -> void:
	var source: Dictionary = assets[asset]
	var rect: Array = source.regions[frame]
	actor.texture = load(str(source.texture))
	actor.region_rect = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
	actor.offset = Vector2(0, -float(rect[3]) * 0.5)
	actor.scale = Vector2.ONE * (height / float(rect[3]))
	actor.position = foot
	actor.flip_h = flip
	# Keep every shot below the later caption siblings in the Stage canvas.
	actor.z_index = 0
	if depth > 0:
		move_child(actor, get_child_count() - 1)
	actor.rotation = 0.0
	actor.modulate = Color.WHITE
	actor.show()
	homes[actor] = foot
	heights[actor] = actor.scale.x

func _body(actor: Sprite2D, frame: int, height: float, at: Vector2, flip: bool = false, depth: int = 0) -> void:
	_pose(actor, "athena_animatic" if actor == athena else "odysseus_animatic", frame, height, at, flip, depth)

func _bust(actor: Sprite2D, frame: int, height: float, at: Vector2, flip: bool = false, depth: int = 0) -> void:
	_pose(actor, "athena_expressions" if actor == athena else "odysseus_expressions", frame, height, at, flip, depth)

func present(index: int, beat: Dictionary) -> void:
	current_index = index
	current_shot = SHOTS[index]
	shot_elapsed = 0.0
	ending = false
	homes.clear()
	heights.clear()
	odysseus.hide()
	athena.hide()
	for echo in echoes:
		echo.hide()
	var pose: int = int(beat.pose)
	var reaction: int = int(beat.get("reaction", 0))
	var athena_speaking: bool = beat.speaker == "Atena"
	var athena_pose: int = pose if athena_speaking else reaction
	var odysseus_pose: int = reaction if athena_speaking else pose
	match current_shot:
		"wide":
			_body(odysseus, 0, 272, Vector2(332, 475))
			_body(athena, 0, 416, Vector2(778, 475))
		"athena_foreground":
			_body(odysseus, 0, 285, Vector2(420, 479))
			_bust(athena, athena_pose, 920, Vector2(1106, 758), false, 2)
		"athena_close", "athena_hurt", "athena_memories":
			_bust(athena, athena_pose, 594, Vector2(615, 628))
			if current_shot == "athena_memories":
				_memories()
		"odysseus_close", "odysseus_grief", "odysseus_memories":
			_bust(odysseus, odysseus_pose, 548, Vector2(566, 625))
			if current_shot == "odysseus_memories":
				_memories()
		"odysseus_heart", "odysseus_pleading":
			_body(odysseus, 2, 650, Vector2(574, 754))
		"divine":
			_body(odysseus, 0, 318, Vector2(391, 495))
			_body(athena, 0, 475, Vector2(797, 495))
		"reprimand":
			_body(odysseus, 0, 296, Vector2(363, 498))
			_body(athena, 1, 481, Vector2(786, 498))
		"athena_shoulder":
			_body(odysseus, 1 if index == 17 else 0, 426, Vector2(399, 555))
			_body(athena, 3, 1050, Vector2(998, 1034), true, 2)
		"two_medium":
			_body(odysseus, 3, 380, Vector2(405, 583), true)
			_body(athena, 0, 536, Vector2(801, 583))
		"confrontation":
			_body(athena, 1, 1030, Vector2(400, 1060), true)
			_bust(odysseus, odysseus_pose, 450, Vector2(816, 675), true, 1)
		"defiance":
			_body(odysseus, 1, 363, Vector2(717, 500), true)
			_body(athena, 2, 468, Vector2(345, 500), true)
		"athena_departure":
			_body(athena, 2, 552, Vector2(647, 569))
		"farewell":
			_body(odysseus, 0, 267, Vector2(364, 473))
			_body(athena, 2, 417, Vector2(776, 473))
	queue_redraw()

func _memories() -> void:
	for i in echoes.size():
		var echo := echoes[i]
		_pose(echo, "odysseus_animatic", i % 3, 322 + (i % 2) * 28, Vector2(130 + i * 176, 469), i % 2 == 0)
		echo.modulate = Color(0.35, 0.58, 0.69, 0.10)

func begin_departure() -> void:
	present(33, {"speaker": "Atena", "pose": 3, "reaction": 0})
	ending = true
	shot_elapsed = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	shot_elapsed += delta
	var push: float = minf(shot_elapsed / 7.0, 1.0) * 0.025
	var entrance: float = 1.0 - smoothstep(0.0, 0.55, shot_elapsed)
	for actor in [odysseus, athena]:
		if actor == null or not actor.visible or not homes.has(actor):
			continue
		var home: Vector2 = homes[actor]
		var motion := Vector2(0, sin(elapsed * (1.2 if actor == athena else 1.8)) * (1.6 if actor == athena else 0.8))
		if current_shot in ["reprimand", "confrontation", "defiance"]:
			motion.x += entrance * (-18.0 if actor == odysseus else 23.0)
		if ending:
			var travel: float = smoothstep(0.0, 1.0, minf(shot_elapsed / 3.5, 1.0))
			motion += Vector2(320, -28) * travel if actor == athena else Vector2(212, 0) * travel
			push = -0.09 * travel
		actor.position = home + motion
		actor.scale = Vector2.ONE * float(heights[actor]) * (1.0 + push)
		var material := actor.material as ShaderMaterial
		material.set_shader_parameter("presence", presence if actor == athena else 1.0)
		material.set_shader_parameter("elapsed", elapsed)
		material.set_shader_parameter("flutter", agitation)
	for echo in echoes:
		if echo.visible:
			echo.modulate.a = minf(shot_elapsed / 0.8, 1.0) * 0.12
	queue_redraw()

func _draw() -> void:
	# The reference uses an empty mental stage. Here it has a subdued blue palette.
	for strip in 81:
		var ratio: float = strip / 80.0
		draw_rect(Rect2(0, strip * 8, 1152, 8), Color(0.095, 0.15, 0.22).lerp(Color(0.22, 0.30, 0.34), ratio))
	draw_rect(Rect2(0, 374, 1152, 274), Color(0.045, 0.10, 0.14, 0.42))
	for i in 14:
		var x: float = 576 + (i - 6.5) * 140
		draw_line(Vector2(576 + (x - 576) * 0.16, 374), Vector2(x, 648), Color(0.41, 0.54, 0.61, 0.09), 1)
	for i in 8:
		var y: float = 374 + pow(i / 7.0, 2.0) * 274
		draw_line(Vector2(0, y), Vector2(1152, y), Color(0.41, 0.54, 0.61, 0.09), 1)
	for actor in [odysseus, athena]:
		if actor != null and actor.visible and homes.has(actor) and Vector2(homes[actor]).y < 560:
			var foot: Vector2 = actor.position
			draw_set_transform(foot + Vector2(0, 3), 0, Vector2(2.8, 0.35))
			draw_circle(Vector2.ZERO, 23, Color(0.01, 0.025, 0.04, 0.20 * (presence if actor == athena else 1.0)))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	for i in 32:
		var point := Vector2(fposmod(i * 79 + sin(elapsed * 0.3 + i) * 5, 1152), fposmod(i * 67 - elapsed * 5, 452))
		draw_rect(Rect2(point, Vector2(2, 2)), Color(0.63, 0.76, 0.87, 0.07 + presence * 0.08))
