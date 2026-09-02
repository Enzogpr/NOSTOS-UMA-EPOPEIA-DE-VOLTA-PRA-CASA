extends Control

## Cutscene de Encerramento do Ato II - Chegada à Ilha a Leste

var current_slide := 0

var slides = [
	{
		"image": "res://Assets/act2_ending_fleet.jpg",
		"text": "Após dias enfrentando o mar aberto, os navios de Ítaca alcançam a enseada deserta e silenciosa de uma ilha selvagem a leste."
	},
	{
		"image": "res://Assets/act2_ending_landing.png",
		"text": "Odisseu: \"A maior parte dos homens deve aguardar ancorada na praia. Irei na frente com um grupo reduzido para explorar a ilha e buscar provisões.\""
	},
	{
		"image": "res://Assets/act2_ending_landing.png",
		"text": "Odisseu e seus homens desembarcam na praia de pedra e caminham sob a luz da lua em direção a uma enorme abertura na encosta da montanha..."
	}
]

@onready var texture_rect: TextureRect = $TextureRect
@onready var text_panel: ColorRect = $TextPanel
@onready var label: Label = $TextPanel/Label
@onready var continue_label: Label = $TextPanel/ContinueLabel

@onready var final_container: Control = $FinalContainer
@onready var end_title: Label = $FinalContainer/EndTitle
@onready var end_subtitle: Label = $FinalContainer/EndSubtitle

func _ready() -> void:
	final_container.visible = false
	_update_slide()

func _load_texture(path: String) -> Texture2D:
	var variations = [
		path,
		path.replace(".jpg", ".png"),
		path.replace(".png", ".jpg"),
		path.replace(".jpg", ".jpeg"),
		path.replace(".png", ".jpeg"),
		path.replace(".jpg", ".webp"),
		path.replace(".png", ".webp")
	]
	for p in variations:
		if ResourceLoader.exists(p):
			return load(p)
		if FileAccess.file_exists(p):
			var img = Image.new()
			var err = img.load(p)
			if err == OK:
				return ImageTexture.create_from_image(img)
	return null

func _update_slide() -> void:
	label.text = slides[current_slide]["text"]
	var img_path: String = slides[current_slide]["image"]
	
	texture_rect.texture = _load_texture(img_path)
	continue_label.text = "Pressione qualquer botão para continuar..."

func _unhandled_input(event: InputEvent) -> void:
	if final_container.visible:
		return
		
	if event.is_pressed() and not event.is_echo():
		if current_slide < slides.size() - 1:
			current_slide += 1
			_update_slide()
		else:
			_show_act_ending()

func _show_act_ending() -> void:
	text_panel.visible = false
	texture_rect.visible = false
	final_container.visible = true
	end_title.modulate.a = 0.0
	end_subtitle.modulate.a = 0.0
	
	var tween = create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(end_title, "modulate:a", 1.0, 1.5)
	tween.tween_property(end_subtitle, "modulate:a", 1.0, 1.5)
	tween.tween_interval(3.5)
	tween.tween_property(end_title, "modulate:a", 0.0, 1.5)
	tween.tween_property(end_subtitle, "modulate:a", 0.0, 1.5)
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://Scenes/TitleScreen.tscn")
	)
