extends Control

@onready var texture_rect: TextureRect = $TextureRect
@onready var logo_rect: TextureRect = $LogoRect
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

var can_start: bool = true

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
		
	_start_pulse_animation()

func _start_pulse_animation() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(subtitle_label, "modulate:a", 0.35, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

func _unhandled_input(event: InputEvent) -> void:
	if can_start and event.is_pressed() and not event.is_echo():
		can_start = false
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func():
			get_tree().change_scene_to_file("res://Ato1_Troia/Cutscenes/Act1_TitleCard.tscn")
		)
