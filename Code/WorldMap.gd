extends Control
const DESIGN := Vector2(1152,648)
const DATA := preload("res://Code/JourneyMapData.gd")
@onready var chart: Node2D = $Chart
@onready var player: Node2D = $Chart/MapPlayer
@onready var info_label: Label = $Chart/UI/InfoLabel
@onready var status_label: Label = $Chart/UI/StatusLabel
@onready var enter_button: Button = $Chart/UI/EnterButton
@onready var progress_label: Label = $Chart/UI/ProgressLabel
var stops: Array[MapNode] = []
var node_buttons: Array[Button] = []
var node_labels: Array[Label] = []
var chapter_buttons: Array[Button] = []

func _ready() -> void:
	set_meta("hide_main_hud",true)
	for index in DATA.DESTINATIONS.size():
		var stop := MapNode.new()
		stop.name = DATA.DESTINATIONS[index].id
		stop.configure(DATA.DESTINATIONS[index],index)
		$Chart/Nodes.add_child(stop)
		stops.append(stop)
		_build_marker(stop)
	for index in stops.size():
		stops[index].previous = stops[index-1] if index > 0 else null
		stops[index].following = stops[index+1] if index+1 < stops.size() else null
	$Chart/Paths.stops = stops
	player.arrived_at_node.connect(_on_player_arrived)
	player.entry_requested.connect(_on_entry_requested)
	enter_button.pressed.connect(player.enter_current)
	GameManager.act4_progress_changed.connect(_refresh_map)
	GameManager.journey_time_changed.connect(_refresh_time)
	GameManager.player_stats_changed.connect(_refresh_time)
	resized.connect(_fit_chart)
	_fit_chart()
	_refresh_map()
	var latest: MapNode = stops[0]
	for stop in stops:
		if stop.latest_unlocked_order() > latest.latest_unlocked_order(): latest = stop
	player.snap_to(latest)

func destination(id: String) -> MapNode:
	for stop in stops:
		if stop.destination_id == id: return stop
	return null

func _fit_chart() -> void:
	if not is_instance_valid(chart): return
	var factor := minf(size.x/DESIGN.x,size.y/DESIGN.y)
	chart.scale = Vector2.ONE*factor
	chart.position = (size-DESIGN*factor)*0.5

func _build_marker(stop: MapNode) -> void:
	var button := Button.new()
	button.position = Vector2(-75,-25)
	button.size = Vector2(150,66)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.pressed.connect(func(): player.request_travel(stop))
	stop.add_child(button)
	node_buttons.append(button)
	var label := Label.new()
	label.position = Vector2(-95,17)
	label.size = Vector2(190,26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_shadow_color",Color("03111d"))
	label.add_theme_constant_override("shadow_outline_size",7)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stop.add_child(label)
	node_labels.append(label)

func _refresh_map() -> void:
	if stops.is_empty(): return
	var completed := 0
	for index in stops.size():
		var stop := stops[index]
		if stop.is_completed(): completed += 1
		if stop.selected_chapter().is_empty():
			stop.select_chapter(stop.recommended_chapter().get("id",""))
		node_buttons[index].disabled = not stop.is_unlocked()
		node_buttons[index].tooltip_text = stop.real_name+" · "+stop.get_status_text()
		node_labels[index].text = stop.real_name
		node_labels[index].modulate = Color("f4e7c9") if stop.is_unlocked() else Color("87999e")
		stop.queue_redraw()
	progress_label.text = "%d / %d DESTINOS CONCLUÍDOS" % [completed,stops.size()]
	$Chart/Paths.queue_redraw()
	_refresh_time()
	if is_instance_valid(player.current_node): _on_player_arrived(player.current_node)

func _refresh_time() -> void:
	$Chart/UI/TimeLabel.text = "RETORNO: %s  ·  IDADE: %d" % [GameManager.story_time_text(),GameManager.player_age]
	$Chart/UI/TimeLabel.tooltip_text = "Tempo desde a saída de Troia. Anos sacrificados: %d." % GameManager.sacrificed_years

func _on_player_arrived(stop: MapNode) -> void:
	stop.select_chapter(stop.recommended_chapter().get("id",""))
	$Chart/UI/DestinationTitle.text = stop.real_name
	$Chart/UI/DestinationSubtitle.text = stop.subtitle.to_upper()
	$Chart/UI/DestinationDescription.text = stop.description
	$Chart/UI/ChapterCount.text = "%d / %d ETAPAS CONCLUÍDAS" % [stop.completed_chapters(),stop.chapters.size()]
	_build_chapters(stop)
	_update_selection(stop)
	for marker in stops:
		marker.selected = marker == stop
		marker.queue_redraw()

func _build_chapters(stop: MapNode) -> void:
	for button in chapter_buttons:
		button.get_parent().remove_child(button)
		button.queue_free()
	chapter_buttons.clear()
	for index in stop.chapters.size():
		var entry: Dictionary = stop.chapters[index]
		var button := Button.new()
		button.position = Vector2(876,277+index*62)
		button.size = Vector2(234,54)
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size",14)
		button.add_theme_color_override("font_color",Color("dde9e5"))
		button.add_theme_color_override("font_disabled_color",Color("7d9298"))
		var state := "CONCLUÍDA" if DATA.chapter_completed(entry) else "DISPONÍVEL" if DATA.chapter_unlocked(entry) else "BLOQUEADA"
		button.text = "%d  %s\n     %s" % [index+1,entry.name,state]
		button.disabled = not DATA.chapter_unlocked(entry)
		button.pressed.connect(func(): select_chapter(String(entry.id)))
		$Chart/UI.add_child(button)
		chapter_buttons.append(button)

func select_chapter(id: String) -> bool:
	if player.is_moving or not is_instance_valid(player.current_node): return false
	var stop: MapNode = player.current_node
	if not stop.select_chapter(id): return false
	_update_selection(stop)
	return true

func _update_selection(stop: MapNode) -> void:
	var entry := stop.selected_chapter()
	if entry.is_empty():
		info_label.text = stop.real_name
		status_label.text = "Destino ainda bloqueado"
		enter_button.disabled = true
		return
	info_label.text = String(entry.name)
	var act: String = ["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII"][clampi(int(entry.act)-1,0,12)]
	status_label.text = stop.real_name+"  ·  Ato "+act
	enter_button.text = "REJOGAR  ›" if DATA.chapter_completed(entry) else "CONTINUAR  ›"
	enter_button.disabled = not DATA.chapter_unlocked(entry)
	for index in chapter_buttons.size():
		var active: bool = stop.chapters[index].id == entry.id
		var box := StyleBoxFlat.new()
		box.bg_color = Color("183743") if active else Color("0d242f")
		box.border_color = Color("d6b875") if active else Color("294754")
		box.set_border_width_all(1)
		box.set_corner_radius_all(4)
		box.content_margin_left = 10
		for state in ["normal","hover","pressed","disabled"]:
			chapter_buttons[index].add_theme_stylebox_override(state,box)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if not is_instance_valid(player.current_node): return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	var index := key-KEY_1
	if index >= 0 and index < player.current_node.chapters.size():
		select_chapter(player.current_node.chapters[index].id)
		get_viewport().set_input_as_handled()

func _on_entry_requested(path: String) -> void:
	get_tree().change_scene_to_file(path)
