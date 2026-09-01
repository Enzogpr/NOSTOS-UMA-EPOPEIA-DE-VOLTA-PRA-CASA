extends Control

## Renderizador 2.5D Clássico em Primeira Pessoa (Estilo Shin Megami Tensei / Wizardry)

@onready var main_station = get_owner()

func _draw() -> void:
	if not main_station:
		main_station = get_parent().get_parent().get_parent()
	if not main_station or not ("player_pos" in main_station):
		return
		
	var w: float = size.x
	var h: float = size.y
	var half_h: float = h * 0.5
	
	# 1. Céu e Copa das Árvores
	var sky_color := Color(0.12, 0.28, 0.22) # Verde escuro de floresta densa
	var ground_color := Color(0.22, 0.16, 0.10) # Terra batida da selva
	
	draw_rect(Rect2(0, 0, w, half_h), sky_color)
	draw_rect(Rect2(0, half_h, w, half_h), ground_color)
	
	# Efeito de névoa / raios de sol no topo
	for i in range(12):
		var ray_x = (i * w / 10.0) + (sin(Time.get_ticks_msec() * 0.001 + i) * 20.0)
		draw_line(Vector2(ray_x, 0), Vector2(ray_x - 60, half_h), Color(0.8, 0.9, 0.5, 0.08), 16.0)
		
	# Trilhas / Caminho no chão
	var path_pts = PackedVector2Array([
		Vector2(w * 0.35, half_h), Vector2(w * 0.65, half_h),
		Vector2(w * 0.85, h), Vector2(w * 0.15, h)
	])
	draw_colored_polygon(path_pts, Color(0.28, 0.22, 0.14))
	
	# 2. Renderização de Profundidade (Distâncias 3, 2, 1)
	var pos: Vector2i = main_station.player_pos
	var dir_idx: int = main_station.player_dir
	var fwd: Vector2i = main_station.dir_vectors[dir_idx]
	var right: Vector2i = main_station.dir_vectors[(dir_idx + 1) % 4]
	var left: Vector2i = -right
	
	# Renderiza de trás para frente (distância 3 -> 2 -> 1)
	for dist in range(3, 0, -1):
		var check_pos = pos + (fwd * dist)
		_draw_layer(check_pos, left, right, dist, w, h, half_h)
		
	# 3. Elemento na célula atual (se estiver no mesmo tile do NPC)
	_draw_current_cell_event(pos, w, h, half_h)

func _draw_layer(check_pos: Vector2i, left: Vector2i, right: Vector2i, dist: int, w: float, h: float, half_h: float) -> void:
	var map = main_station.map
	if not _is_valid(check_pos):
		return
		
	# Cores com base na distância (névoa atmosférica)
	var depth_factor: float = float(dist) / 3.0
	var tree_color: Color = Color(0.08, 0.18, 0.12).lerp(Color(0.18, 0.42, 0.24), 1.0 - depth_factor * 0.6)
	var trunk_color: Color = Color(0.15, 0.10, 0.05).lerp(Color(0.35, 0.24, 0.14), 1.0 - depth_factor * 0.6)
	
	var scale_factor: float = 1.0 / float(dist)
	var box_w: float = w * scale_factor * 0.45
	var box_h: float = h * scale_factor * 0.45
	
	# Parede Frontal de Árvores
	if _get_tile(check_pos) == 1:
		var front_x = (w - box_w) * 0.5
		var front_y = half_h - box_h * 0.5
		# Troncos de árvores densas
		draw_rect(Rect2(front_x, front_y, box_w, box_h), trunk_color)
		# Folhagem orgânica exuberante
		draw_circle(Vector2(w * 0.5, front_y), box_w * 0.55, tree_color)
		draw_circle(Vector2(front_x + box_w * 0.2, front_y + box_h * 0.1), box_w * 0.35, tree_color.darkened(0.08))
		draw_circle(Vector2(front_x + box_w * 0.8, front_y + box_h * 0.1), box_w * 0.35, tree_color.darkened(0.08))
		# Flores tropicais sutis nos galhos
		if dist <= 2:
			draw_circle(Vector2(front_x + box_w * 0.3, front_y + box_h * 0.3), 5.0 * scale_factor, Color(0.85, 0.45, 0.8, 0.8))
			draw_circle(Vector2(front_x + box_w * 0.7, front_y + box_h * 0.25), 4.0 * scale_factor, Color(0.85, 0.45, 0.8, 0.8))
	else:
		# Se for NPC / Tripulante à distância
		if _get_tile(check_pos) in [2, 3, 4]:
			_draw_npc_sprite(Vector2(w * 0.5, half_h + box_h * 0.2), scale_factor, _get_tile(check_pos))
			
	# Paredes Laterais (Esquerda e Direita)
	var left_pos = check_pos + left
	var right_pos = check_pos + right
	
	if _get_tile(left_pos) == 1:
		var l_pts = PackedVector2Array([
			Vector2(0, half_h - box_h * 0.9), Vector2((w - box_w) * 0.5, half_h - box_h * 0.5),
			Vector2((w - box_w) * 0.5, half_h + box_h * 0.5), Vector2(0, half_h + box_h * 0.9)
		])
		draw_colored_polygon(l_pts, trunk_color.darkened(0.15))
		draw_circle(Vector2((w - box_w) * 0.22, half_h - box_h * 0.55), box_w * 0.35, tree_color.darkened(0.1))
		
	if _get_tile(right_pos) == 1:
		var r_pts = PackedVector2Array([
			Vector2(w, half_h - box_h * 0.9), Vector2(w - (w - box_w) * 0.5, half_h - box_h * 0.5),
			Vector2(w - (w - box_w) * 0.5, half_h + box_h * 0.5), Vector2(w, half_h + box_h * 0.9)
		])
		draw_colored_polygon(r_pts, trunk_color.darkened(0.15))
		draw_circle(Vector2(w - (w - box_w) * 0.22, half_h - box_h * 0.55), box_w * 0.35, tree_color.darkened(0.1))

func _draw_current_cell_event(pos: Vector2i, w: float, h: float, half_h: float) -> void:
	var tile = _get_tile(pos)
	if tile in [2, 3, 4]:
		_draw_npc_sprite(Vector2(w * 0.5, h * 0.65), 1.6, tile)
	elif tile == 5:
		# Visual da praia (Barco ao longe)
		draw_rect(Rect2(w * 0.35, half_h - 40, w * 0.3, 30), Color(0.45, 0.3, 0.15))
		draw_line(Vector2(w * 0.5, half_h - 70), Vector2(w * 0.5, half_h - 10), Color(0.3, 0.2, 0.1), 4.0)

func _draw_npc_sprite(center: Vector2, scale: float, type: int) -> void:
	# Fogueira e flores de lótus ao redor do NPC
	draw_circle(center + Vector2(0, 15 * scale), 20 * scale, Color(0.9, 0.4, 0.1, 0.6)) # Brilho do fogo
	draw_circle(center + Vector2(0, 15 * scale), 8 * scale, Color(1.0, 0.8, 0.2)) # Chama
	
	# Pétalas de lótus brilhantes
	draw_circle(center + Vector2(-25 * scale, 10 * scale), 6 * scale, Color(0.9, 0.4, 0.8, 0.9))
	draw_circle(center + Vector2(25 * scale, 12 * scale), 6 * scale, Color(0.9, 0.4, 0.8, 0.9))
	
	# Corpo do marinheiro deitado/sentado
	draw_rect(Rect2(center.x - 18 * scale, center.y - 25 * scale, 36 * scale, 30 * scale), Color(0.75, 0.6, 0.4))
	# Manto grego
	draw_rect(Rect2(center.x - 14 * scale, center.y - 15 * scale, 28 * scale, 20 * scale), Color(0.8, 0.25, 0.25) if type != 4 else Color(0.4, 0.2, 0.6))
	# Cabeça com coroa de flores
	draw_circle(center + Vector2(0, -32 * scale), 12 * scale, Color(0.8, 0.65, 0.5))
	draw_circle(center + Vector2(0, -40 * scale), 6 * scale, Color(0.9, 0.5, 0.8)) # Flor na cabeça

func _is_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < main_station.map_width and pos.y >= 0 and pos.y < main_station.map_height

func _get_tile(pos: Vector2i) -> int:
	if not _is_valid(pos):
		return 1
	return main_station.map[pos.y][pos.x]
