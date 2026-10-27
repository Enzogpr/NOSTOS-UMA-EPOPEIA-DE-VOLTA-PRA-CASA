extends "res://Ato4_Tempestade/Cutscenes/LuckRunsOut.gd"
## Stops at the crew's assent and offers the nine-day vigilance.
signal wind_bag_received
signal watch_requested
const FRIENDS_DIRECTOR := preload("res://Ato4_Tempestade/Cutscenes/FriendsStage.gd")
@export_file("*.tscn") var watch_scene_path: String = ""
@export var persist_progress: bool = true
var end_panel: Panel
var ended: bool = false
var exiting: bool = false
var reward_emitted: bool = false

func _dialogue_path() -> String:
	return "res://Ato4_Tempestade/Cutscenes/AeoliaMeeting.dialogue.json"

func _create_director() -> Node2D:
	return FRIENDS_DIRECTOR.new()

func _ready() -> void:
	super._ready()
	standalone_ascent = false
	director.name = "FriendsStage"
	MainHUD.set_station("Ato 4 - A bolsa dos ventos")
	$Stage/TopTitle.text = "ATO IV   /   MANTENHA SEUS AMIGOS POR PERTO"
	# Long collective speaker names need their own space above the dialogue.
	speaker.size.x = 630
	speaker.add_theme_font_size_override("font_size",22)
	speaker_context.position = Vector2(690,7)
	speaker_context.size.x = 300
	speaker_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_end_panel()

func _show_beat(index: int) -> void:
	super._show_beat(index)
	var name_text: String = str(beats[index].speaker)
	var tint := Color(1.0,0.76,0.48)
	if "Éolo" in name_text or name_text == "Winions":
		tint = Color(0.63,0.95,0.90)
	elif "Perímedes" in name_text or "Elpenor" in name_text:
		tint = Color(0.73,0.85,1.0)
	speaker.add_theme_color_override("font_color",tint)
	$Stage/Captions/Accent.color = tint
	speaker_context.text = "CONVÉS · A BOLSA DOS VENTOS" if index >= 20 else "EÓLIA · REINO DOS VENTOS"

func _process(delta: float) -> void:
	if director != null and director.transitioning:
		input_cooldown = maxf(0.0,input_cooldown-delta)
		director.speaking = false
		return
	super._process(delta)

func _advance_requested() -> void:
	if director != null and director.transitioning:
		return
	super._advance_requested()

func _finish() -> void:
	if is_ending:
		return
	is_ending = true
	can_advance = false
	if intro_tween and intro_tween.is_running():
		intro_tween.kill()
	director.prepare_journey()
	ending_tween = create_tween()
	ending_tween.tween_property($Stage/Captions,"modulate:a",0.0,0.5)
	ending_tween.parallel().tween_property($Stage/Controls,"modulate:a",0.0,0.5)
	ending_tween.tween_interval(1.3)
	ending_tween.tween_callback(func():
		ended = true
		end_panel.show()
		end_panel.modulate.a = 0.0
		create_tween().tween_property(end_panel,"modulate:a",1.0,0.45)
		end_panel.get_node("Map").grab_focus()
		if not reward_emitted:
			reward_emitted = true
			if persist_progress: GameManager.unlock_act4_stage(2)
			wind_bag_received.emit()
			conversation_finished.emit()
			cinematic_finished.emit()
	)

func _build_end_panel() -> void:
	end_panel = Panel.new()
	end_panel.position = Vector2(250,470)
	end_panel.size = Vector2(652,158)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.09,0.13,0.97)
	style.border_color = Color(0.72,0.65,0.4)
	style.set_border_width_all(1)
	end_panel.add_theme_stylebox_override("panel",style)
	stage.add_child(end_panel)
	var title := Label.new()
	title.text = "RUMO A ÍTACA"
	title.position = Vector2(24,14)
	title.add_theme_font_size_override("font_size",25)
	title.add_theme_color_override("font_color",Color(0.97,0.85,0.58))
	end_panel.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Ventos favoráveis. Uma promessa: manter a bolsa fechada."
	subtitle.position = Vector2(24,53)
	subtitle.add_theme_font_size_override("font_size",18)
	end_panel.add_child(subtitle)
	for definition in [["Retry","REVER CONVERSA",24],["Map","VOLTAR AO MAPA",337]]:
		var button := Button.new()
		button.name = definition[0]
		button.text = definition[1]
		if definition[0] == "Map" and not watch_scene_path.is_empty():
			button.text = "INICIAR VIAGEM"
		button.position = Vector2(definition[2],99)
		button.size = Vector2(290,40)
		button.add_theme_font_size_override("font_size",17)
		var path: String = "res://Ato4_Tempestade/Cutscenes/AeoliaMeeting.tscn" if definition[0] == "Retry" else "res://Scenes/WorldMap.tscn"
		var starts_watch: bool = definition[0] == "Map" and not watch_scene_path.is_empty()
		if starts_watch:
			path = watch_scene_path
		button.pressed.connect(func():
			if starts_watch:
				watch_requested.emit()
			_leave(path)
		)
		end_panel.add_child(button)
	end_panel.hide()

func _leave(path: String) -> void:
	if exiting:
		return
	exiting = true
	get_tree().change_scene_to_file(path)
