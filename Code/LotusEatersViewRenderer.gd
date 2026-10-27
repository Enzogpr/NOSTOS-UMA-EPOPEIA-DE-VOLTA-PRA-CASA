extends Control

## Renderizador 2.5D em Primeira Pessoa da Ilha dos Lotófagos
## Árvores ampliadas completando as laterais, setas de madeira nas paredes/bifurcações e chão dinâmico.

@onready var main_station = get_owner()

# Texturas do Cenário
var tex_sky: Texture2D
var tex_ground: Texture2D
var tex_trees_left: Texture2D
var tex_trees_right: Texture2D
var tex_wall_blocked: Texture2D
var tex_arrow_wood_left: Texture2D
var tex_arrow_wood_right: Texture2D
var tex_lotus_npc: Texture2D
var tex_crew: Texture2D
var tex_bewitched_crew: Texture2D

var tex_bushes: Array[Texture2D] = []
var tex_rocks: Array[Texture2D] = []

# Animações de Movimento
var _anim_time: float = 0.0
var _step_progress: float = 0.0

# Hover e clique
var hover_left: bool = false
var hover_right: bool = false
var hover_forward: bool = false

func _ready() -> void:
	_load_textures()
	mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	_anim_time += delta
	if _step_progress > 0.0:
		_step_progress = max(0.0, _step_progress - delta * 3.5)
	queue_redraw()

func trigger_step_animation() -> void:
	_step_progress = 1.0
	queue_redraw()

func trigger_turn_animation() -> void:
	queue_redraw()

func _load_textures() -> void:
	# 1. Árvores Laterais
	tex_trees_left = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/ARVORESESQUERDA.png")
	if not tex_trees_left:
		tex_trees_left = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/ARVORESLADOESQUERDO.png")

	tex_trees_right = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/ARVORESDIREITA.png")
	if not tex_trees_right:
		tex_trees_right = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/ARVORESLADODIREITO.png")

	# 2. Setas de Madeira
	tex_arrow_wood_left = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/SETAESQUERDA.png")
	if not tex_arrow_wood_left:
		tex_arrow_wood_left = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/SETALADOESQUERDO.png")

	tex_arrow_wood_right = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/SETADIREITA.png")
	if not tex_arrow_wood_right:
		tex_arrow_wood_right = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/SETALADODIREITO.png")

	# 3. Céu, Chão, Parede e NPCs
	tex_sky = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/CÉU.png")
	tex_ground = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/CHÃO.png")
	tex_wall_blocked = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/PAREDEQUENAOPODEPASSAR.png")
	tex_lotus_npc = _try_load("res://IMAGEM JOGO/LOTÓFAGO.png")
	tex_crew = _try_load("res://IMAGEM JOGO/TRIPULANTE COMUM.png")
	tex_bewitched_crew = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/TRIPULANTEENFEITIÇADO.png")
	if not tex_bewitched_crew:
		tex_bewitched_crew = _try_load("res://IMAGEM JOGO/TRIPULANTEENFEITIÇADO.png")

	# Varredura inteligente de diretório
	var dir = DirAccess.open("res://IMAGEM JOGO/ATO 2 FASE 01")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".png"):
				var full_path = "res://IMAGEM JOGO/ATO 2 FASE 01/" + file_name
				var u_name = file_name.to_upper()
				if not tex_sky and ("C" in u_name and "U.PNG" in u_name):
					tex_sky = _try_load(full_path)
				elif not tex_ground and ("CH" in u_name and "O.PNG" in u_name):
					tex_ground = _try_load(full_path)
				elif not tex_trees_left and ("ESQUERDA" in u_name and "ARV" in u_name):
					tex_trees_left = _try_load(full_path)
				elif not tex_trees_right and ("DIREITA" in u_name and "ARV" in u_name):
					tex_trees_right = _try_load(full_path)
				elif not tex_arrow_wood_left and ("SETA" in u_name and "ESQ" in u_name):
					tex_arrow_wood_left = _try_load(full_path)
				elif not tex_arrow_wood_right and ("SETA" in u_name and "DIR" in u_name):
					tex_arrow_wood_right = _try_load(full_path)
				elif not tex_wall_blocked and ("PAREDE" in u_name):
					tex_wall_blocked = _try_load(full_path)
				elif not tex_bewitched_crew and ("ENFEITI" in u_name or ("TRIPULANTE" in u_name and "COMUM" not in u_name)):
					tex_bewitched_crew = _try_load(full_path)
			file_name = dir.get_next()
	
	# Arbustos (1 a 10)
	tex_bushes.clear()
	for i in range(1, 11):
		var b = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/ARBUSTO%d.png" % i)
		if b:
			tex_bushes.append(b)
			
	# Pedras (1 a 11)
	tex_rocks.clear()
	for i in range(1, 12):
		var r = _try_load("res://IMAGEM JOGO/ATO 2 FASE 01/PEDRA%d.png" % i)
		if r:
			tex_rocks.append(r)

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _gui_input(event: InputEvent) -> void:
	if not main_station:
		return
		
	if event is InputEventMouseMotion:
		var w = size.x
		var h = size.y
		var m_pos = event.position
		hover_left = (m_pos.x < w * 0.28)
		hover_right = (m_pos.x > w * 0.72)
		hover_forward = (m_pos.x >= w * 0.28 and m_pos.x <= w * 0.72 and m_pos.y < h * 0.75 and m_pos.y > h * 0.25)
		queue_redraw()
		
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var w = size.x
		var h = size.y
		var m_pos = event.position
		if m_pos.x < w * 0.28:
			main_station._turn_left()
			trigger_turn_animation()
		elif m_pos.x > w * 0.72:
			main_station._turn_right()
			trigger_turn_animation()
		elif m_pos.y < h * 0.65:
			main_station._move_forward()
			trigger_step_animation()
		else:
			main_station._move_backward()
			trigger_step_animation()

func _draw() -> void:
	if not main_station:
		main_station = get_parent().get_parent().get_parent()
	if not main_station or not ("player_pos" in main_station):
		return
		
	var w: float = size.x
	var h: float = size.y
	if w <= 1.0 or h <= 1.0:
		return
		
	# Linha do Horizonte FIXA
	var horizon_y: float = h * 0.46
	
	# Posições e Vetores do Jogador
	var pos: Vector2i = main_station.player_pos
	var dir_idx: int = main_station.player_dir
	var fwd: Vector2i = main_station.dir_vectors[dir_idx]
	var right: Vector2i = main_station.dir_vectors[(dir_idx + 1) % 4]
	var left: Vector2i = -right
	
	# Encontra a primeira parede bloqueada na linha de visão à frente
	var first_blocked_dist = 0
	for d in range(1, 4):
		if _get_tile(pos + (fwd * d)) == 1:
			first_blocked_dist = d
			break
	
	# 1. CÉU (Sempre presente)
	_draw_sky(w, horizon_y)
	
	# 2. CHÃO COM PERSPECTIVA (Sempre presente)
	_draw_ground(w, h, horizon_y)
	
	# Efeito de raios de sol
	_draw_sunbeams(w, horizon_y)
	
	# =========================================================================
	# CENÁRIO 1: FIM DO CAMINHO / PAREDE FRONTAL (dist == 1)
	# A parede PAREDEQUENAOPODEPASSAR.png é a cena completa frontal.
	# As árvores laterais NÃO são desenhadas por cima dela para evitar sobreposição.
	# =========================================================================
	if first_blocked_dist == 1:
		_draw_dead_end_wall(w, h, horizon_y)
		_draw_wall_wooden_arrows(pos, left, right, fwd, w, h, horizon_y)
		_draw_current_cell_event(pos, w, h)
		return
		
	# =========================================================================
	# CENÁRIO 2: CORREDOR ABERTO / NAVEGAÇÃO
	# Trilha aberta, vegetação ao longe no horizonte e árvores laterais.
	# =========================================================================
	# 3. SELVA DISTANTE NO HORIZONTE (Evita o vazio de céu no fim da trilha)
	_draw_distant_forest(w, h, horizon_y, first_blocked_dist)
	
	# 4. TRILHA NA SELVA
	_draw_path(w, h, horizon_y)
	
	# 5. RENDERIZAÇÃO DE PROFUNDIDADE (Distâncias 3, 2 e 1)
	for dist in range(3, 0, -1):
		var check_pos = pos + (fwd * dist)
		_draw_depth_layer(check_pos, left, right, dist, first_blocked_dist, w, h, horizon_y)
		
	# 6. MOLDURA FRONTAL (ÁRVORES LATERAIS FORMANDO O CORREDOR SEM NENHUM VÃO)
	_draw_foreground_trees(w, h)
	
	# 7. PLACAS DE SINALIZAÇÃO LATERAL (Quando houver caminhos para os lados)
	_draw_wall_wooden_arrows(pos, left, right, fwd, w, h, horizon_y)
	
	# 8. EVENTO NA CÉLULA ATUAL
	_draw_current_cell_event(pos, w, h)
	
	# 9. INDICADOR DE AVANÇO
	_draw_forward_indicator(pos, fwd, w, h)

# -------------------------------------------------------------
# SUB-ROTINAS DE DESENHO
# -------------------------------------------------------------

func _draw_dead_end_wall(w: float, h: float, horizon_y: float) -> void:
	if tex_wall_blocked:
		var img_sz: Vector2 = tex_wall_blocked.get_size()
		var img_aspect: float = img_sz.x / img_sz.y
		var screen_aspect: float = w / h
		
		var draw_w: float = w
		var draw_h: float = h
		
		# Aspect Cover com margem de sangramento para cobrir 100% da tela sem frestas
		if img_aspect > screen_aspect:
			draw_h = h * 1.10
			draw_w = draw_h * img_aspect
		else:
			draw_w = w * 1.10
			draw_h = draw_w / img_aspect
			
		var draw_x: float = (w - draw_w) * 0.5
		var draw_y: float = (h - draw_h) * 0.5 - (h * 0.02)
		var wall_rect = Rect2(draw_x, draw_y, draw_w, draw_h)
		draw_texture_rect(tex_wall_blocked, wall_rect, false)
	else:
		draw_rect(Rect2(0, 0, w, h), Color(0.10, 0.20, 0.12))

func _draw_distant_forest(w: float, h: float, horizon_y: float, first_blocked_dist: int) -> void:
	# Fecha a linha do horizonte com vegetação distante para a trilha nunca terminar num vazio de céu
	if tex_wall_blocked:
		var dist_h: float = h * 0.36
		var dist_w: float = dist_h * (1448.0 / 1086.0)
		var center_x: float = w * 0.5
		# Tonalidade com névoa atmosférica de distância
		var haze_tint = Color(0.70, 0.82, 0.74, 0.95)
		var dist_rect = Rect2(center_x - dist_w * 0.5, horizon_y - dist_h * 0.65, dist_w, dist_h)
		draw_texture_rect(tex_wall_blocked, dist_rect, false, haze_tint)

# -------------------------------------------------------------
# SUB-ROTINAS DE DESENHO
# -------------------------------------------------------------

func _draw_sky(w: float, horizon_y: float) -> void:
	if tex_sky:
		var sky_rect = Rect2(0, 0, w, horizon_y + 16)
		draw_texture_rect(tex_sky, sky_rect, false)
	else:
		draw_rect(Rect2(0, 0, w, horizon_y + 16), Color(0.10, 0.24, 0.20))

func _draw_ground(w: float, h: float, horizon_y: float) -> void:
	if tex_ground:
		var step_offset = _step_progress * 28.0
		var ground_rect = Rect2(0, horizon_y - step_offset * 0.3, w, (h - horizon_y) + step_offset * 0.8)
		draw_texture_rect(tex_ground, ground_rect, false)
	else:
		draw_rect(Rect2(0, horizon_y, w, h - horizon_y), Color(0.20, 0.15, 0.10))

func _draw_sunbeams(w: float, horizon_y: float) -> void:
	for i in range(8):
		var ray_x = (i * w / 7.0) + (sin(_anim_time * 0.8 + i * 1.5) * 15.0)
		draw_line(Vector2(ray_x, 0), Vector2(ray_x - 80, horizon_y + 30), Color(0.9, 0.95, 0.6, 0.05), 24.0)

func _draw_path(w: float, h: float, horizon_y: float) -> void:
	# CHÃO.png já contém a trilha com texturas nítidas.
	# Não desenhamos polígonos marrons por cima para evitar qualquer névoa/mancha escura no fundo.
	pass

func _draw_depth_layer(check_pos: Vector2i, left: Vector2i, right: Vector2i, dist: int, first_blocked_dist: int, w: float, h: float, horizon_y: float) -> void:
	if not _is_valid(check_pos):
		return
		
	var tile = _get_tile(check_pos)
	var effective_dist = float(dist) - (_step_progress * 0.45)
	var scale_factor: float = 1.0 / max(0.5, effective_dist)
	var depth_factor: float = float(dist) / 3.0
	var depth_tint: Color = Color(1.0, 1.0, 1.0).lerp(Color(0.60, 0.75, 0.68), depth_factor * 0.5)
	var center_x: float = w * 0.5
	
	# 1. PAREDE AO LONGE NO HORIZONTE (Distância 2 ou 3)
	if tile == 1 and dist == first_blocked_dist:
		var wall_h: float = h * scale_factor * 0.92
		var wall_w: float = wall_h * (1448.0 / 1086.0)
		var wall_rect = Rect2(center_x - wall_w * 0.5, horizon_y - wall_h * 0.50, wall_w, wall_h)
		if tex_wall_blocked:
			draw_texture_rect(tex_wall_blocked, wall_rect, false, depth_tint)
		else:
			draw_rect(wall_rect, Color(0.12, 0.22, 0.14).lerp(Color(0.04, 0.08, 0.05), depth_factor))
	elif tile != 1:
		if tile in [2, 3, 4]:
			_draw_npc_element(Vector2(center_x, horizon_y + (h * 0.22 * scale_factor)), scale_factor, tile, depth_tint)
			
	# 2. ÁRVORES LATERAIS NA PROFUNDIDADE (Distância 2 e 3)
	if dist >= 2:
		var side_tree_h: float = h * scale_factor * 1.05
		var side_tree_w: float = side_tree_h * (1024.0 / 1536.0)
		var box_half_w: float = w * scale_factor * 0.35
		
		# Parede Lateral Esquerda
		var left_pos = check_pos + left
		if _get_tile(left_pos) == 1 and tex_trees_left:
			var l_rect = Rect2(center_x - box_half_w - side_tree_w * 0.85, horizon_y - side_tree_h * 0.55, side_tree_w, side_tree_h)
			draw_texture_rect(tex_trees_left, l_rect, false, depth_tint.darkened(0.15))
			
		# Parede Lateral Direita
		var right_pos = check_pos + right
		if _get_tile(right_pos) == 1 and tex_trees_right:
			var r_rect = Rect2(center_x + box_half_w - side_tree_w * 0.15, horizon_y - side_tree_h * 0.55, side_tree_w, side_tree_h)
			draw_texture_rect(tex_trees_right, r_rect, false, depth_tint.darkened(0.15))

	# 3. PEDRAS E ARBUSTOS DA PROFUNDIDADE
	_draw_tile_decorations(check_pos, dist, w, h, horizon_y, scale_factor, depth_tint)

func _draw_wall_wooden_arrows(pos: Vector2i, left: Vector2i, right: Vector2i, fwd: Vector2i, w: float, h: float, horizon_y: float) -> void:
	var can_turn_left = (_get_tile(pos + left) != 1)
	var can_turn_right = (_get_tile(pos + right) != 1)
	var fwd_blocked = (_get_tile(pos + fwd) == 1)
	
	# Se não houver nenhum caminho para os lados, não desenha placas
	if not can_turn_left and not can_turn_right:
		return
		
	# Tamanho e posição proporcional: ligeiramente mais compacto em encruzilhadas abertas
	var arrow_h = h * (0.32 if fwd_blocked else 0.27)
	var arrow_w = arrow_h * (1086.0 / 1448.0)
	var arrow_y = h * (0.64 if fwd_blocked else 0.66)
	var font = ThemeDB.fallback_font
	
	# SETA DE MADEIRA PARA A ESQUERDA (NO CHÃO)
	if can_turn_left and tex_arrow_wood_left:
		var arrow_x = (w * 0.20 if fwd_blocked else w * 0.17) - arrow_w * 0.5
		var arrow_rect = Rect2(arrow_x, arrow_y, arrow_w, arrow_h)
		
		var tint = Color(1.25, 1.25, 0.85, 1.0) if hover_left else Color(1.0, 1.0, 1.0, 1.0)
		draw_texture_rect(tex_arrow_wood_left, arrow_rect, false, tint)
		
		# Badge com fundo escuro e borda dourada
		var badge_w: float = 78.0
		var badge_h: float = 23.0
		var badge_rect = Rect2(arrow_x + (arrow_w - badge_w) * 0.5, arrow_y + arrow_h - 2.0, badge_w, badge_h)
		draw_rect(badge_rect, Color(0.06, 0.10, 0.07, 0.90), true)
		draw_rect(badge_rect, Color(1.0, 0.85, 0.35, 0.95), false, 1.5)
		draw_string(font, Vector2(badge_rect.position.x + 13, badge_rect.position.y + 16.0), "[ A ] ◄", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.98, 0.85))

	# SETA DE MADEIRA PARA A DIREITA (NO CHÃO)
	if can_turn_right and tex_arrow_wood_right:
		var arrow_x = (w * 0.80 if fwd_blocked else w * 0.83) - arrow_w * 0.5
		var arrow_rect = Rect2(arrow_x, arrow_y, arrow_w, arrow_h)
		
		var tint = Color(1.25, 1.25, 0.85, 1.0) if hover_right else Color(1.0, 1.0, 1.0, 1.0)
		draw_texture_rect(tex_arrow_wood_right, arrow_rect, false, tint)
		
		# Badge com fundo escuro e borda dourada
		var badge_w: float = 78.0
		var badge_h: float = 23.0
		var badge_rect = Rect2(arrow_x + (arrow_w - badge_w) * 0.5, arrow_y + arrow_h - 2.0, badge_w, badge_h)
		draw_rect(badge_rect, Color(0.06, 0.10, 0.07, 0.90), true)
		draw_rect(badge_rect, Color(1.0, 0.85, 0.35, 0.95), false, 1.5)
		draw_string(font, Vector2(badge_rect.position.x + 13, badge_rect.position.y + 16.0), "► [ D ]", HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(1.0, 0.98, 0.85))

func _draw_foreground_trees(w: float, h: float) -> void:
	# === MOLDURA FRONTAL COM PARALAXE E COBERTURA TOTAL ===
	const BASE_RATIO: float = 0.42
	var bleed_edge: float = w * 0.12
	
	# Paralaxe: ao avançar o passo, as árvores se afastam do centro suavemente
	var parallax: float = _step_progress * 0.06
	var parallax_scale: float = 1.0 + parallax
	var parallax_shift_l: float = -w * parallax
	var parallax_shift_r: float = w * parallax
	
	var tree_h: float = h * (1.16 + parallax * 0.5)
	var scaled_w: float = (w * BASE_RATIO * parallax_scale) + bleed_edge
	var tree_y: float = -(h * 0.08)
	
	# 1. Árvore da Esquerda (começa bem antes da borda esquerda)
	if tex_trees_left:
		var l_rect = Rect2(-bleed_edge + parallax_shift_l, tree_y, scaled_w, tree_h)
		draw_texture_rect(tex_trees_left, l_rect, false)
	else:
		var lx: float = -bleed_edge + parallax_shift_l
		var l_pts = PackedVector2Array([Vector2(lx, 0), Vector2(lx + scaled_w, 0), Vector2(lx + scaled_w, h), Vector2(lx, h)])
		draw_polygon(l_pts, PackedColorArray([Color(0.08, 0.18, 0.12)]))
		
	# 2. Árvore da Direita (termina bem depois da borda direita)
	if tex_trees_right:
		var r_x: float = w - scaled_w + bleed_edge + parallax_shift_r
		var r_rect = Rect2(r_x, tree_y, scaled_w, tree_h)
		draw_texture_rect(tex_trees_right, r_rect, false)
	else:
		var rx: float = w - scaled_w + bleed_edge + parallax_shift_r
		var r_pts = PackedVector2Array([Vector2(rx, 0), Vector2(rx + scaled_w, 0), Vector2(rx + scaled_w, h), Vector2(rx, h)])
		draw_polygon(r_pts, PackedColorArray([Color(0.08, 0.18, 0.12)]))
		
	# 3. Arbustos e Pedras no primeiro plano (acompanhando o movimento de passo)
	_draw_foreground_foliage(w, h, parallax_shift_l, parallax_shift_r, parallax_scale)

func _draw_foreground_foliage(w: float, h: float, shift_l: float, shift_r: float, p_scale: float) -> void:
	# Canto inferior esquerdo (acompanha o passo)
	if tex_bushes.size() > 0:
		var b_tex = tex_bushes[0]
		var b_w = w * 0.25 * p_scale
		var b_h = b_w * (333.0 / 468.0)
		draw_texture_rect(b_tex, Rect2(Vector2(shift_l, h - b_h * 0.92), Vector2(b_w, b_h)), false)
		
	if tex_rocks.size() > 0:
		var r_tex = tex_rocks[0]
		var r_w = w * 0.15 * p_scale
		var r_h = r_w * (468.0 / 556.0)
		draw_texture_rect(r_tex, Rect2(Vector2(w * 0.10 + shift_l * 0.8, h - r_h * 0.88), Vector2(r_w, r_h)), false)
		
	# Canto inferior direito (acompanha o passo)
	if tex_bushes.size() > 1:
		var b_tex = tex_bushes[1]
		var b_w = w * 0.25 * p_scale
		var b_h = b_w * (230.0 / 355.0)
		draw_texture_rect(b_tex, Rect2(Vector2(w - b_w + shift_r, h - b_h * 0.92), Vector2(b_w, b_h)), false)
		
	if tex_rocks.size() > 1:
		var r_tex = tex_rocks[1]
		var r_w = w * 0.15 * p_scale
		var r_h = r_w * (344.0 / 429.0)
		draw_texture_rect(r_tex, Rect2(Vector2(w - w * 0.10 - r_w + shift_r * 0.8, h - r_h * 0.88), Vector2(r_w, r_h)), false)

func _draw_tile_decorations(tile_pos: Vector2i, dist: int, w: float, h: float, horizon_y: float, scale_factor: float, depth_tint: Color) -> void:
	var seed_val: int = abs((tile_pos.x * 73856093) ^ (tile_pos.y * 19349663) ^ (dist * 83492791))
	
	if tex_bushes.size() > 0:
		var bush_idx = seed_val % tex_bushes.size()
		var bush_tex = tex_bushes[bush_idx]
		var bush_w = (130.0 * scale_factor)
		var bush_h = (95.0 * scale_factor)
		
		var side_offset_x = (w * 0.5) - (w * 0.28 * scale_factor) - bush_w * 0.5
		var bush_y = horizon_y + (h * 0.28 * scale_factor) - bush_h * 0.7
		draw_texture_rect(bush_tex, Rect2(side_offset_x, bush_y, bush_w, bush_h), false, depth_tint)
		
		var bush2_idx = (bush_idx + 3) % tex_bushes.size()
		var bush2_tex = tex_bushes[bush2_idx]
		var side2_offset_x = (w * 0.5) + (w * 0.28 * scale_factor) - bush_w * 0.5
		draw_texture_rect(bush2_tex, Rect2(side2_offset_x, bush_y + 5.0 * scale_factor, bush_w, bush_h), false, depth_tint)

	if tex_rocks.size() > 0:
		var rock_idx = (seed_val + 5) % tex_rocks.size()
		var rock_tex = tex_rocks[rock_idx]
		var rock_w = (85.0 * scale_factor)
		var rock_h = (65.0 * scale_factor)
		var rock_x = (w * 0.5) + (sin(seed_val * 0.1) * w * 0.15 * scale_factor) - rock_w * 0.5
		var rock_y = horizon_y + (h * 0.38 * scale_factor) - rock_h * 0.5
		draw_texture_rect(rock_tex, Rect2(rock_x, rock_y, rock_w, rock_h), false, depth_tint)

func _draw_current_cell_event(pos: Vector2i, w: float, h: float) -> void:
	var tile = _get_tile(pos)
	if tile in [2, 3, 4]:
		_draw_npc_element(Vector2(w * 0.5, h * 0.66), 1.15, tile, Color.WHITE)

func _draw_npc_element(center: Vector2, scale_factor: float, type: int, tint: Color) -> void:
	var clamped_scale = min(1.30, scale_factor)
	var pulse = 1.0 + 0.10 * sin(_anim_time * 3.5)
	
	# Aura mágica de Lótus proporcional
	draw_circle(center + Vector2(0, 10 * clamped_scale), 26 * clamped_scale * pulse, Color(0.95, 0.4, 0.8, 0.25 * tint.a))
	draw_circle(center + Vector2(0, 8 * clamped_scale), 12 * clamped_scale * pulse, Color(1.0, 0.7, 0.9, 0.45 * tint.a))
	
	# Pétalas flutuantes mágicas
	for i in range(4):
		var p_x = center.x + sin(_anim_time * 2.0 + i * 1.3) * 32.0 * clamped_scale
		var p_y = center.y - 15.0 * clamped_scale + cos(_anim_time * 1.8 + i * 1.7) * 14.0 * clamped_scale
		draw_circle(Vector2(p_x, p_y), 3.0 * clamped_scale, Color(1.0, 0.5, 0.85, 0.8 * tint.a))

	# Seleciona a textura do Tripulante Enfeitiçado
	var npc_tex: Texture2D = null
	if type == 4:
		npc_tex = tex_lotus_npc
	elif type in [2, 3]:
		npc_tex = tex_bewitched_crew if tex_bewitched_crew else (tex_crew if tex_crew else tex_lotus_npc)
	else:
		npc_tex = tex_bewitched_crew if tex_bewitched_crew else tex_crew
		
	if npc_tex:
		var img_sz = npc_tex.get_size()
		var aspect = img_sz.x / max(1.0, img_sz.y)
		var spr_h = 140.0 * clamped_scale
		var spr_w = spr_h * aspect
		var spr_rect = Rect2(center.x - spr_w * 0.5, center.y - spr_h * 0.86, spr_w, spr_h)
		draw_texture_rect(npc_tex, spr_rect, false, tint)

func _draw_forward_indicator(pos: Vector2i, fwd: Vector2i, w: float, h: float) -> void:
	var path_fwd_open = (_get_tile(pos + fwd) != 1)
	if path_fwd_open:
		var pulse = 0.85 + 0.15 * sin(_anim_time * 4.0)
		var fwd_center = Vector2(w * 0.5, h * 0.82)
		var fwd_col = Color(1.0, 0.95, 0.5, 0.80 * pulse if not hover_forward else 1.0)
		var font = ThemeDB.fallback_font
		draw_string(font, fwd_center + Vector2(-65, 0), "▲ AVANÇAR [ W / ↑ ]", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, fwd_col)

# -------------------------------------------------------------
# UTILITÁRIOS
# -------------------------------------------------------------

func _is_valid(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < main_station.map_width and pos.y >= 0 and pos.y < main_station.map_height

func _get_tile(pos: Vector2i) -> int:
	if not _is_valid(pos):
		return 1
	return main_station.map[pos.y][pos.x]
