extends CanvasLayer

@onready var label: Label = $SpeechBubble/Label
@onready var athena_tex: TextureRect = $AthenaTex

var pages: Array = []
var current_page: int = 0

func _ready() -> void:
	if ResourceLoader.exists("res://Assets/athena.png"):
		athena_tex.texture = load("res://Assets/athena.png")

func setup(texts: Array) -> void:
	pages = texts
	current_page = 0
	if pages.size() > 0:
		label.text = pages[0]
	get_tree().paused = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		return
	if event.is_pressed() and not event.is_echo():
		current_page += 1
		if current_page < pages.size():
			label.text = pages[current_page]
		else:
			get_tree().paused = false
			queue_free()
