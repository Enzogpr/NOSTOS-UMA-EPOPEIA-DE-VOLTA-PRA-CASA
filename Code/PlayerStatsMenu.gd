extends CanvasLayer

const DESIGN := Vector2(1000, 600)

@onready var control = $Control
@onready var layout: Control = $Control/Layout
@onready var age_label = $Control/Layout/Diagram/CenterNode/AgeLabel
@onready var speed_label = $Control/Layout/Diagram/TopNode/SpeedLabel
@onready var intellect_label = $Control/Layout/Diagram/RightNode/IntellectLabel
@onready var hp_label = $Control/Layout/Diagram/BottomRightNode/HPLabel
@onready var dash_label = $Control/Layout/Diagram/BottomLeftNode/DashLabel
@onready var damage_label = $Control/Layout/Diagram/LeftNode/DamageLabel
@onready var sacrifice_btn = $Control/Layout/ButtonsBox/SacrificeBtn
@onready var close_btn = $Control/Layout/ButtonsBox/CloseBtn
@onready var portrait_rect = $Control/Layout/PortraitPanel/Margin/VBox/PortraitRect
@onready var status_label = $Control/Layout/PortraitPanel/Margin/VBox/StatusLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	control.visible = false
	control.resized.connect(_fit_menu)
	_fit_menu()
	GameManager.player_stats_changed.connect(_update_stats_ui)
	GameManager.journey_time_changed.connect(_update_stats_ui)
	sacrifice_btn.pressed.connect(_on_sacrifice_pressed)
	close_btn.pressed.connect(_on_close_pressed)

func _fit_menu() -> void:
	var available: Vector2 = control.size
	var factor := minf(maxf(1.0, available.x - 32.0) / DESIGN.x, maxf(1.0, available.y - 32.0) / DESIGN.y)
	layout.size = DESIGN
	layout.scale = Vector2.ONE * factor
	layout.position = (available - DESIGN * factor) * 0.5

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.is_echo():
		toggle_menu()

func _can_use_attributes() -> bool:
	var scene: Node=get_tree().current_scene
	if not is_instance_valid(scene): return false
	return scene.scene_file_path not in ["res://Scenes/TitleScreen.tscn","res://Scenes/SplashScreen.tscn"]

func _process(_delta: float) -> void:
	if control.visible and not _can_use_attributes():
		control.hide()
		get_tree().paused=false

func toggle_menu() -> void:
	if control.visible:
		control.visible = false
		get_tree().paused = false
	else:
		if not _can_use_attributes(): return
		_fit_menu()
		_update_stats_ui()
		control.visible = true
		get_tree().paused = true

func _update_stats_ui() -> void:
	age_label.text = "Idade: " + str(GameManager.player_age)
	hp_label.text = str(GameManager.player_current_hp) + "/" + str(GameManager.player_max_hp)
	damage_label.text = str(GameManager.player_damage)
	speed_label.text = str(snapped(GameManager.player_speed_mult, 0.01)) + "x"
	dash_label.text = str(snapped(GameManager.player_dash_cooldown, 0.01)) + "s"
	intellect_label.text = str(GameManager.player_intellect)

	if GameManager.player_age >= 40:
		if ResourceLoader.exists("res://Assets/odisseu_velho.png"):
			portrait_rect.texture = load("res://Assets/odisseu_velho.png")
		status_label.text = "Veterano Experiente (" + str(GameManager.player_age) + " Anos)"
	else:
		if ResourceLoader.exists("res://Assets/odisseu.png"):
			portrait_rect.texture = load("res://Assets/odisseu.png")
		status_label.text = "Jovem Guerreiro (" + str(GameManager.player_age) + " Anos)"

	status_label.text += "\nRetorno: %s\nAnos sacrificados: %d" % [GameManager.story_time_text(), GameManager.sacrificed_years]

	if GameManager.standalone_stage_preview:
		status_label.text += "\nTeste da fase · sem salvar"

func _on_sacrifice_pressed() -> void:
	if not control.visible or not _can_use_attributes(): return
	GameManager.sacrifice_year()
	
func _on_close_pressed() -> void:
	toggle_menu()
