extends Node
## Diagnostic gallery rendered by Godot. Original assets are never modified.

func _ready() -> void:
	get_viewport().size = Vector2i(1920, 1080)
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://scratch/campaign_review/original_story.json"))
	for page in range(int(ceil(audit.art.size() / 12.0))):
		var board := Control.new()
		add_child(board)
		for slot in range(12):
			var index: int = page * 12 + slot
			if index >= audit.art.size():
				break
			var file: String = audit.art[index]
			var image_rect := TextureRect.new()
			image_rect.position = Vector2((slot % 4) * 480, (slot / 4) * 270)
			image_rect.size = Vector2(476, 240)
			image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image_rect.texture = load("res://" + file)
			board.add_child(image_rect)
			var label := Label.new()
			label.position = image_rect.position + Vector2(5, 240)
			label.text = str(index) + "  " + file.get_file()
			label.add_theme_font_size_override("font_size", 17)
			board.add_child(label)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://scratch/campaign_review/art_board_%d.png" % page)
		board.queue_free()
		await get_tree().process_frame
	get_tree().quit()
