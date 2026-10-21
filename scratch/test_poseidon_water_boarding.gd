extends SceneTree
const Combat := preload("res://Ato4_Tempestade/Gameplay/PoseidonWaterBoarding.gd")
var checks:=0
var failures:=0
func check(value: bool, message: String) -> void:
	checks+=1
	if not value:
		failures+=1
		push_error(message)
func _initialize() -> void:
	run.call_deferred()
func fresh() -> Combat:
	var c:=Combat.new()
	c.setup(Rect2(0,470,1600,24))
	return c
func collision(kind: String, feet: Vector2, crouched: bool, guard: bool, facing: float=1.0, grounded: bool=true) -> Dictionary:
	var c:=fresh()
	c.enemies.resize(1)
	var e: Dictionary=c.enemies[0]
	e.position=Vector2(600,470)
	e.facing=-1.0
	e.kind=kind
	e.target_x=500.0
	e.state="strike"
	e.age=0.0
	return c.tick(1.0/120,feet,facing,grounded,crouched,false,guard)
func run() -> void:
	var c:=fresh()
	check(c.active and not c.cleared and c.enemies.size()==2 and c.remaining()==3,"Boarding begins with two water soldiers and a reserved champion")
	check(c.enemies[0].hp==3 and c.enemies[1].hp==3,"Initial enemy health is authored")
	check(c.enemy_rect(c.enemies[0]).size==Vector2(44,108),"Regular water soldier collision follows the smaller body")
	var body:=Vector2(680,470)
	var safe:=c.tick(0.1,body,1,true,false,false,false)
	check(safe.damage==0,"Boarding arrival and body overlap do not cause invisible contact damage")
	for i in 120: c.tick(1.0/120,Vector2(100,470),1,true,false,true,false)
	check(c.attack_count==1,"Holding attack cannot produce an automatic chain of sword strikes")
	c=fresh()
	c.enemies.resize(1)
	c.enemies[0].position=Vector2(600,470)
	c.enemies[0].state="recover"
	c.enemies[0].age=0.0
	for i in 30: c.tick(1.0/120,Vector2(500,470),-1,true,false,i==0,false)
	check(c.enemies[0].hp==3,"Sword cannot hit the enemy behind Odisseu")
	c.player_attack_age=-1
	for i in 30: c.tick(1.0/120,Vector2(500,470),1,true,false,i==0,false)
	check(c.enemies[0].hp==2,"Sword active frames hit an enemy within forward reach")
	for i in 60: c.tick(1.0/120,Vector2(500,470),1,true,false,false,false)
	check(c.enemies[0].hp==2,"A single swing cannot damage repeatedly across its active frames")
	c=fresh()
	c.enemies[0].state="recover"
	for i in 30: c.tick(1.0/120,Vector2(300,470),1,true,false,i==0,false)
	check(c.enemies[0].hp==3,"Sword cannot hit across the deck")
	check(collision("sweep",Vector2(500,470),false,false).damage==20,"Low sweep hits a standing target")
	check(collision("sweep",Vector2(500,470),true,false).damage==20,"Crouching does not evade the low sweep")
	check(collision("sweep",Vector2(500,410),false,false,1,false).damage==0,"Jumping over the trident evades a low sweep")
	check(collision("hook",Vector2(500,470),false,false).damage==20,"High hook reaches a standing target")
	check(collision("hook",Vector2(500,470),true,false).damage==0,"Crouch clearance evades the high hook")
	check(collision("overhead",Vector2(500,470),false,false).damage==25,"Overhead slam is heavier than the sweep")
	check(collision("overhead",Vector2(390,470),false,false).damage==0,"Moving away from the committed overhead target evades it")
	check(collision("hook",Vector2(500,470),false,true).damage==0,"Facing the incoming trident can guard a regular blow")
	check(collision("hook",Vector2(500,470),false,true,-1).damage==20,"A guard facing away does not block a rear attack")
	check(collision("overhead",Vector2(500,470),false,true).damage==8,"Heavy overhead pressure partly breaks the guard")
	check(collision("hook",Vector2(500,470),false,true,1,false).damage==20,"An airborne target cannot guard")
	c=fresh()
	c.enemies.resize(1)
	c.enemies[0].state="windup"
	c.enemies[0].age=0.0
	c.enemies[0].position=Vector2(600,470)
	for i in 20: c.tick(1.0/120,Vector2(500,470),1,true,false,i==0,false)
	check(c.enemies[0].hp==2 and c.enemies[0].state=="windup","Hitting a committed swing cannot stun-lock its windup")
	var saved:=c.snapshot()
	c.enemies[0].hp=0
	c.enemies[0].position.x=999
	c.elapsed=80
	c.restore(saved)
	check(c.snapshot()==saved,"Checkpoint restores enemy health, positions and exact action timers")
	c.enemies[0].hp=1
	check(saved.enemies[0].hp==2,"Restored state does not mutate the saved checkpoint")
	c=fresh()
	for enemy in c.enemies:
		enemy.hp=0
		enemy.state="dead"
	c.kills=2
	for i in 150: c.tick(1.0/120,Vector2(200,470),1,true,false,false,false)
	check(c.wave==2 and c.enemies.size()==3 and c.enemies[2].max_hp==5,"A stronger water captain follows the first pair")
	check(c.enemy_rect(c.enemies[2]).size==Vector2(50,122),"Water captain collision follows its taller visual body")
	check(c.active and not c.cleared and c.remaining()==1,"Defeating the first pair alone cannot unlock the encounter")
	c.enemies[2].hp=1
	c.enemies[2].state="recover"
	c.enemies[2].position=Vector2(600,470)
	var clear_cue:=""
	for i in 30:
		var hit:=c.tick(1.0/120,Vector2(500,470),1,true,false,i==0,false)
		if hit.cue=="boarding_clear": clear_cue=hit.cue
	check(c.kills==3 and c.cleared and not c.active and clear_cue=="boarding_clear","Last actual sword hit clears boarding exactly once")
	var end:=c.snapshot()
	for i in 120: c.tick(1.0/120,Vector2(500,470),1,true,false,true,true)
	check(c.snapshot()==end,"A completed encounter never respawns boarders or advances clocks")
	var separated:=fresh()
	for enemy in separated.enemies:
		enemy.state="approach"
	separated.enemies[0].position=Vector2(600,470)
	separated.enemies[1].position=Vector2(680,470)
	separated.tick(0.1,Vector2(300,470),1,true,false,false,false)
	check(absf(separated.enemies[0].position.x-separated.enemies[1].position.x)>=78,"Approaching soldiers keep separate feet instead of stacking inside each other")
	separated.enemies[0].state="windup"
	var committed: Vector2=separated.enemies[0].position
	separated.tick(0.1,Vector2(300,470),1,true,false,false,false)
	check(separated.enemies[0].position==committed,"Separation cannot slide a committed trident windup across the deck")
	var run:=fresh()
	var pilot:=preload("res://scratch/PoseidonWaterPilot.gd").new()
	var feet:=Vector2(150,470)
	var facing:=1.0
	var damage:=0.0
	for frame in 120*100:
		if not run.active: break
		var input: Dictionary=pilot.controls(run,feet,facing,true)
		feet.x=clampf(feet.x+float(input.move)*305.0/120.0,75,1525)
		if absf(float(input.move))>0.01: facing=signf(float(input.move))
		var outcome:=run.tick(1.0/120,feet,facing,true,false,input.attack,input.guard)
		damage+=float(outcome.damage)
	check(run.cleared and run.kills==3,"Input-only guard-and-counter pilot can defeat both waves")
	check(damage<100,"Counterplay completes without an invisible rescue or invulnerability")
	print("BOARDING_PILOT seconds=",snappedf(run.elapsed,0.1)," damage=",damage," attacks=",run.attack_count," blocks=",run.blocked_count)
	print("BOARDING_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
