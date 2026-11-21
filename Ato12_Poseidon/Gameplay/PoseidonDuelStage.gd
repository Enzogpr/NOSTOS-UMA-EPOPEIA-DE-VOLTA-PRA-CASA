extends Node2D

const DUEL := preload("res://Ato12_Poseidon/Gameplay/PoseidonDuel.gd")
const WATER_GEOMETRY := preload("res://Ato12_Poseidon/Gameplay/PoseidonWaterGeometry.gd")
const REEF := preload("res://Assets/act12_poseidon/reef.png")
const SEA := preload("res://Assets/act4_released_winds/storm_open_sea.png")
const COLOSSUS := preload("res://Assets/act12_poseidon/poseidon_colossus.png")
const GOD := preload("res://Assets/act12_poseidon/poseidon_duel.png")
const HERO := preload("res://Assets/act5_circe/battle/odysseus_directions.png")
const TRIDENT := preload("res://Assets/act12_poseidon/trident.png")
const BAG := preload("res://Assets/act4_friends/wind_bag.png")
const SOLDIER := preload("res://Assets/act4_poseidon_soldiers/water_soldier_combat.png")
const ARCHER_PICKUP := preload("res://Assets/act12_poseidon/arena_archer_pickup.png")
const WATER_VFX := preload("res://Assets/act12_poseidon/arena_water_vfx.png")
const DASH_BAR := preload("res://Code/DashRechargeBar.gd")
const VIEW := Vector2(1152, 648)
const FOAM := Color("c5ebe5")
const GOLD := Color("efd59c")
const GOD_RECTS := [Rect2(104,30,454,556),Rect2(640,82,600,498),Rect2(50,786,554,407),Rect2(702,623,535,574)]
const SOLDIER_RECTS := [Rect2(0,0,627,440),Rect2(627,0,627,440),Rect2(0,440,627,430),Rect2(627,440,627,430),Rect2(0,870,657,384),Rect2(657,870,597,384)]
const SOLDIER_FEET := [Vector2(312,432),Vector2(275,432),Vector2(321,423),Vector2(262,423),Vector2(320,367),Vector2(227,367)]

var duel: DUEL
var time := 0.0
var camera_x := 0.0
var pose := 0
var old_pose := 0
var blend := 1.0
var impact := 0.0
var dash_bar := DASH_BAR.new()

func _ready() -> void:
	add_child(dash_bar)

func visible_phase() -> int:
	return duel.lost_from if duel.phase == DUEL.Phase.LOST else duel.phase

func player_feet() -> Vector2:
	return duel.position

func advance(delta: float) -> void:
	time = duel.clock
	impact = maxf(0, impact - delta)
	var attacking := duel.finisher or (duel.state == DUEL.State.STRIKE and duel.state_age > 0.30 and duel.state_age < 1.55)
	var next_pose := 3 if duel.boss_flash > 0 else 2 if duel.state == DUEL.State.EXPOSED else 1 if attacking else 0
	if visible_phase() == DUEL.Phase.DISARM:
		next_pose = 3 if duel.trident_dropped else 1
	if next_pose != pose:
		old_pose = pose
		pose = next_pose
		blend = 0.0
	blend = minf(1, blend + delta * 7)
	dash_bar.update_at(duel.position, duel.dash_recharge, duel.dash_recharge_duration(), duel.active())
	queue_redraw()

func on_cue(kind: StringName) -> void:
	if kind in [&"boss_hit", &"disarm", &"unleash", &"duel_start"]:
		impact = 0.24 if kind == &"boss_hit" else 0.45

func _draw() -> void:
	var current := visible_phase()
	var storm := duel.storm
	_draw_sea(storm)
	if current in [DUEL.Phase.READY, DUEL.Phase.SURGE, DUEL.Phase.GUARDS, DUEL.Phase.DISARM, DUEL.Phase.UNLEASH]:
		_draw_colossus()
	_draw_floor(storm)
	_draw_health_pickups()
	for hazard in duel.hazards:
		_draw_hazard(hazard)
	if current in [DUEL.Phase.SURGE, DUEL.Phase.DISARM] and duel.state == DUEL.State.EXPOSED:
		_draw_weakpoint()
	if current == DUEL.Phase.DISARM:
		_draw_disarm_trident()
	# Feet share one depth order, including the foreground god in the final duel.
	var actors: Array[Dictionary] = [{"kind":"hero", "y":duel.position.y}]
	for enemy in duel.guards.enemies:
		actors.append({"kind":"soldier", "y":enemy.position.y, "enemy":enemy})
	if current in [DUEL.Phase.DUEL, DUEL.Phase.ENDING, DUEL.Phase.WON]:
		actors.append({"kind":"boss", "y":duel.boss.y})
	actors.sort_custom(func(a, b): return a.y < b.y)
	for actor in actors:
		match actor.kind:
			"hero": _draw_player()
			"soldier": _draw_soldier(actor.enemy)
			"boss": _draw_boss()
	if current == DUEL.Phase.DUEL and duel.state == DUEL.State.STRIKE:
		_draw_duel_strike()
	_draw_arrows()
	for shot in duel.projectiles:
		var at: Vector2 = shot.position - Vector2(0, 36)
		_wake(at, shot.direction, true)
		draw_arc(at, 17, -time * 9, -time * 9 + 4.8, 19, Color(FOAM, 0.92), 3.1, true)
		draw_arc(at, 10, time * 12, time * 12 + 4.2, 16, Color.WHITE, 2, true)
	_draw_guard_health()
	_draw_weather(storm)
	_draw_progress()
	if duel.last_boss_damage > 0 and time < duel.boss_damage_until:
		var remaining := duel.boss_damage_until-time
		var at := duel.boss_damage_at+Vector2(60,-126-(0.75-remaining)*27)
		var text := "−%d" % duel.last_boss_damage
		draw_string(ThemeDB.fallback_font,at+Vector2(1,1),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(0.02,0.07,0.10,minf(1,remaining*4)))
		draw_string(ThemeDB.fallback_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color(GOLD,minf(1,remaining*4)))
	if duel.phase == DUEL.Phase.UNLEASH:
		_draw_unleash()
	if impact > 0:
		draw_rect(Rect2(Vector2.ZERO, VIEW), Color(FOAM, impact * impact * 0.42))
	if duel.hit_flash > 0:
		draw_rect(Rect2(0, 0, 1152, 7), Color(0.72, 0.14, 0.10, duel.hit_flash))

func _draw_sea(storm: float) -> void:
	var pan := sin(time * (0.25 + storm * 0.45)) * (8 + storm * 7)
	draw_texture_rect(SEA, Rect2(-25 + pan, -18, 1202, 685), false, Color("b6c6ca").lerp(Color("596f89"), storm * 0.84))
	# The island progressively vanishes as the whole bag empties.
	if storm < 0.99:
		draw_texture_rect_region(REEF, Rect2(0, 72, 1152, 215), Rect2(0, 0, REEF.get_width(), REEF.get_height() * 0.35), Color(0.84,0.91,0.96,(1-storm)*0.82))
	for n in 5:
		var points := PackedVector2Array()
		for i in 31:
			var x := i * 40.0
			points.append(Vector2(x, 100 + n * 32 + sin(x * 0.007 + time * (0.23 + storm * 0.48) + n) * 14))
		points.append_array(PackedVector2Array([Vector2(1200, 0), Vector2(0, 0)]))
		draw_colored_polygon(points, Color(0.025,0.055,0.095,0.06 + storm * 0.075))
	for n in 10:
		var y := 245 + n * 10
		_ripple(Vector2(fposmod(n * 193 - time * (25 + storm * 43), 1280) - 64, y), 123, 0.12 + storm * 0.12, n)

func _draw_colossus() -> void:
	var cell := COLOSSUS.get_size() * 0.5
	var at := Vector2(576 + sin(time * 0.75) * 12 + clampf((duel.position.x - 576) * 0.026, -12, 12), 596 + sin(time * 1.6) * 3)
	for entry in [[old_pose,1-smoothstep(0,1,blend)],[pose,smoothstep(0,1,blend)]]:
		if entry[1] < 0.005:
			continue
		var region := Rect2(Vector2(int(entry[0]) % 2, int(entry[0]) / 2) * cell, cell)
		var opacity := 1.0 - smoothstep(0.6,4.6,duel.state_age) if duel.phase == DUEL.Phase.UNLEASH and duel.bag_emptied else 1.0
		_sprite_at(COLOSSUS, region, at, 552, Color(0.92,0.97,1,float(entry[1])*opacity))
	if duel.phase == DUEL.Phase.GUARDS and not duel.trident_dropped:
		_weapon(Vector2(820, 292), PI * 0.47, 279)

func _draw_floor(storm: float) -> void:
	# Reuse the complete painted rock edge, so the arena has actual sea-level support.
	var source := Rect2(0, REEF.get_height() * 0.37, REEF.get_width(), REEF.get_height() * 0.63)
	draw_texture_rect_region(REEF, Rect2(0, 337, 1152, 311), source, Color("c5d0d0").lerp(Color("8a9fad"), storm * 0.65))
	for n in 6:
		_ripple(Vector2(120+n*177, 611 + sin(time*2+n)*5), 89, 0.22+storm*0.14, n)

func _draw_weakpoint() -> void:
	var at := duel.wind_point - Vector2(0, 36)
	var available := duel.phase in [DUEL.Phase.SURGE,DUEL.Phase.DISARM]
	var pulse := 0.5 + sin(time * 7) * 0.15
	for n in 3:
		_ripple(at + Vector2(0,n*5), 66+n*21, (0.45 if available else 0.15)*pulse, n)
	if available and not duel.opening_used:
		draw_arc(at, 25, time * 3, time * 3 + 4.9, 27, Color(FOAM,0.86), 2.1, true)
		for n in 4:
			var theta := n*PI*0.5 + time
			var offset := Vector2.from_angle(theta) * 34
			draw_line(at+offset, at+offset*0.77, Color(FOAM,0.8), 1.6, true)

func _draw_disarm_trident() -> void:
	var anchored := Vector2(440,284)
	if not duel.trident_dropped:
		var u := smoothstep(0,1.25,duel.disarm_age)
		_weapon(Vector2(820,292).lerp(anchored,u),lerpf(PI*0.47,1.8,u),lerpf(279,245,u))
		if u > 0.95:
			_ripple(Vector2(411,397),59,0.35,2)
	else:
		var u := smoothstep(0,0.8,duel.release_age)
		var at := anchored.lerp(duel.trident-Vector2(0,16),u)-Vector2(0,sin(u*PI)*44)
		_weapon(at,lerpf(1.8,-0.20,u),lerpf(245,142,u))
		if u >= 0.99:
			_ripple(duel.trident,85,0.48,4)

func _draw_progress() -> void:
	var current := visible_phase()
	if current == DUEL.Phase.SURGE:
		for n in int(duel.config.barrier_seals):
			var at := Vector2((VIEW.x-(int(duel.config.barrier_seals)*35-7))*0.5+n*35,94)
			draw_rect(Rect2(at,Vector2(28,4)),Color(0.1,0.26,0.31,0.8))
			if n >= duel.barrier_hits:
				draw_rect(Rect2(at,Vector2(28,4)),Color("8bd4df"))
	elif current == DUEL.Phase.GUARDS:
		for n in int(duel.config.guard_formations):
			var at := Vector2((VIEW.x-(int(duel.config.guard_formations)*48-9))*0.5+n*48,94)
			draw_rect(Rect2(at,Vector2(39,4)),Color("4a4938") if n < duel.anchor_hits else GOLD)
	elif current == DUEL.Phase.DUEL:
		draw_rect(Rect2(376,94,400,5),Color("142732"))
		draw_rect(Rect2(376,94,400*float(duel.boss_hp)/duel.boss_max_hp,5),Color("6fb4d0"))
		draw_string(ThemeDB.fallback_font,Vector2(785,101),"%d / %d" % [duel.boss_hp,duel.boss_max_hp],HORIZONTAL_ALIGNMENT_LEFT,-1,12,FOAM)

func _draw_hazard(hazard: Dictionary) -> void:
	var age: float = hazard.age
	var lead: float = hazard.lead
	var rect: Rect2 = hazard.rect
	if age < 0:
		return
	var at := rect.get_center() - Vector2(0, 28)
	var build := smoothstep(0, lead, age)
	var fade := 1 - smoothstep(lead + hazard.hold, lead + hazard.hold + 0.42, age)
	if hazard.kind == "tide" and age < lead:
		var before := 1.0 if age >= lead else build * 0.5
		for section in [Vector2(DUEL.ARENA.position.y, hazard.gap-hazard.gap_size*0.5),Vector2(hazard.gap+hazard.gap_size*0.5,DUEL.ARENA.end.y)]:
			var height: float = section.y - section.x
			_draw_breaking_wave(Vector2(at.x,(section.x+section.y)*0.5-25),Vector2(74,height+18),0.95,fade*before)
		return
	if age < lead:
		var lines := 3 if rect.size.x < 130 else maxi(3,int(rect.size.x/60))
		for n in lines:
			var center := Vector2(rect.position.x + rect.size.x*(n+0.5)/lines, rect.get_center().y-12)
			_ripple(center, minf(84,rect.size.x/lines+18), build*0.49, n)
		if hazard.kind in ["rain","breaker"]:
			for n in maxi(3,int(rect.size.x/40)):
				var x := rect.position.x + rect.size.x*(n+0.5)/maxi(3,int(rect.size.x/40))
				draw_line(Vector2(x,338),Vector2(x+sin(time*4+n)*5,365-build*24),Color(FOAM,build*0.27),2,true)
		return
	_draw_parts(WATER_GEOMETRY.hazard_parts(hazard,time))

func _draw_player() -> void:
	var at := duel.position
	if duel.dash_left > 0:
		_wake(at,duel.dash_direction,false)
	_draw_hero(at,88,Color("f0a899") if duel.hit_flash > 0 else Color.WHITE,duel.dash_direction.x*0.12 if duel.dash_left > 0 else 0)
	if duel.has_trident:
		var direction := duel.attack_direction if duel.attack_age >= 0 else duel.look
		_weapon(at-Vector2(0,38)+direction*duel.trident_extension(),direction.angle(),132)
	elif duel.phase != DUEL.Phase.ENDING:
		draw_texture_rect(BAG,Rect2(at+Vector2(19,-51),Vector2(29,36)),false,Color("d6cfa9"))
		for n in DUEL.WIND_MAX:
			draw_circle(at+Vector2(27+n*7,-57),1.9,Color(FOAM,0.9 if n<duel.wind_charges else 0.16))
	if duel.attack_age >= 0:
		var u := clampf(duel.attack_age/(0.48 if duel.has_trident else 0.39),0,1)
		var theta := duel.attack_direction.angle()+lerpf(-0.95,0.95,u)
		draw_arc(at-Vector2(0,36),DUEL.TRIDENT_REACH if duel.has_trident else DUEL.SWORD_REACH,theta-0.3,theta+0.1,19,Color(FOAM,(1-u)*0.68),2.1,true)
	if duel.defend:
		draw_arc(at-Vector2(0,38)+duel.look*12,25,duel.look.angle()-0.8,duel.look.angle()+0.8,17,Color(GOLD,0.8),2,true)

func _draw_soldier(enemy: Dictionary) -> void:
	if enemy.role == "archer":
		_draw_archer(enemy)
		return
	var age: float = enemy.age
	var state: String = enemy.state
	var pose_index := 0
	match state:
		"approach": pose_index = 1 if fmod(time*2.8+enemy.id*0.3,1)>0.46 else 0
		"windup": pose_index = 2
		"strike": pose_index = 3 if enemy.attacks % 2 == 0 else 4
		"stagger", "dead": pose_index = 5
	var alpha := 1-smoothstep(0.1,1.05,age) if state == "dead" else smoothstep(0,0.95,age) if state == "arrive" else 1.0
	if alpha < 0.005:
		return
	var at: Vector2 = enemy.position
	var scale_factor := 0.235 if enemy.elite else 0.21
	var face := -1 if enemy.facing.x < 0 else 1
	var bob := -absf(sin(time*7.7+enemy.id))*1.7 if state == "approach" else sin(time*2.8+enemy.id)*0.8
	var collapse := 1-smoothstep(0.1,1.0,age)*0.8 if state == "dead" else 1.0
	var region: Rect2 = SOLDIER_RECTS[pose_index]
	var feet: Vector2 = SOLDIER_FEET[pose_index]
	var tint := Color(0.82,0.96,1,alpha) if enemy.elite else Color(0.69,0.89,1,alpha)
	if enemy.flash > 0:
		tint = Color(0.94,1,1,alpha)
	_ripple(at,49,alpha*0.28,int(enemy.id))
	draw_set_transform(at+Vector2(0,bob),face*0.025*sin(age*5) if state=="strike" else 0,Vector2(face*scale_factor,scale_factor*collapse))
	draw_texture_rect_region(SOLDIER,Rect2(-feet,region.size),region,tint)
	draw_set_transform(Vector2.ZERO)
	if state in ["strike","windup"]:
		var segment := WATER_GEOMETRY.soldier_segment(enemy)
		draw_line(segment[0],segment[1],Color(FOAM,alpha*0.68),3,true)
	if enemy.elite and (enemy.armor_flash > 0 or state in ["approach","windup"]):
		var direction: Vector2 = enemy.facing
		draw_arc(at-Vector2(0,37)+direction*12,25,direction.angle()-0.77,direction.angle()+0.77,16,Color(FOAM,0.85 if enemy.armor_flash > 0 else 0.27),2,true)

func _draw_archer(enemy: Dictionary) -> void:
	var frame := 1 if enemy.state=="approach" else 2 if enemy.state=="aim" else 3 if enemy.state=="shoot" else 4 if enemy.state=="dead" else 0
	var alpha := 1-smoothstep(0.1,1.05,enemy.age) if enemy.state=="dead" else smoothstep(0,1.05,enemy.age) if enemy.state=="arrive" else 1.0
	if alpha <= 0.005:return
	var at: Vector2 = enemy.position
	var face := -1 if enemy.facing.x < 0 else 1
	var bob := -absf(sin(time*7))*1.4 if enemy.state=="approach" else sin(time*2.5)*0.8
	var tint := Color(0.76,0.95,1,alpha)
	if enemy.flash > 0:tint=Color(0.95,1,1,alpha)
	var source := Rect2(Vector2(frame%3,frame/3)*512,Vector2(512,512))
	_ripple(at,47,alpha*0.25,int(enemy.id))
	draw_set_transform(at+Vector2(0,bob),0,Vector2(face,1))
	draw_texture_rect_region(ARCHER_PICKUP,Rect2(-48,-90,96,96),source,tint)
	draw_set_transform(Vector2.ZERO)

func _draw_arrows() -> void:
	for arrow in duel.guards.arrows:
		if arrow.spent:continue
		var segment := WATER_GEOMETRY.arrow_segment(arrow)
		var direction: Vector2 = arrow.direction
		var normal := direction.orthogonal()
		draw_line(segment[0],segment[1],Color("b4e9ef"),2.5,true)
		var tip: Vector2 = segment[1]
		draw_colored_polygon(PackedVector2Array([tip,tip-direction*10+normal*4,tip-direction*10-normal*4]),Color("e3f7f5"))
		for side in [-1,1]:
			draw_line(segment[0]+direction*8,segment[0]+normal*side*4,Color("6ab8ce"),1.6,true)

func _draw_health_pickups() -> void:
	if visible_phase() in [DUEL.Phase.ENDING,DUEL.Phase.WON]:return
	for pickup in duel.health_pickups:
		if pickup.collected:continue
		var at: Vector2 = pickup.position
		draw_set_transform(at,0,Vector2(1,0.28))
		draw_circle(Vector2.ZERO,23,Color(0.17,0.62,0.32,0.13+sin(time*3)*0.035))
		draw_set_transform(Vector2.ZERO)
		var bob := sin(time*2.7+pickup.id)*1.7
		draw_texture_rect_region(ARCHER_PICKUP,Rect2(at+Vector2(-18,-44+bob),Vector2(36,44)),Rect2(1120,575,320,390))
		var text_at := at+Vector2(-11,-50+bob)
		draw_string(ThemeDB.fallback_font,text_at+Vector2(1,1),"+%d"%pickup.amount,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("071a16"))
		draw_string(ThemeDB.fallback_font,text_at,"+%d"%pickup.amount,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a2efaa"))

func _draw_guard_health() -> void:
	for enemy in duel.guards.enemies:
		if enemy.hp <= 0:
			continue
		var alpha := smoothstep(0,0.95,enemy.age) if enemy.state == "arrive" else 1.0
		var at: Vector2 = enemy.position-Vector2(24,116 if enemy.elite else 104)
		draw_rect(Rect2(at,Vector2(48,4)),Color(0.06,0.15,0.21,alpha))
		draw_rect(Rect2(at,Vector2(48*float(enemy.hp)/enemy.max_hp,4)),Color(0.47,0.86,0.91,alpha))

func _draw_boss() -> void:
	var terminal := visible_phase() in [DUEL.Phase.ENDING,DUEL.Phase.WON]
	var vulnerable := duel.boss_vulnerable()
	var pose_index := 2 if terminal or vulnerable or duel.boss_flash > 0 else 1 if duel.state==DUEL.State.STRIKE else 3 if duel.state==DUEL.State.WINDUP and duel.move==DUEL.Move.WAVE else 0
	var at := duel.boss
	var face := 1 if duel.position.x < at.x else -1
	var lean := face*sin(clampf(duel.state_age/duel.strike_time(),0,1)*PI)*0.055 if duel.state==DUEL.State.STRIKE else 0.0
	draw_set_transform(at+Vector2(0,sin(time*2.2)*1.5),lean,Vector2(face,1))
	var tint := Color("e9b9b3") if duel.boss_flash>0 else Color("c4d9e2")
	if vulnerable and duel.boss_flash<=0:tint=Color("e4d3af")
	if duel.phase == DUEL.Phase.DUEL:
		tint.a = smoothstep(0,1.1,duel.phase_age)
	_sprite_at(GOD,GOD_RECTS[pose_index],Vector2.ZERO,146 if terminal or vulnerable else 168,tint)
	draw_set_transform(Vector2.ZERO)
	if terminal:
		return
	if vulnerable:
		_ripple(at+Vector2(0,3),87,0.48,1)
	elif duel.phase == DUEL.Phase.DUEL:
		var direction := at.direction_to(duel.position)
		draw_arc(at-Vector2(0,58)+direction*14,40,direction.angle()-1.0,direction.angle()+1.0,23,Color(FOAM,0.32),2.2,true)
	for n in 3:
		_ripple(at+Vector2(0,n*5),61+n*14,0.2,n)
	if duel.state==DUEL.State.WINDUP:
		_ripple(at,82+duel.state_age*37,0.46,3)

func _draw_duel_strike() -> void:
	if duel.move==DUEL.Move.WAVE:
		_draw_parts(WATER_GEOMETRY.wave_parts(duel.wave_x(),duel.wave_gap_y(),DUEL.ARENA,time))
		return
	var tip := duel.thrust_tip() if duel.move==DUEL.Move.THRUST else duel.sweep_tip()
	_draw_parts(WATER_GEOMETRY.duel_parts(duel.strike_origin,tip,time))

func _draw_parts(parts: Array[Dictionary]) -> void:
	for part in parts:
		draw_set_transform(part.origin,part.angle)
		_effect(part.frame,part.rect,part.opacity)
	draw_set_transform(Vector2.ZERO)

func _draw_weather(storm: float) -> void:
	_rain(0.20+storm*0.77)
	if storm <= 0.02:
		return
	for n in 34:
		var x := fposmod(n*77.3-time*335,1210)-30
		var y := 70+fposmod(n*39.7+time*18,550)
		draw_line(Vector2(x,y),Vector2(x-43-storm*35,y+9),Color(FOAM,storm*(0.035+n%3*0.014)),1,true)
	var lightning := fposmod(time,7.7)
	if lightning < 0.16:
		var seed := int(time/7.7)%3
		var x := 177+seed*371
		var bolt := PackedVector2Array([Vector2(x,70),Vector2(x-35,134),Vector2(x+4,157),Vector2(x-44,229),Vector2(x-13,217),Vector2(x-58,304)])
		draw_polyline(bolt,Color(0.64,0.84,1,storm*(1-lightning/0.16)),2.8,true)
	if duel.wind_force.length()>4:
		for n in 4:
			var side := signf(duel.wind_force.x)
			_wake(Vector2(576+n*113,405+n*43),Vector2(side,0),false)

func _draw_unleash() -> void:
	var at := duel.position-Vector2(0,44)
	if not duel.bag_emptied:
		draw_texture_rect(BAG,Rect2(at-Vector2(20,24),Vector2(40,49)),false)
		if duel.bag_untying>0:
			draw_arc(at,33,-PI*0.5,-PI*0.5+TAU*duel.bag_untying/2.3,39,Color(FOAM,0.9),2.4,true)
		# Poseidon's approaching wall is physical scenery, prior to the released storm.
		_draw_breaking_wave(Vector2(576,350),Vector2(1130,90+duel.phase_age*4),0.85,minf(0.80,duel.phase_age*0.06))
	else:
		var u := clampf(duel.state_age/4.0,0,1)
		if duel.state_age < 1.0:
			var bag_at := at + Vector2(-27,duel.state_age*18)
			draw_texture_rect(BAG,Rect2(bag_at-Vector2(20,25),Vector2(40,50)),false,Color(1,1,1,1-duel.state_age))
			draw_set_transform(bag_at-Vector2(0,17),0,Vector2(1,0.45))
			draw_circle(Vector2.ZERO,8,Color(0.04,0.12,0.16,1-duel.state_age))
			draw_set_transform(Vector2.ZERO)
			for side in [-1,1]:
				var ribbon := PackedVector2Array([bag_at+Vector2(0,-19),bag_at+Vector2(side*(12+u*44),-26-u*22),bag_at+Vector2(side*(23+u*74),-18-u*42)])
				draw_polyline(ribbon,Color(GOLD,1-duel.state_age),1.6,true)
		for n in 9:
			var theta := n*TAU/9+time*0.45
			_wake(at+Vector2.from_angle(theta)*u*460,Vector2.from_angle(theta),true)
		draw_rect(Rect2(Vector2.ZERO,VIEW),Color(0.60,0.83,0.91,sin(u*PI)*0.13))

func _effect(frame: int, target: Rect2, opacity: float) -> void:
	var cells := WATER_GEOMETRY.CELLS
	draw_texture_rect_region(WATER_VFX,target,cells[frame],Color(0.86,0.97,1,clampf(opacity,0,1)))

func _draw_breaking_wave(at: Vector2, size: Vector2, power: float, opacity: float) -> void:
	_draw_parts([WATER_GEOMETRY.breaker(at,size,power,opacity,time)])

func _draw_hero(at: Vector2, height: float, tint: Color, tilt: float = 0.0) -> void:
	var facing := duel.facing
	var row := 1 if facing.y < -0.57 else 0 if facing.y > 0.57 else 2
	var frame: int = [0, 1, 0, 2][posmod(int(time * 11), 4)] if duel.velocity.length() > 18 else 0
	if duel.attack_age >= 0.0:
		row = 3
		frame = mini(2, int(duel.attack_age * 13))
	var cell := HERO.get_size() / 4.0
	draw_set_transform(at + Vector2(0, 3), 0, Vector2(1, 0.27))
	draw_circle(Vector2.ZERO, height * 0.2, Color(0.04, 0.12, 0.14, 0.43))
	draw_set_transform(at, tilt, Vector2(-1 if row in [2, 3] and facing.x < 0 else 1, 1))
	draw_texture_rect_region(HERO, Rect2(-height * 0.5, -height, height, height), Rect2(Vector2(frame, row) * cell, cell), tint)
	draw_set_transform(Vector2.ZERO)


func _wake(at: Vector2, direction: Vector2, wind: bool) -> void:
	for n in 13:
		var width := (n - 6) * 4.8
		var distance := fposmod(time * 440 + n * 19, 102)
		var start := at - direction * distance + direction.orthogonal() * width - Vector2(0, 27)
		draw_line(start, start - direction * (37 + (1 - absf(width) / 34) * 53), Color(FOAM, 0.50 if wind else 0.21), 1.25 + n % 3 * 0.5, true)


func _ripple(at: Vector2, width: float, opacity: float, seed: int) -> void:
	var line := PackedVector2Array()
	for n in 22:
		var u := n / 21.0
		line.append(at + Vector2((u - 0.5) * width, sin(u * TAU + time * 4.6 + seed) * 2.4))
	draw_polyline(line, Color(FOAM, opacity), 1.7, true)


func _rain(power: float) -> void:
	for n in 85:
		var at := Vector2(fposmod(n * 91.7 - time * 117, 1178), fposmod(n * 59.1 + time * 412, 679))
		draw_line(at, at + Vector2(-7, 17 + n % 7), Color(0.73, 0.86, 0.90, power * (0.11 + n % 4 * 0.04)), 1.0, true)


func _weapon(at: Vector2, angle: float, length: float) -> void:
	draw_set_transform(at, angle)
	draw_texture_rect_region(TRIDENT, Rect2(-length * 0.5, -length * 0.084, length, length * 0.168), Rect2(30, 181, 2114, 353))
	draw_set_transform(Vector2.ZERO)


func _sprite_at(texture: Texture2D, region: Rect2, feet: Vector2, height: float, tint: Color = Color.WHITE) -> void:
	var width := height * region.size.x / region.size.y
	draw_texture_rect_region(texture, Rect2(feet - Vector2(width * 0.5, height), Vector2(width, height)), region, tint)
