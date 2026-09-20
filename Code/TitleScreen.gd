extends Control

@onready var texture_rect: TextureRect = $TextureRect
@onready var logo_rect: TextureRect = $LogoRect
@onready var title_label: Label = $TitleLabel
@onready var menu_vbox: VBoxContainer = $MenuVBox
@onready var btn_novo: Button = $MenuVBox/BtnNovoJogo
@onready var btn_continuar: Button = $MenuVBox/BtnContinuar
@onready var btn_opcoes: Button = $MenuVBox/BtnOpcoes
@onready var btn_sair: Button = $MenuVBox/BtnSair
@onready var settings_menu: Control = $SettingsMenu

func _ready() -> void:
	if ResourceLoader.exists("res://Assets/title_bg.png"):
		texture_rect.texture = load("res://Assets/title_bg.png")
		
	if ResourceLoader.exists("res://Assets/logo.png"):
		logo_rect.texture = load("res://Assets/logo.png")
		logo_rect.visible = true
		title_label.visible = false
	else:
		logo_rect.visible = false
		title_label.visible = true
		
	btn_novo.pressed.connect(_on_novo_pressed)
	btn_continuar.pressed.connect(_on_continuar_pressed)
	btn_opcoes.pressed.connect(func(): settings_menu.open_settings())
	btn_sair.pressed.connect(_on_sair_pressed)
	
	if GameManager.has_save_file():
		btn_continuar.disabled = false
		btn_continuar.grab_focus()
	else:
		btn_continuar.disabled = true
		btn_novo.grab_focus()

func _on_novo_pressed() -> void:
	GameManager.reset()
	GameManager.save_game()
	_transition_to_map()

func _on_continuar_pressed() -> void:
	if GameManager.load_game():
		_transition_to_map()

func _on_sair_pressed() -> void:
	get_tree().quit()

func _transition_to_map() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://Scenes/WorldMap.tscn")
	)
