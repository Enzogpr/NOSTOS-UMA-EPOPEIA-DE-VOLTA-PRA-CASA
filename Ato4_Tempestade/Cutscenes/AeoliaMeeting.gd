extends Control
## A short original introduction, separate from the musical's lyrics/script.

@onready var cinematic: Control = $CinematicPresenter
var beats: Array = []
var beat_index: int = 0
var ended: bool = false
var exiting: bool = false
var end_panel: Panel

func _ready() -> void:
	set_meta("hide_main_hud", true)
	set_meta("cinematic_active", true)
	GameManager.combat_mode = false
	beats = JSON.parse_string(FileAccess.get_file_as_string("res://Ato4_Tempestade/Cutscenes/AeoliaMeeting.dialogue.json"))
	var odysseus := AtlasTexture.new()
	odysseus.atlas = preload("res://Assets/act4_storm/odysseus_fullbody.png")
	odysseus.region = Rect2(0, 45, 640, 340)
	odysseus.filter_clip = true
	cinematic.library.actors["odysseus_aeolia"] = {"poses": [odysseus], "pose_offsets": [Vector2(-29, 0)], "height": 520.0, "flip": false}
	var aeolus := AtlasTexture.new()
	aeolus.atlas = load("res://Assets/act4_storm/aeolus_fullbody.png")
	aeolus.region = Rect2(170, 0, 1080, 650)
	aeolus.filter_clip = true
	cinematic.library.actors["aeolus"] = {"poses": [aeolus], "pose_offsets": [Vector2(-160, 0)], "height": 520.0, "flip": true}
	var directions: Array = []
	for beat in beats:
		directions.append({"background": "res://Assets/act4_storm/aeolia_floating.png", "left": "odysseus_aeolia", "right": "aeolus", "left_pose": 0, "right_pose": 0, "focus": "left" if beat.speaker == "Odisseu" else "right", "quiet": true, "context": "EÓLIA · O REINO DOS VENTOS", "intensity": 0.10})
	cinematic.library.sequences["aeolia_meeting"] = {"title": "O ENCONTRO COM ÉOLO", "beats": directions}
	cinematic.advance_requested.connect(_advance)
	cinematic.autoplay = false
	cinematic._update_auto_button()
	_build_end_panel()
	_present()

func _present() -> void:
	cinematic.present(beats[beat_index], "aeolia_meeting", beat_index)

func _advance() -> void:
	if ended:
		return
	if beat_index + 1 < beats.size():
		beat_index += 1
		_present()
	else:
		ended = true
		cinematic.suspend()
		end_panel.show()
		end_panel.get_node("Map").grab_focus()

func _build_end_panel() -> void:
	end_panel = Panel.new()
	end_panel.position = Vector2(250, 472)
	end_panel.size = Vector2(652, 156)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.09, 0.13, 0.97)
	style.border_color = Color(0.72, 0.65, 0.4)
	style.set_border_width_all(1)
	end_panel.add_theme_stylebox_override("panel", style)
	cinematic.get_node("Stage").add_child(end_panel)
	var title := Label.new()
	title.text = "ODISSEU ALCANÇOU EÓLIA"
	title.position = Vector2(24, 15)
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color(0.97, 0.85, 0.58))
	end_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "A corda abriu o caminho até o reino de Éolo."
	subtitle.position = Vector2(24, 52)
	subtitle.add_theme_font_size_override("font_size", 18)
	end_panel.add_child(subtitle)
	for definition in [["Retry", "REPETIR MINIGAME", 24], ["Map", "VOLTAR AO MAPA", 337]]:
		var button := Button.new()
		button.name = definition[0]
		button.text = definition[1]
		button.position = Vector2(definition[2], 98)
		button.size = Vector2(290, 40)
		button.add_theme_font_size_override("font_size", 17)
		var path: String = "res://Ato4_Tempestade/Gameplay/AeoliaHarpoon.tscn" if definition[0] == "Retry" else "res://Scenes/WorldMap.tscn"
		button.pressed.connect(func(): _leave(path))
		end_panel.add_child(button)
	end_panel.hide()

func _leave(path: String) -> void:
	if exiting:
		return
	exiting = true
	get_tree().change_scene_to_file(path)
