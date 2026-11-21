extends RefCounted
## Authored solution replay, only for verification. It knows the tricks, unlike
## the player on the first attempt. Never attached to a gameplay scene.
static func age(model: RefCounted, id: String) -> float:
	for i in model.trickery.definitions.size():
		if model.trickery.definitions[i].id==id: return model.trickery.ages[i]
	return -1.0

static func drive(m: RefCounted, returning: bool, max_seconds: float = 240.0, knows_tricks: bool = true) -> bool:
	var next_surface:=Rect2()
	var in_jump:=false
	var mode: String=""
	var floor_baited:=false
	for step in int(max_seconds*120):
		if m.phase==m.Phase.FAILED:
			print("DEVIL_REPLAY_FAIL ",m.position," time ",m.clock," hp ",m.hp," mode ",mode," fired ",m.trickery.fired_ids)
			return false
		var target: float=m.palace_position().x if returning else m.level.flower[0]
		if absf(m.position.x-target)<38 and m.grounded:
			m.set_input(0,false,false)
			return true
		var direction: int=-1 if returning else 1
		if returning and m.position.x<target-30: direction=1
		var axis:=float(direction)
		var duck:=false
		if not returning and not m.memory_gate_open and m.position.x>2530 and m.position.x<2650 and m.grounded:
			m.set_input(0,false,true)
			m.tick(1.0/120)
			continue
		if m.memory_gate_open and m.gate_opening<0.99:
			m.set_input(0,false,true)
			m.tick(1.0/120)
			continue
		for branch: Array in m.level.low_branches:
			var body: Rect2=m._body()
			body.position.x+=direction*35
			if body.intersects(Rect2(branch[0],branch[1],branch[2],branch[3])): duck=true
		if returning:
			for i in m.tree_ages.size():
				var tree: Dictionary=m.level.return_trees[i]
				if direction<0 and m.position.x>float(tree.x)+45 and m.position.x<float(tree.x)+float(tree.trigger) and m.tree_ages[i]<float(tree.warning)+float(tree.fall)+0.15: axis=0
				if direction<0 and m.position.x>float(tree.x) and m.position.x<float(tree.x)+90 and m.grounded and m.tree_ages[i]>float(tree.warning)+float(tree.fall): m.request_jump()
		if knows_tricks and not returning and m.grounded and m.position.x>1935 and m.position.x<1985 and not floor_baited:
			m.request_jump()
			floor_baited=true
			mode="floor_jump"
		if knows_tricks and not returning and m.trickery.is_fired("jump_teeth") and m.position.x>1535 and m.position.x<1670 and not m.grounded and m.position.y<425 and m.dash_recharge<=0:
			m.request_dash()
			mode="teeth_escape"
		if knows_tricks and not returning and m.trickery.is_fired("memory_slide") and not m.trickery.is_fired("jump_column") and m.grounded:
			axis=0
			if absf(m.velocity.x)<20:
				m.request_jump()
				mode="memory_bait"
		if knows_tricks and not returning and m.position.x>5750 and m.position.x<5880 and not m.trickery.is_fired("last_bough") and m.grounded:
			axis=0
			if absf(m.velocity.x)<20:
				m.request_jump()
				mode="last_bait"
		if knows_tricks and not returning and m.trickery.is_fired("false_flower") and m.position.x>5340 and m.position.x<5510 and m.grounded:
			m.request_jump()
			m.request_dash()
			mode="lure_escape"
		if knows_tricks and returning and m.trickery.is_fired("backward_teeth") and m.position.x>5510 and m.position.x<5630 and m.grounded: m.request_jump()
		if knows_tricks and returning and m.trickery.is_fired("last_door") and m.position.x>700 and m.position.x<956 and mode!="door_escape":
			if m.grounded: m.request_jump()
			m.request_dash()
			mode="door_escape"
		if mode in ["memory_bait","last_bait"]:
			axis=0
			var id: String="jump_column" if mode=="memory_bait" else "last_bough"
			if m.grounded and age(m,id)>1.0: mode=""
		elif mode=="floor_jump":
			axis=1 if m.position.x<2190 else 0
			if m.grounded and m.position.x>2150: mode=""
		elif mode=="teeth_escape":
			axis=1 if m.position.x<1770 else 0
			if m.grounded and m.position.x>1730: mode=""
		elif mode=="lure_escape":
			axis=1 if m.position.x<5540 else 0
			if m.grounded and m.position.x>=5510: mode=""
		elif mode=="door_escape":
			axis=-1 if m.position.x>710 else 0
			if m.grounded and m.position.x<700: mode=""
		if mode=="":
			if m.grounded:
				in_jump=false
				var support:=Rect2()
				for surface: Rect2 in m.surface_rects:
					if not surface.has_area(): continue
					if absf(m.position.y-surface.position.y)<1.0 and m.position.x>=surface.position.x-13 and m.position.x<=surface.end.x+13:
						if support.size.x==0 or (direction>0 and surface.end.x>support.end.x) or (direction<0 and surface.position.x<support.position.x): support=surface
				var best_distance:=INF
				for surface: Rect2 in m.surface_rects:
					if not surface.has_area() or surface==support: continue
					var si: int=m.surface_rects.find(surface)
					if m.speed_mult<0.6 and m.crumble_delay(float(m.surface_items[si][0]))>0: continue
					var ahead: bool=surface.position.x>support.position.x if direction>0 else surface.end.x<support.end.x
					if not ahead: continue
					var distance: float=surface.position.x-m.position.x if direction>0 else m.position.x-surface.end.x
					if distance<best_distance and distance>=-13:
						best_distance=distance
						next_surface=surface
				if support.has_area() and next_surface.has_area():
					var gap: float=next_surface.position.x-support.end.x if direction>0 else support.position.x-next_surface.end.x
					var edge: float=support.end.x-m.position.x if direction>0 else m.position.x-support.position.x
					var launch: bool=(next_surface.position.y<support.position.y-10 and best_distance<80) or (gap>5 and edge<48)
					if launch and not duck and axis!=0:
						if m.speed_mult<0.6 and gap>25 and m.dash_recharge>0: axis=0
						else:
							m.request_jump()
							in_jump=true
			if in_jump and not m.grounded and next_surface.has_area():
				var margin:=24.0 if next_surface.position.x==5200 else minf(100,next_surface.size.x*0.5)
				var landing: float=next_surface.position.x+margin if direction>0 else next_surface.end.x-minf(100,next_surface.size.x*0.5)
				if (m.position.x-landing)*direction>0: axis=0
				var use_dash: bool=m.speed_mult<0.6 or next_surface.position.x==5200 or (m.position.x>2770 and m.position.x<2960 and age(m,"jump_column")>1)
				if use_dash and absf(landing-m.position.x)>110 and m.position.y<next_surface.position.y-5 and m.velocity.y<0: m.request_dash()
			# The last true terrace has a separate readable bramble after landing.
			if not returning and m.grounded and m.position.x>5200 and m.position.x>float(m.level.hazards.back().x)-115 and m.position.x<float(m.level.hazards.back().x)-30: m.request_jump()
		m.set_input(axis,true,false,duck)
		m.tick(1.0/120)
	print("DEVIL_REPLAY_TIMEOUT ",m.position," mode ",mode," fired ",m.trickery.fired_ids)
	return false
