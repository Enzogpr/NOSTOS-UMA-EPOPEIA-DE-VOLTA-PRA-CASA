extends Control

## Renderizador do Mini-mapa com Fog of War e Bússola

@onready var main_station = get_owner()

func _draw() -> void:
	if not main_station:
		main_station = get_parent().get_parent().get_parent()
	if not main_station or not ("player_pos" in main_station):
		return
		
	var cell_size: float = 11.0
	var offset_x: float = 10.0
	var offset_y: float = 10.0
	
	# Fundo do Minimapa
	draw_rect(Rect2(0, 0, size.x, size.y), Color(0.05, 0.08, 0.06, 0.85))
	
	for y in range(main_station.map_height):
		for x in range(main_station.map_width):
			var cell_pos = Vector2i(x, y)
			var draw_pos = Vector2(offset_x + x * cell_size, offset_y + y * cell_size)
			var rect = Rect2(draw_pos, Vector2(cell_size - 1, cell_size - 1))
			
			if cell_pos in main_station.explored:
				var tile = main_station.map[y][x]
				if tile == 1:
					draw_rect(rect, Color(0.12, 0.25, 0.15)) # Árvores
				elif tile == 0:
					draw_rect(rect, Color(0.35, 0.30, 0.22)) # Trilha
				elif tile == 5:
					draw_rect(rect, Color(0.2, 0.6, 0.8)) # Praia / Barco
				elif tile == 6:
					draw_rect(rect, Color(0.8, 0.75, 0.6)) # Ruínas
				elif tile in [2, 3, 4]:
					draw_rect(rect, Color(0.9, 0.3, 0.8)) # Tripulante / Lótus
			else:
				# Fog of War (Não explorado)
				draw_rect(rect, Color(0.02, 0.03, 0.02, 0.95))
				
	# Desenhar Jogador (Seta amarela na direção certa)
	var px = offset_x + main_station.player_pos.x * cell_size + cell_size * 0.5
	var py = offset_y + main_station.player_pos.y * cell_size + cell_size * 0.5
	var center = Vector2(px, py)
	
	var dir_vec = Vector2(main_station.dir_vectors[main_station.player_dir])
	var tip = center + dir_vec * 6.0
	var left_wing = center + dir_vec.rotated(2.4) * 4.0
	var right_wing = center + dir_vec.rotated(-2.4) * 4.0
	
	draw_colored_polygon(PackedVector2Array([tip, left_wing, right_wing]), Color(1.0, 0.85, 0.2))
