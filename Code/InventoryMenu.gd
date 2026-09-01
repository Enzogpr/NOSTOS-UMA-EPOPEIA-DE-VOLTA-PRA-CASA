extends Control

## Menu de Inventário do Odisseu
## Abre ao pressionar [ I ], exibe os itens coletados e detalhes com duplo clique.

signal inventory_closed

@onready var item_list_container: VBoxContainer = $Panel/Margin/VBox/Scroll/ItemList
@onready var details_modal: Panel = $DetailsModal
@onready var details_title: Label = $DetailsModal/Margin/VBox/ItemTitle
@onready var details_desc: Label = $DetailsModal/Margin/VBox/ItemDesc
@onready var details_usage: Label = $DetailsModal/Margin/VBox/ItemUsage
@onready var details_img: TextureRect = $DetailsModal/Margin/VBox/ItemIcon

var _last_click_time: float = 0.0
var _last_clicked_id: String = ""

func _ready() -> void:
	details_modal.visible = false
	visible = false

func open_inventory() -> void:
	visible = true
	details_modal.visible = false
	_populate_items()

func close_inventory() -> void:
	visible = false
	details_modal.visible = false
	inventory_closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey and (event.keycode == KEY_I or event.keycode == KEY_ESCAPE):
			if details_modal.visible:
				details_modal.visible = false
			else:
				close_inventory()
			get_viewport().set_input_as_handled()

func _populate_items() -> void:
	for child in item_list_container.get_children():
		child.queue_free()
		
	var items = GameManager.inventory
	if items.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "O inventário está vazio."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		item_list_container.add_child(empty_lbl)
		return
		
	for item in items:
		var btn = Button.new()
		btn.text = "  🌸  " + item["name"] + "  (Clique duplo para examinar)"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 16)
		
		# Conecta clique
		var item_ref = item
		btn.pressed.connect(func(): _on_item_clicked(item_ref))
		item_list_container.add_child(btn)

func _on_item_clicked(item: Dictionary) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var is_double_click = (item["id"] == _last_clicked_id) and (current_time - _last_click_time < 0.5)
	
	_last_click_time = current_time
	_last_clicked_id = item["id"]
	
	# Abre os detalhes tanto no duplo clique quanto ao clicar no botão
	if is_double_click or true: # Permite abrir fácil para comodidade
		_show_item_details(item)

func _show_item_details(item: Dictionary) -> void:
	details_title.text = item["name"]
	details_desc.text = "📜 Descrição:\n" + item["description"]
	details_usage.text = "💡 Como Usar:\n" + item["usage"]
	
	var icon_path: String = item.get("icon", "")
	if ResourceLoader.exists(icon_path):
		details_img.texture = load(icon_path)
	elif ResourceLoader.exists(icon_path.replace(".jpg", ".png")):
		details_img.texture = load(icon_path.replace(".jpg", ".png"))
	else:
		details_img.texture = null
		
	details_modal.visible = true
