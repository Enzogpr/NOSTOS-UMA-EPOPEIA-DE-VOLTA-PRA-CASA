extends Node

func _ready():
	print("--- INICIANDO TESTE GERAL ---")
	
	print("Testando Fase 1...")
	var pack1 = load("res://Scenes/TrojanHorse.tscn")
	var l1 = pack1.instantiate()
	get_tree().root.add_child(l1)
	
	print("Testando Fase 2...")
	var pack2 = load("res://Scenes/Level2.tscn")
	var l2 = pack2.instantiate()
	get_tree().root.add_child(l2)
	
	print("Testando Fase 3...")
	var pack3 = load("res://Scenes/Level3.tscn")
	var l3 = pack3.instantiate()
	get_tree().root.add_child(l3)

	print("--- TESTE GERAL CONCLUÍDO COM SUCESSO ---")
	get_tree().quit()
