extends RefCounted

## One pin per place; chapters keep their existing campaign gates.
const DESTINATIONS := [
	{"id":"troy", "name":"Troia", "subtitle":"A cidade em chamas", "position":Vector2(126, 210),
	 "description":"As muralhas que encerraram dez anos de guerra. A viagem de volta começa aqui.", "chapters":[{"id": "troy", "name": "A queda de Troia", "order": 0, "act": 1, "chapter": -1, "scene": "res://Ato1_Troia/Cutscenes/Act1_TitleCard.tscn"}]},
	{"id":"lotus", "name":"Ilha dos Lotófagos", "subtitle":"O jardim do esquecimento", "position":Vector2(328, 202),
	 "description":"Entre flores e águas tranquilas, os homens começam a esquecer o caminho de casa.", "chapters":[{"id": "lotus", "name": "Os comedores de lótus", "order": 1, "act": 2, "chapter": -1, "scene": "res://Ato2_Lotofagos/Cutscenes/Act2_TitleCard.tscn"}]},
	{"id":"cyclops", "name":"Ilha do Ciclope", "subtitle":"A caverna de Polifemo", "position":Vector2(523, 206),
	 "description":"Uma costa rochosa, rebanhos e uma caverna cujo dono não recebe visitantes.", "chapters":[{"id": "cyclops", "name": "Polifemo", "order": 2, "act": 3, "chapter": -1, "scene": "res://Ato3_Ciclope/Cutscenes/Act3_TitleCard.tscn"}]},
	{"id":"aeolia", "name":"Eólia", "subtitle":"A ilha dos ventos", "position":Vector2(726, 197),
	 "description":"A tempestade leva a um reino suspenso. A ajuda de Éolo depende de uma bolsa fechada.", "chapters":[{"id": "storm", "name": "A travessia da tempestade", "order": 3, "act": 4, "chapter": 0, "scene": "res://Ato4_Tempestade/Cutscenes/Act4_StormCutscene.tscn"},{"id": "harpoon", "name": "A ilha no céu", "order": 4, "act": 4, "chapter": 1, "scene": "res://Ato4_Tempestade/Cutscenes/AeoliaApproach.tscn"},{"id": "vigil", "name": "Nove dias de vigília", "order": 5, "act": 4, "chapter": 2, "scene": "res://Ato4_Tempestade/Gameplay/NineDaysVigil.tscn"}]},
	{"id":"giants", "name":"Costa dos Gigantes", "subtitle":"As águas de Poseidon", "position":Vector2(743, 346),
	 "description":"Penhascos fecham o horizonte. Aqui a frota encontra a fúria do deus do mar.", "chapters":[{"id": "first_poseidon", "name": "A destruição da frota", "order": 6, "act": 4, "chapter": 3, "scene": "res://Ato4_Tempestade/Cutscenes/Ruthlessness.tscn"}]},
	{"id":"aeaea", "name":"Eeia · Circe", "subtitle":"A ilha da feiticeira", "position":Vector2(548, 351),
	 "description":"A floresta guarda a flor de Hermes. Além dela, Circe espera em seu palácio.", "chapters":[{"id": "moly", "name": "A flor de Hermes", "order": 7, "act": 5, "chapter": -1, "scene": "res://Ato5_Circe/Gameplay/CirceForest.tscn"},{"id": "circe", "name": "O palácio de Circe", "order": 8, "act": 5, "chapter": 1, "scene": "res://Ato5_Circe/Gameplay/CirceBattle.tscn"}]},
	{"id":"underworld", "name":"Submundo", "subtitle":"As margens dos mortos", "position":Vector2(337, 346),
	 "description":"O rio das almas conduz a Tirésias. Odisseu precisa atravessar o que deixou para trás.", "chapters":[{"id": "souls", "name": "A fuga das almas", "order": 9, "act": 6, "chapter": 0, "scene": "res://Ato6_Submundo/Gameplay/UnderworldCrossing.tscn"},{"id": "prophet", "name": "A profecia de Tirésias", "order": 10, "act": 6, "chapter": 1, "scene": "res://Ato6_Submundo/Gameplay/UnderworldOracle.tscn"}]},
	{"id":"sirens", "name":"Ilha das Sereias", "subtitle":"O recife do canto", "position":Vector2(134, 355),
	 "description":"O canto atravessa os recifes e oferece a voz de quem Odisseu mais deseja reencontrar.", "chapters":[{"id": "sirens", "name": "O canto da sereia", "order": 11, "act": 7, "chapter": -1, "scene": "res://Ato7_Sereias/Gameplay/SirenCove.tscn"}]},
	{"id":"strait", "name":"Cila e Caríbdis", "subtitle":"O estreito de duas ameaças", "position":Vector2(150, 496),
	 "description":"A gruta de Cila e o redemoinho de Caríbdis dividem o mesmo estreito, visitado em momentos diferentes.", "chapters":[{"id": "scylla", "name": "Cila · As seis tochas", "order": 12, "act": 8, "chapter": -1, "scene": "res://Ato8_Cila/Gameplay/ScyllaPassage.tscn"},{"id": "charybdis", "name": "Caríbdis · O redemoinho", "order": 16, "act": 11, "chapter": -1, "scene": "res://Ato11_Caribdis/Gameplay/Charybdis.tscn"}]},
	{"id":"thrinacia", "name":"Trinácia · Hélio", "subtitle":"A ilha do rebanho sagrado", "position":Vector2(353, 500),
	 "description":"A fome e a desconfiança dividem a tripulação diante do gado sagrado do Sol.", "chapters":[{"id": "mutiny", "name": "O motim de Euríloco", "order": 13, "act": 9, "chapter": -1, "scene": "res://Ato9_Motim/Gameplay/Mutiny.tscn"}]},
	{"id":"ogygia", "name":"Ogígia · Calipso", "subtitle":"Sete anos longe de casa", "position":Vector2(548, 500),
	 "description":"Uma praia acolhedora e um mar que sempre devolve Odisseu à mesma ilha.", "chapters":[{"id": "captivity", "name": "Os sete anos", "order": 14, "act": 10, "chapter": 0, "scene": "res://Ato10_Calipso/Gameplay/CalypsoPaths.tscn"},{"id": "raft", "name": "A última maré", "order": 15, "act": 10, "chapter": 1, "scene": "res://Ato10_Calipso/Gameplay/CalypsoDeparture.tscn"}]},
	{"id":"ithaca", "name":"Ítaca", "subtitle":"O lar além da última tempestade", "position":Vector2(743, 496),
	 "description":"Poseidon ainda vigia as águas da chegada. Em terra, os pretendentes ocupam o palácio.", "chapters":[{"id": "final_poseidon", "name": "Poseidon · O último mar", "order": 17, "act": 12, "chapter": -1, "scene": "res://Ato12_Poseidon/Gameplay/FinalPoseidon.tscn"},{"id": "suitors", "name": "Os pretendentes", "order": 18, "act": 13, "chapter": -1, "scene": "res://Ato13_Itaca/Gameplay/Ithaca.tscn"}]},
]

static func destination(id: String) -> Dictionary:
	for place in DESTINATIONS:
		if place.id == id: return place
	return {}

static func chapter_unlocked(entry: Dictionary) -> bool:
	var manager: Node = Engine.get_main_loop().root.get_node("GameManager")
	var act := int(entry.act)
	var chapter := int(entry.chapter)
	if act==13: return manager.final_poseidon_completed
	if act==12: return manager.charybdis_completed
	if act==11: return manager.calypso_completed
	if act==10: return manager.ogygia_paths_completed if chapter==1 else manager.mutiny_completed
	if act==9: return manager.scylla_completed
	if act==8: return manager.sirens_completed
	if act==7: return manager.underworld_prophecy_completed
	if act==6:
		return manager.underworld_crossing_completed if chapter==1 else manager.circe_battle_completed
	if act==5:
		return manager.circe_search_completed if chapter==1 else manager.act4_completed or manager.highest_unlocked_level>=5
	if manager.highest_unlocked_level<act: return false
	return chapter<0 or chapter<=manager.act4_unlocked_stage

static func chapter_completed(entry: Dictionary) -> bool:
	var manager: Node = Engine.get_main_loop().root.get_node("GameManager")
	var act := int(entry.act)
	var chapter := int(entry.chapter)
	if not chapter_unlocked(entry): return false
	if act==13: return manager.ithaca_completed
	if act==12: return manager.final_poseidon_completed
	if act==11: return manager.charybdis_completed
	if act==10: return manager.calypso_completed if chapter==1 else manager.ogygia_paths_completed
	if act==9: return manager.mutiny_completed
	if act==8: return manager.scylla_completed
	if act==7: return manager.sirens_completed
	if act==6: return manager.underworld_prophecy_completed if chapter==1 else manager.underworld_crossing_completed
	if act==5: return manager.circe_battle_completed if chapter==1 else manager.circe_search_completed
	if chapter<0: return manager.highest_unlocked_level>act
	return manager.act4_completed or chapter<manager.act4_unlocked_stage
