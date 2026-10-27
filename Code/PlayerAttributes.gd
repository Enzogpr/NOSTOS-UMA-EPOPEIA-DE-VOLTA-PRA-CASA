extends RefCounted
## One snapshot format for campaign attributes used by the different controllers.
## Scene-specific mechanics decide which attributes apply, without writing saves.
static func capture(manager: Node) -> Dictionary:
	return {
		"age":int(manager.player_age),
		"max_hp":maxi(1,int(manager.player_max_hp)),
		"current_hp":int(manager.player_current_hp),
		"speed_mult":maxf(0.3,float(manager.player_speed_mult)),
		"damage":maxi(1,int(manager.player_damage)),
		"dash_cooldown":maxf(0.5,float(manager.player_dash_cooldown)),
		"intellect":int(manager.player_intellect),
	}
