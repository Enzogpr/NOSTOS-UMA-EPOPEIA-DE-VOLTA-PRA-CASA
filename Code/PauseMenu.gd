extends CanvasLayer

@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeBtn
@onready var restart_btn: Button = $Panel/VBoxContainer/RestartBtn
@onready var menu_btn: Button = $Panel/VBoxContainer/MenuBtn

func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(_on_resume_pressed)
	restart_btn.pressed.connect(_on_restart_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			toggle_pause()

func toggle_pause() -> void:
	var current_scene = get_tree().current_scene
	if current_scene and (current_scene.name == "TitleScreen" or current_scene.name == "IntroCutscene" or current_scene.name == "Act1TitleCard"):
		return
		
	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	visible = is_paused
	
	if is_paused:
		resume_btn.grab_focus()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false

func _on_restart_pressed() -> void:
	get_tree().paused = false
	visible = false
	GameManager.heal_fully()
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	GameManager.reset()
	get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")
