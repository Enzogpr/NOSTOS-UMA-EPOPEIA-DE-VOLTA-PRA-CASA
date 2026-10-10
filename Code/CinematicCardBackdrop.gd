extends Control
## Scene-independent atmospheric backdrop for the three act cards.
var elapsed: float = 0.0
var image: TextureRect

static func attach(host: Node, texture_path: String) -> Control:
	var backdrop := Control.new()
	backdrop.set_script(load("res://Code/CinematicCardBackdrop.gd"))
	backdrop.name = "CinematicBackdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(backdrop)
	host.move_child(backdrop, 0)
	backdrop.image = TextureRect.new()
	backdrop.image.texture = load(texture_path)
	backdrop.image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	backdrop.image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(backdrop.image)
	backdrop.image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.image.modulate = Color(0.42, 0.45, 0.52)
	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.025, 0.045, 0.45)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for path in ["Background", "ColorRect"]:
		var old := host.get_node_or_null(path)
		if old is ColorRect:
			old.color.a = 0.28
	return backdrop

func _process(delta: float) -> void:
	elapsed += delta
	if image:
		image.pivot_offset = size * 0.5
		image.scale = Vector2.ONE * (1.035 + sin(elapsed * 0.12) * 0.012)
	queue_redraw()

func _draw() -> void:
	for i in range(25):
		var point := Vector2(fmod(i * 139.0 + sin(elapsed * 0.2 + i) * 9.0, size.x), wrapf(i * 53.0 - elapsed * (3 + i % 6), 0, size.y))
		draw_rect(Rect2(point.round(), Vector2.ONE * (1 + i % 2)), Color(0.9, 0.76, 0.52, 0.12))
