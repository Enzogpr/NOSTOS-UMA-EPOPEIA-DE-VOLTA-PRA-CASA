extends RefCounted
## Lightweight adapter: existing campaign scripts keep all gameplay logic.

static func attach(host: Control, callback: Callable) -> Control:
	var stage: Control = load("res://Scenes/CinematicPresenter.tscn").instantiate()
	stage.name = "CinematicPresentation"
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.z_index = 10
	host.add_child(stage)
	stage.advance_requested.connect(callback)
	for path in ["TextureRect", "TextPanel", "BottomGradient"]:
		var old: Node = host.get_node_or_null(path)
		if old is CanvasItem:
			old.hide()
	for path in ["PanicHUD", "NameInputPanel", "GameOverOverlay", "InventoryMenu", "MinigamePanel", "ChoiceContainer", "FinalContainer"]:
		var overlay: Node = host.get_node_or_null(path)
		if overlay is CanvasItem:
			overlay.z_index = 20
	return stage
