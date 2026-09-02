extends Node

func _ready():
	print("--- INICIANDO TESTE GERAL ---")
	
	print("Testando Ato 1 - Fase 1...")
	var pack1 = load("res://Ato1_Troia/Fase1_PortaoDeTroia.tscn")
	var l1 = pack1.instantiate()
	get_tree().root.add_child(l1)
	
	print("Testando Ato 1 - Fase 2...")
	var pack2 = load("res://Ato1_Troia/Fase2_Invasao.tscn")
	var l2 = pack2.instantiate()
	get_tree().root.add_child(l2)
	
	print("Testando Ato 1 - Fase 3...")
	var pack3 = load("res://Ato1_Troia/Fase3_ReiDeTroia.tscn")
	var l3 = pack3.instantiate()
	get_tree().root.add_child(l3)

	print("Testando Ato 2 - Fase 1...")
	var pack4 = load("res://Ato2_Lotofagos/Fase1_IlhaDosLotofagos.tscn")
	var l4 = pack4.instantiate()
	get_tree().root.add_child(l4)

	print("Testando Ato 2 - Fase 2...")
	var pack5 = load("res://Ato2_Lotofagos/Fase2_NavegacaoMaritima.tscn")
	var l5 = pack5.instantiate()
	get_tree().root.add_child(l5)

	print("--- TESTE GERAL CONCLUÍDO COM SUCESSO ---")
	get_tree().quit()
