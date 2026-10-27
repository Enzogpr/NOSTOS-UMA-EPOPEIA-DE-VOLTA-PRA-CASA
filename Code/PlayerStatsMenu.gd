extends CanvasLayer

@onready var control = $Control
@onready var age_label = $Control/Diagram/CenterNode/AgeLabel
@onready var speed_label = $Control/Diagram/TopNode/SpeedLabel
@onready var intellect_label = $Control/Diagram/RightNode/IntellectLabel
@onready var hp_label = $Control/Diagram/BottomRightNode/HPLabel
@onready var dash_label = $Control/Diagram/BottomLeftNode/DashLabel
@onready var damage_label = $Control/Diagram/LeftNode/DamageLabel
@onready var sacrifice_btn = $Control/ButtonsBox/SacrificeBtn
@onready var close_btn = $Control/ButtonsBox/CloseBtn
@onready var portrait_rect = $Control/PortraitPanel/Margin/VBox/PortraitRect
@onready var status_label = $Control/PortraitPanel/Margin/VBox/StatusLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	control.visible = false
	GameManager.player_stats_changed.connect(_update_stats_ui)
	sacrifice_btn.pressed.connect(_on_sacrifice_pressed)
	close_btn.pressed.connect(_on_close_pressed)

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

func _on_sacrifice_pressed() -> void:
	if not control.visible or not _can_use_attributes(): return
	GameManager.sacrifice_year()
	
func _on_close_pressed() -> void:
	toggle_menu()
