extends RefCounted
## Shared navigation only. Spiritual trials never reset campaign health or sacrifice stats.
signal feedback(text: String)
signal cue(kind: String)
signal completed
signal failed
signal dialogue_requested(key: String)
enum Phase {READY, ACTIVE, MEMORY, COMPLETE, FAILED}
var phase := Phase.READY
var clock := 0.0
var position := Vector2(150,410)
var velocity := Vector2.ZERO
var facing := Vector2.RIGHT
var movement := Vector2.ZERO
var speed_mult := 1.0
var dash_cooldown := 3.0
var intellect := 5
var dash_time := 0.0
var dash_recharge := 0.0
var dash_direction := Vector2.RIGHT
var braced := false
var brace_held := false
var retries := 0
const SPEED := 215.0
const RADIUS := 12.0

func apply_player_stats(stats: Dictionary) -> void:
	speed_mult=maxf(0.3,float(stats.get("speed_mult",speed_mult)))
	dash_cooldown=maxf(0.5,float(stats.get("dash_cooldown",dash_cooldown)))
	intellect=int(stats.get("intellect",intellect))

func begin() -> void:
	if phase==Phase.READY: phase=Phase.ACTIVE

func set_input(axis: Vector2,brace: bool=false) -> void:
	movement=axis.limit_length(1); brace_held=brace

func request_dash() -> void:
	if phase!=Phase.ACTIVE or dash_recharge>0: return
	dash_direction=movement.normalized() if movement.length_squared()>0.01 else facing
	dash_time=0.19; dash_recharge=dash_cooldown; cue.emit("dash")

func walkable(_at: Vector2) -> bool: return true

func move_actor(delta: float,extra := Vector2.ZERO) -> void:
	dash_time=maxf(0,dash_time-delta); dash_recharge=maxf(0,dash_recharge-delta)
	if movement.length_squared()>0.01: facing=movement.normalized()
	var desired := movement*SPEED*speed_mult+extra
	if dash_time>0: desired=dash_direction*680+extra
	if braced: desired=Vector2.ZERO; velocity=Vector2.ZERO
	velocity=velocity.move_toward(desired,delta*2200)
	var next := position+Vector2(velocity.x*delta,0)
	if walkable(next): position.x=next.x
	else: velocity.x=0
	next=position+Vector2(0,velocity.y*delta)
	if walkable(next): position.y=next.y
	else: velocity.y=0

func finish_dialogue(_key: String) -> void:
	if phase==Phase.MEMORY: phase=Phase.ACTIVE
