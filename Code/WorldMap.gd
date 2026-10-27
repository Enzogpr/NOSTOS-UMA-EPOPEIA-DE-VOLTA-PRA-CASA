extends Control
const DESIGN:=Vector2(1152,648)
@onready var chart: Node2D=$Chart
@onready var player: Node2D=$Chart/MapPlayer
@onready var info_label: Label=$Chart/UI/InfoLabel
@onready var status_label: Label=$Chart/UI/StatusLabel
@onready var enter_button: Button=$Chart/UI/EnterButton
@onready var progress_label: Label=$Chart/UI/ProgressLabel
var stops: Array[MapNode]=[]
var node_buttons: Array[Button]=[]
var node_labels: Array[Label]=[]

func _ready() -> void:
	set_meta("hide_main_hud",true)
	for stop in $Chart/Nodes.get_children():
		stops.append(stop)
		_build_marker(stop)
	player.arrived_at_node.connect(_on_player_arrived)
	player.entry_requested.connect(_on_entry_requested)
	enter_button.pressed.connect(player.enter_current)
	GameManager.act4_progress_changed.connect(_refresh_map)
	resized.connect(_fit_chart)
	_fit_chart()
	_refresh_map()
	var latest: MapNode=stops[0]
	for stop in stops:
		if stop.is_unlocked(): latest=stop
	player.snap_to(latest)

func _fit_chart() -> void:
	if not is_instance_valid(chart): return
	var factor: float=minf(size.x/DESIGN.x,size.y/DESIGN.y)
	chart.scale=Vector2.ONE*factor
	chart.position=(size-DESIGN*factor)*0.5

func _build_marker(stop: MapNode) -> void:
	var button:=Button.new()
	button.position=Vector2(-25,-25)
	button.size=Vector2(50,50)
	button.focus_mode=Control.FOCUS_NONE
	for state in ["normal","hover","pressed","focus","disabled"]:
		button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.pressed.connect(func(): player.request_travel(stop))
	stop.add_child(button)
	node_buttons.append(button)
	var label:=Label.new()
	label.position=Vector2(-96,26)
	label.size=Vector2(192,24)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_outline_size",6)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	stop.add_child(label)
	node_labels.append(label)

func _refresh_map() -> void:
	if stops.is_empty(): return
	var completed:=0
	for i in stops.size():
		var stop: MapNode=stops[i]
		if stop.is_completed(): completed+=1
		node_buttons[i].disabled=not stop.is_unlocked()
		node_buttons[i].tooltip_text=stop.get_display_name()+" · "+stop.get_status_text()
		node_labels[i].text=(stop.short_name if not stop.short_name.is_empty() else stop.real_name) if stop.is_unlocked() else "???"
		node_labels[i].modulate=Color.WHITE if stop.is_unlocked() else Color(0.65,0.69,0.7)
		stop.queue_redraw()
		if i>0:
			var path: Line2D=$Chart/Paths.get_child(i-1)
			path.default_color=Color(0.90,0.74,0.38,0.9) if stop.is_unlocked() else Color(0.27,0.34,0.37,0.65)
	progress_label.text="%d / %d ETAPAS CONCLUÍDAS" % [completed,stops.size()]
	if is_instance_valid(player.current_node): _on_player_arrived(player.current_node)

func _on_player_arrived(stop: MapNode) -> void:
	info_label.text=stop.get_display_name()
	status_label.text=stop.get_status_text()+"  ·  "+("Ato IV" if stop.level_id==4 else "Ato %s" % ["I","II","III"][clampi(stop.level_id-1,0,2)])
	enter_button.text="REJOGAR  ›" if stop.is_completed() else "INICIAR  ›"
	enter_button.disabled=not stop.is_unlocked()
	for marker in stops:
		marker.selected=marker==stop
		marker.queue_redraw()

func _on_entry_requested(path: String) -> void:
	get_tree().change_scene_to_file(path)
