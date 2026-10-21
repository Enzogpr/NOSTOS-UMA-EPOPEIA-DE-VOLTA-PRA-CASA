extends RefCounted
## Poseidon forms water soldiers on the intact deck. Positions mark their feet.
## No contact damage: water tridents only collide during their authored strike interval.
const SWORD_WINDUP := 0.075
const SWORD_ACTIVE := 0.12
const SWORD_DURATION := 0.46
const SWORD_REACH := 96.0
const ENEMY_HEIGHT := 108.0
const PLAYER_HEIGHT := 76.0
const CROUCH_HEIGHT := 52.0

var deck := Rect2()
var enemies: Array[Dictionary] = []
var active := false
var cleared := false
var elapsed := 0.0
var kills := 0
var attack_count := 0
var wave := 1
var player_attack_age := -1.0
var player_attack_facing := 1.0
var player_guarding := false
var player_combo := 0
var player_attack_crouched := false
var player_attack_hits: Array[int] = []
var previous_attack := false
var hurt_cooldown := 0.0
var champion_delay := -1.0
var strike_count := 0
var blocked_count := 0

func setup(surface: Rect2) -> void:
	deck=surface
	enemies.clear()
	active=true
	cleared=false
	elapsed=0.0
	kills=0
	attack_count=0
	wave=1
	player_attack_age=-1.0
	player_guarding=false
	player_combo=0
	player_attack_hits.clear()
	previous_attack=false
	hurt_cooldown=0.0
	champion_delay=-1.0
	strike_count=0
	blocked_count=0
	_spawn(0,deck.position.x+680,3,0)
	_spawn(1,deck.position.x+1190,3,1)

func _spawn(id: int, x: float, hp: int, variant: int) -> void:
	enemies.append({"id":id,"position":Vector2(x,deck.position.y),"facing":-1.0,"hp":hp,"max_hp":hp,"state":"arrive","age":0.0,"kind":"sweep","target_x":x,"strike_serial":0,"flash":0.0,"variant":variant,"attack_index":0,"hit_player":false})

func tick(dt: float, player_position: Vector2, facing: float, grounded: bool, crouching: bool, attack: bool, guard: bool) -> Dictionary:
	var result: Dictionary={"damage":0.0,"side":0.0,"cue":""}
	if not active or dt<=0.0: return result
	elapsed+=dt
	hurt_cooldown=maxf(0.0,hurt_cooldown-dt)
	var attack_edge: bool=attack and not previous_attack
	previous_attack=attack
	if player_attack_age>=0:
		player_attack_age+=dt
		if player_attack_age>=SWORD_DURATION: player_attack_age=-1.0
	player_guarding=guard and grounded and player_attack_age<0
	if attack_edge and player_attack_age<0 and not guard:
		player_attack_age=0.0
		player_attack_facing=-1.0 if facing<0 else 1.0
		player_attack_crouched=crouching
		player_attack_hits.clear()
		player_combo=player_combo%3+1
		attack_count+=1
		result.cue="sword_swing"
	if player_attack_age>=SWORD_WINDUP and player_attack_age<SWORD_WINDUP+SWORD_ACTIVE:
		var sword:=attack_rect(player_position)
		for enemy in enemies:
			if int(enemy.hp)<=0 or enemy.state=="arrive" or int(enemy.id) in player_attack_hits: continue
			if not sword.intersects(enemy_rect(enemy)): continue
			player_attack_hits.append(int(enemy.id))
			enemy.hp=int(enemy.hp)-1
			enemy.flash=0.18
			result.cue="sword_hit"
			if int(enemy.hp)<=0:
				enemy.state="dead"
				enemy.age=0.0
				kills+=1
				result.cue="water_fall"
			elif enemy.state in ["approach","recover","stagger"]:
				# A committed trident swing retains its momentum through a sword hit.
				# Otherwise repeated attacks could lock a soldier in permanent stagger.
				enemy.state="stagger"
				enemy.age=0.0
				enemy.position.x=clampf(float(enemy.position.x)+player_attack_facing*15,deck.position.x+75,deck.end.x-75)
	for enemy in enemies:
		enemy.age=float(enemy.age)+dt
		enemy.flash=maxf(0.0,float(enemy.flash)-dt)
		match str(enemy.state):
			"dead": pass
			"arrive":
				if float(enemy.age)>=0.65+float(enemy.variant)*0.12: _state(enemy,"approach")
			"stagger":
				if float(enemy.age)>=0.20: _state(enemy,"approach")
			"approach":
				var dx: float=player_position.x-float(enemy.position.x)
				if absf(dx)>2: enemy.facing=signf(dx)
				if absf(dx)>126:
					var speed: float=90.0 if int(enemy.variant)<2 else 110.0
					var step_x: float=clampf(float(enemy.position.x)+signf(dx)*minf(absf(dx)-126,speed*dt),deck.position.x+75,deck.end.x-75)
					if _approach_is_clear(enemy,step_x): enemy.position.x=step_x
				elif absf(player_position.y-deck.position.y)<180:
					_begin_swing(enemy,player_position.x)
			"windup":
				if float(enemy.age)>=windup_duration(enemy):
					_state(enemy,"strike")
					enemy.hit_player=false
					strike_count+=1
			"strike":
				if not bool(enemy.hit_player) and float(enemy.age)<=0.17:
					var body:=Rect2(player_position-Vector2(14,CROUCH_HEIGHT if crouching else PLAYER_HEIGHT),Vector2(28,CROUCH_HEIGHT if crouching else PLAYER_HEIGHT))
					if strike_rect(enemy).intersects(body):
						enemy.hit_player=true
						if hurt_cooldown<=0:
							var toward: float=signf(float(enemy.position.x)-player_position.x)
							var guarded: bool=player_guarding and facing*toward>0
							var heavy: bool=enemy.kind=="overhead"
							result.damage=8.0 if guarded and heavy else 0.0 if guarded else 25.0 if heavy else 20.0
							result.side=-toward if toward!=0 else float(enemy.facing)
							result.cue="guard" if guarded else "water_hit"
							hurt_cooldown=0.65
							if guarded: blocked_count+=1
				if float(enemy.age)>=0.20: _state(enemy,"recover")
			"recover":
				if float(enemy.age)>=recovery_duration(enemy): _state(enemy,"approach")
	if kills==2 and wave==1 and champion_delay<0:
		champion_delay=1.1
	if champion_delay>=0:
		champion_delay-=dt
		if champion_delay<=0:
			champion_delay=-1
			wave=2
			# Enter from the opposite side, safely inside the surviving ship.
			var spawn_x: float=deck.end.x-190 if player_position.x<deck.get_center().x else deck.position.x+190
			_spawn(2,spawn_x,5,2)
	if kills>=3:
		active=false
		cleared=true
		player_attack_age=-1.0
		player_guarding=false
		result.cue="boarding_clear"
	return result

func _approach_is_clear(enemy: Dictionary, next_x: float) -> bool:
	# Preserve committed attack positions; only approaching feet choose a lane.
	# The follower waits behind the leading soldier rather than occupying its torso.
	for other in enemies:
		if int(other.id)==int(enemy.id) or int(other.hp)<=0: continue
		var separation: float=absf(next_x-float(other.position.x))
		if separation<78.0 and separation<absf(float(enemy.position.x)-float(other.position.x)):
			return false
	return true

func _state(enemy: Dictionary, next: String) -> void:
	enemy.state=next
	enemy.age=0.0

func _begin_swing(enemy: Dictionary, target_x: float) -> void:
	var patterns: Array=["sweep","hook"] if int(enemy.variant)==0 else ["overhead","hook"] if int(enemy.variant)==1 else ["overhead","sweep","hook"]
	enemy.kind=patterns[int(enemy.attack_index)%patterns.size()]
	enemy.attack_index=int(enemy.attack_index)+1
	enemy.strike_serial=int(enemy.strike_serial)+1
	enemy.target_x=clampf(target_x,float(enemy.position.x)-155,float(enemy.position.x)+155)
	enemy.facing=-1.0 if target_x<float(enemy.position.x) else 1.0
	enemy.hit_player=false
	_state(enemy,"windup")

func windup_duration(enemy: Dictionary) -> float:
	return 0.78 if str(enemy.kind)=="overhead" else 0.61 if str(enemy.kind)=="sweep" else 0.53

func recovery_duration(enemy: Dictionary) -> float:
	return (1.05 if str(enemy.kind)=="overhead" else 0.80)-0.08*float(enemy.variant)

func enemy_rect(enemy: Dictionary) -> Rect2:
	var height: float=122.0 if int(enemy.variant)==2 else ENEMY_HEIGHT
	var width: float=50.0 if int(enemy.variant)==2 else 44.0
	return Rect2(enemy.position-Vector2(width*0.5,height),Vector2(width,height))

func attack_rect(player_position: Vector2) -> Rect2:
	var height:=42.0 if player_attack_crouched else 50.0
	var y:=player_position.y-(48.0 if player_attack_crouched else 78.0)
	var x:=player_position.x+9.0 if player_attack_facing>0 else player_position.x-SWORD_REACH-9.0
	return Rect2(x,y,SWORD_REACH,height)

func strike_rect(enemy: Dictionary) -> Rect2:
	var x: float=float(enemy.position.x)
	var direction: float=float(enemy.facing)
	var left: float=x+16 if direction>0 else x-138
	match str(enemy.kind):
		"overhead":
			return Rect2(float(enemy.target_x)-40,deck.position.y-118,80,120)
		"hook":
			return Rect2(left,deck.position.y-84,122,29)
		_:
			return Rect2(left,deck.position.y-38,122,40)

func remaining() -> int:
	return 3-kills

func snapshot() -> Dictionary:
	return {"deck":deck,"enemies":enemies.duplicate(true),"active":active,"cleared":cleared,"elapsed":elapsed,"kills":kills,"attack_count":attack_count,"wave":wave,"player_attack_age":player_attack_age,"player_attack_facing":player_attack_facing,"player_guarding":player_guarding,"player_combo":player_combo,"player_attack_crouched":player_attack_crouched,"player_attack_hits":player_attack_hits.duplicate(),"previous_attack":previous_attack,"hurt_cooldown":hurt_cooldown,"champion_delay":champion_delay,"strike_count":strike_count,"blocked_count":blocked_count}

func restore(saved: Dictionary) -> void:
	for field in ["deck","active","cleared","elapsed","kills","attack_count","wave","player_attack_age","player_attack_facing","player_guarding","player_combo","player_attack_crouched","previous_attack","hurt_cooldown","champion_delay","strike_count","blocked_count"]:
		set(field,saved[field])
	enemies.assign(saved.enemies.duplicate(true))
	player_attack_hits.assign(saved.player_attack_hits.duplicate())
