extends Control

@onready var player: Node2D = $MapPlayer
@onready var info_label: Label = $UI/InfoLabel
@onready var line_1_2: Line2D = $Paths/Line1_2
@onready var line_2_3: Line2D = $Paths/Line2_3

@onready var node1: MapNode = $Nodes/Node1
@onready var node2: MapNode = $Nodes/Node2
@onready var node3: MapNode = $Nodes/Node3

func _ready() -> void:
	player.arrived_at_node.connect(_on_player_arrived)
	
	# Inicializa as linhas (caminhos)
	line_1_2.default_color = Color(0.3, 0.3, 0.3, 0.5)
	line_2_3.default_color = Color(0.3, 0.3, 0.3, 0.5)
	
	var highest = GameManager.highest_unlocked_level
	if highest >= 2:
		line_1_2.default_color = Color(1.0, 0.8, 0.2, 1.0)
	if highest >= 3:
		line_2_3.default_color = Color(1.0, 0.8, 0.2, 1.0)
		
	# Coloca o jogador no nível mais alto desbloqueado por padrão
	if highest == 1:
		player.current_node = node1
	elif highest == 2:
		player.current_node = node2
	else:
		player.current_node = node3
		
	player.global_position = player.current_node.global_position
	_on_player_arrived(player.current_node)

func _on_player_arrived(node: MapNode) -> void:
	info_label.text = node.get_display_name()
