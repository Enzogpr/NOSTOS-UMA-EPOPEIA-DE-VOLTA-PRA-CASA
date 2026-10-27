extends Control
## The crew discovers Aeolia before the player prepares the harpoon.

const STORY := "res://Ato4_Tempestade/Cutscenes/AeoliaApproach.dialogue.json"
const HARPOON := "res://Ato4_Tempestade/Gameplay/AeoliaHarpoon.tscn"
const DISCOVERY := "res://Assets/act4_storm/aeolia_discovery.png"
@onready var cinematic: Control = $CinematicPresenter
var beats: Array = []
var beat_index: int = 0
var handoff_started: bool = false

func _ready() -> void:
	set_meta("hide_main_hud", true)
	set_meta("cinematic_active", true)
	GameManager.combat_mode = false
	MainHUD.set_station("Ato 4 - Uma ilha no céu")
	beats = JSON.parse_string(FileAccess.get_file_as_string(STORY))
	var sources: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/act4_storm/fullbody_actors.json"))
	for key in sources:
		cinematic.library.actors[key] = _portrait(sources[key])
	var directions: Array = []
	for index in beats.size():
		var speaker_name: String = beats[index].speaker
		var discovery: bool = index in [1, 2]
		var focus := "wide"
		if speaker_name == "Odisseu":
			focus = "left"
		elif speaker_name == "Euríloco":
			focus = "right"
		directions.append({
			"background": DISCOVERY if discovery else "res://Assets/cinematics/ship_deck.png",
			"left": "odysseus_storm" if index in [0, 3, 5, 7] else "",
			"right": "eurylochus_storm" if index in [0, 4, 6] else "",
			"left_pose": 2 if index in [3, 5, 7] else 3,
			"right_pose": 1 if index in [0, 4, 6] else 3,
			"focus": "wide" if discovery else focus, "quiet": true,
			"water": 0.0 if discovery else 0.15,
			"context": "EÓLIA · NO CÉU" if discovery else "CONVÉS", "intensity": 0.15
		})
	cinematic.library.sequences["aeolia_approach"] = {"title": "UMA ILHA NO CÉU", "beats": directions}
	cinematic.advance_requested.connect(_advance)
	cinematic.autoplay = false
	cinematic._update_auto_button()
	_present()

func _portrait(source: Dictionary) -> Dictionary:
	# Use the same cropped portraits and gestures already seen in the storm.
	var atlas: Texture2D = load(str(source.texture))
	var cell := Vector2(atlas.get_width() / 2.0, atlas.get_height() / 2.0)
	var poses: Array[Texture2D] = []
	var offsets: Array[Vector2] = []
	for frame in 4:
		var top: float = maxf(0.0, float(source.bounds[frame][1]) - 24.0)
		var pose := AtlasTexture.new()
		pose.atlas = atlas
		pose.region = Rect2(Vector2((frame % 2) * cell.x, (frame / 2) * cell.y + top), Vector2(cell.x, 340))
		pose.filter_clip = true
		poses.append(pose)
		var center: float = float(source.anchors[frame][0])
		if bool(source.flip):
			center = cell.x - center
		offsets.append(Vector2(cell.x * 0.5 - center, 0))
	return {"poses": poses, "pose_offsets": offsets, "height": 380.0, "flip": source.flip}

func _present() -> void:
	cinematic.present(beats[beat_index], "aeolia_approach", beat_index)
	var world: Node2D = cinematic.get_node("Stage/World")
	# Let the cropped portraits end inside the bottom shade, not above it.
	world.get_node("Odysseus").position.y = 58
	world.get_node("Athena").position.y = 30
	if beat_index in [3, 5, 7]:
		world.get_node("Odysseus").position = Vector2(-40, 58)
	elif beat_index in [4, 6]:
		world.get_node("Athena").position = Vector2(40, 30)
	# Cut to a distinct sky view: the island is part of that landscape, never a
	# decal composited over the ship's sail, including during a background fade.
	if cinematic.backdrop_tween and cinematic.backdrop_tween.is_running():
		cinematic.backdrop_tween.kill()
	cinematic.previous_cave.modulate.a = 0.0
	world.get_node("Cave").modulate = Color(0.90, 0.93, 0.98, 1.0)

func _advance() -> void:
	if handoff_started:
		return
	if beat_index + 1 < beats.size():
		beat_index += 1
		_present()
	else:
		handoff_started = true
		cinematic.suspend()
		# Release the final dialogue input before the harpoon's preparation screen.
		var tween := create_tween()
		tween.tween_property(cinematic.black, "color:a", 1.0, 0.45)
		tween.tween_callback(func(): get_tree().change_scene_to_file(HARPOON))
