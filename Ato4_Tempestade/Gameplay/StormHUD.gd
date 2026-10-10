extends Control
## UI uses a fitted 1152x648 stage; readable in both windowed and portrait sizes.

var level: Node2D
var font: Font = ThemeDB.fallback_font
var start_button: Button
var retry_button: Button
var map_button: Button
var continue_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_button = _button("ASSUMIR O LEME  ›", Vector2(392, 477), Vector2(368, 48))
	retry_button = _button("TENTAR NOVAMENTE  [R]", Vector2(352, 402), Vector2(448, 48))
	map_button = _button("VOLTAR AO MAPA", Vector2(352, 465), Vector2(448, 48))
	continue_button = _button("ALCANÇAR EÓLIA  ›", Vector2(64, 586), Vector2(320, 42))
	continue_button.hide()
	start_button.pressed.connect(func(): level.start_sailing())
	retry_button.pressed.connect(func(): level.retry())
	map_button.pressed.connect(func(): level.return_to_map())
	continue_button.pressed.connect(func(): level.continue_to_aeolia())
	get_viewport().size_changed.connect(_fit)
	_fit()
	start_button.grab_focus()

func _button(text: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 19)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.14, 0.19)
	style.border_color = Color(0.66, 0.69, 0.48)
	style.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.28, 0.3)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	add_child(button)
	return button

func _fit() -> void:
	var viewport_size := get_viewport_rect().size
	var factor: float = minf(viewport_size.x / 1152.0, viewport_size.y / 648.0)
	scale = Vector2.ONE * factor
	position = (viewport_size - Vector2(1152, 648) * factor) / 2.0

func _process(_delta: float) -> void:
	if not level:
		return
	start_button.visible = level.state == level.State.READY
	var ended: bool = level.state in [level.State.WON, level.State.LOST]
	retry_button.visible = ended
	map_button.visible = ended
	var won: bool = level.state == level.State.WON
	continue_button.visible = won
	retry_button.position = Vector2(420, 586) if won else Vector2(352, 402)
	map_button.position = Vector2(776, 586) if won else Vector2(352, 465)
	retry_button.size = Vector2(312, 42) if won else Vector2(448, 48)
	map_button.size = Vector2(312, 42) if won else Vector2(448, 48)
	queue_redraw()

func label(text: String, at: Vector2, size_px: int = 18, color: Color = Color(0.85, 0.91, 0.9)) -> void:
	draw_string(font, at + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0.02, 0.04, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _draw() -> void:
	if not level:
		return
	var ship: CharacterBody2D = level.ship
	if level.state in [level.State.ARRIVAL, level.State.WON]:
		label("EÓLIA · O DOMÍNIO DE ÉOLO", Vector2(32, 47), 24, Color(0.96, 0.84, 0.55))
		if level.state == level.State.WON:
			_draw_overlay()
		return
	draw_rect(Rect2(20, 20, 270, 112), Color(0.015, 0.04, 0.07, 0.88))
	label("ATO IV  ·  A TEMPESTADE", Vector2(34, 45), 17, Color(0.86, 0.78, 0.52))
	label("CASCO  %d / 100" % ceili(ship.hull), Vector2(34, 75), 19)
	draw_rect(Rect2(34, 86, 240, 12), Color(0.17, 0.22, 0.24))
	draw_rect(Rect2(34, 86, 240 * ship.hull / 100.0, 12), Color(0.32, 0.78, 0.65) if ship.hull > 35 else Color(0.92, 0.35, 0.25))
	label("VELOCIDADE  %d" % absi(int(ship.speed)), Vector2(34, 121), 14)
	var distance: int = 0 if level.state == level.State.WON else maxi(0, int(level.GOAL.x - ship.position.x))
	label("SUPERE A TEMPESTADE", Vector2(344, 40), 20, Color(0.89, 0.87, 0.7))
	label("%d m de travessia restantes" % distance, Vector2(344, 65), 17)
	draw_rect(Rect2(344, 76, 330, 5), Color(0.25, 0.32, 0.35))
	var progress: float = 1.0 if level.state == level.State.WON else clampf((ship.position.x - 320) / (level.GOAL.x - 320), 0, 1)
	draw_rect(Rect2(344, 76, 330 * progress, 5), Color(0.61, 0.84, 0.78))
	draw_rect(Rect2(900, 20, 232, 112), Color(0.015, 0.04, 0.07, 0.88))
	label("VENTO  %d" % int(level.wind.length()), Vector2(920, 48), 17)
	var wind_pos := Vector2(1060, 78)
	var direction: Vector2 = level.wind.normalized() * 25
	draw_line(wind_pos - direction, wind_pos + direction, Color(0.76, 0.87, 0.94), 3)
	draw_line(wind_pos + direction, wind_pos + direction - direction.rotated(0.6) * 0.4, Color(0.76, 0.87, 0.94), 3)
	draw_line(wind_pos + direction, wind_pos + direction - direction.rotated(-0.6) * 0.4, Color(0.76, 0.87, 0.94), 3)
	label("VENTO", Vector2(920, 112), 13)
	if not level.warning.is_empty():
		draw_rect(Rect2(280, 145, 592, 57), Color(0.12, 0.07, 0.04, 0.88))
		label(level.warning, Vector2(299, 181), 19, Color(1, 0.74, 0.42))
	var status := "O mar desgasta o casco. Procure os círculos verdes."
	if ship.calm:
		status = "ÁGUAS CALMAS · Sem dano das ondas. Pare + E para reparar."
	if ship.repairing:
		status = "TRIPULAÇÃO REPARANDO O CASCO  +7,5/s"
	elif ship.braced:
		status = "VELAS RECOLHIDAS · Menos velocidade, impacto e deriva."
	if ship.in_whirlpool:
		status = "REDEMOINHO · ESCAPE DA CORRENTE!  -3 CASCO/s"
	draw_rect(Rect2(20, 552, 1112, 76), Color(0.015, 0.04, 0.07, 0.88))
	label(status, Vector2(35, 580), 18, Color(0.63, 0.89, 0.79) if ship.calm else Color(0.85, 0.91, 0.9))
	label("W/S ou ↑/↓: avançar/frear   A/D ou ←/→: leme   ESPAÇO: recolher velas   E: reparar   ESC: pausa", Vector2(35, 610), 16)
	# Screen-space rain and lightning also freeze with the world.
	for index in range(65):
		var x: float = fposmod(index * 97.0 - level.sea_clock * (80 + level.wind.x * 0.2), 1152)
		var y: float = fposmod(index * 53.0 + level.sea_clock * 490, 648)
		draw_line(Vector2(x, y), Vector2(x + level.wind.x * 0.06 - 5, y + 23), Color(0.61, 0.78, 0.89, 0.19), 1)
	if level.flash > 0:
		draw_rect(Rect2(0, 0, 1152, 648), Color(0.75, 0.87, 1.0, level.flash * 0.3))
	if level.state in [level.State.READY, level.State.LOST]:
		_draw_overlay()

func _draw_overlay() -> void:
	if level.state == level.State.WON:
		draw_rect(Rect2(220, 490, 712, 148), Color(0.025, 0.07, 0.1, 0.93))
		draw_rect(Rect2(220, 490, 712, 148), Color(0.64, 0.68, 0.5), false, 2)
		label("SOB A ILHA DOS VENTOS", Vector2(244, 522), 25, Color(0.96, 0.84, 0.55))
		label("A tempestade ficou para trás. Prenda uma corda para subir.", Vector2(244, 550), 18)
		label("Casco: %d%%  ·  Travessia: %d s" % [ceili(level.ship.hull), int(level.elapsed)], Vector2(244, 573), 15)
		return
	draw_rect(Rect2(0, 0, 1152, 648), Color(0.01, 0.025, 0.05, 0.76))
	draw_rect(Rect2(260, 166, 632, 375), Color(0.025, 0.07, 0.1, 0.98))
	draw_rect(Rect2(260, 166, 632, 375), Color(0.64, 0.68, 0.5), false, 2)
	if level.state == level.State.READY:
		label("ASSUMA O COMANDO", Vector2(312, 218), 30, Color(0.96, 0.84, 0.55))
		label("Resista ao mar até encontrar Eólia no céu.", Vector2(312, 253), 20)
		label("W / ↑: avançar     S / ↓: frear e dar ré", Vector2(312, 302), 19)
		label("A / D ou ← / →: girar o leme", Vector2(312, 337), 19)
		label("ESPAÇO: recolher velas para suportar o impacto", Vector2(312, 372), 19)
		label("Águas verdes: pare e segure E para reparar", Vector2(312, 407), 19)
		label("Ondas podem chegar sem aviso. Desvie dos redemoinhos.", Vector2(312, 446), 18, Color(0.6, 0.88, 0.77))
	else:
		label("O NAVIO AFUNDOU", Vector2(312, 234), 31, Color(0.98, 0.5, 0.37))
		label("Desvie das cristas e proteja o casco com Espaço.", Vector2(312, 281), 19)
		label("Nas águas calmas, pare e use E para recuperar o casco.", Vector2(312, 324), 18)
		label("R: tentar novamente    ·    ESC: pausa", Vector2(312, 365), 17)
