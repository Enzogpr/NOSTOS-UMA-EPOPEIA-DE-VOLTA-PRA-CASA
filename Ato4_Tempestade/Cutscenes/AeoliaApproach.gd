extends Control
## The crew discovers Aeolia before the player prepares the harpoon.

const STORY := "res://Ato4_Tempestade/Cutscenes/AeoliaApproach.dialogue.json"
const HARPOON := "res://Ato4_Tempestade/Gameplay/AeoliaHarpoon.tscn"
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
		var focus := "wide"
		if speaker_name == "Odisseu":
			focus = "left"
		elif speaker_name == "Euríloco":
			focus = "right"
		directions.append({
			"background": "res://Assets/cinematics/ship_deck.png",
			"left": "odysseus_storm", "right": "eurylochus_storm",
			"left_pose": 2 if index in [3, 5, 7] else 3,
			"right_pose": 1 if index in [0, 4, 6] else 3,
			"focus": focus, "quiet": true, "water": 0.15,
			"context": "CONVÉS · EÓLIA", "intensity": 0.15
		})
	cinematic.library.sequences["aeolia_approach"] = {"title": "UMA ILHA NO CÉU", "beats": directions}
	var island := Sprite2D.new()
	island.name = "SkyIsland"
	island.texture = preload("res://Assets/act4_storm/aeolia_floating.png")
	island.position = Vector2(0, -203)
	island.scale = Vector2.ONE * 0.12
	cinematic.get_node("Stage/World").add_child(island)
	cinematic.get_node("Stage/World").move_child(island, 2)
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
	return {"poses": poses, "pose_offsets": offsets, "height": 520.0, "flip": source.flip}

func _present() -> void:
	cinematic.present(beats[beat_index], "aeolia_approach", beat_index)
	var world: Node2D = cinematic.get_node("Stage/World")
	world.get_node("SkyIsland").visible = beat_index >= 1
	if beats[beat_index].speaker == "Odisseu e Euríloco":
		world.get_node("Odysseus").modulate = Color.WHITE
		world.get_node("Athena").modulate = Color.WHITE
	elif beats[beat_index].speaker == "Perimedes e Elpenor":
		# Their call comes from offscreen; the two officers react to the discovery.
		world.get_node("Odysseus").modulate = Color(0.80, 0.85, 0.91)
		world.get_node("Athena").modulate = Color(0.80, 0.85, 0.91)

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
