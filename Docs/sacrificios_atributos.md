# Sacrifício de anos e efeitos por fase

O estado permanente continua em `Code/GameManager.gd`. `sacrifice_year()` calcula as mudanças existentes por idade, aplica limites, emite os sinais de atributos e vida e salva imediatamente. O novo `reset_encounter()` limpa apenas suspeita, derrota, modo de combate e primeiro movimento; a fase do portão usa essa operação ao entrar/reiniciar. `reset()` completo continua reservado às ações explícitas que já iniciavam/abandonavam uma campanha.

O menu de atributos bloqueia abertura e sacrifício nas telas de título/splash e sem cena ativa. Se uma transição leva ao título com o painel aberto, ele fecha e libera sua pausa. Isso evita gravar os valores reiniciados da tela inicial por cima de uma campanha existente.

`Code/PlayerAttributes.gd` fornece o mesmo formato de snapshot a todos os controladores. A conexão a `player_stats_changed` aplica mudanças durante a fase, incluindo sacrifícios feitos no menu pausado. Os valores exportados continuam sendo baselines: reaplicar atributos não multiplica os efeitos acumulativamente.

| Fase | Atributos e efeito |
| --- | --- |
| Portão de Troia | Velocidade altera corrida; inteligência diminui acúmulo de suspeita. A entrada preserva sacrifícios e progresso. |
| Invasão, rei e ciclope | Vida, velocidade, dano e recarga do dash. Vida atual acompanha o limite sem cura por sacrifício; recarga em andamento preserva a fração restante. |
| Lotófagos | Inteligência amplia a memória do minimapa de 1 a 3 células em caminhos conectados, sem enxergar através de paredes. O prazo continua em cinco minutos. |
| Navegação e tempestade | Agilidade altera aceleração e velocidade comandadas; inteligência melhora o leme. Casco e forças do mar continuam pertencendo à embarcação. |
| Arpão | Agilidade altera o tempo de carga; inteligência reduz a influência do vento. Não aumenta a área do alvo ou garante acerto. |
| Vigília | Vitalidade altera resistência ao sono e inteligência melhora concentração. Não recupera sono nem desperta automaticamente. A perda do dia nove continua obrigatória. |
| Poseidon | Dano, corrida, velocidade agachada e recarga do dash usam a campanha; o máximo de fôlego é vida máxima ×10. Checkpoints preservam sacrifícios posteriores. |

## Fórmulas específicas

- Navios: velocidade/aceleração × `clamp(sqrt(speed_mult), 0.7, 1.3)`; leme × `clamp(1 + (intellect - 5) * 0.02, 1, 1.2)`.
- Lotófagos: raio `clamp(1 + floor(max(0, intellect - 5) / 2), 1, 3)`, com busca apenas por caminhos conectados e suas bordas.
- Arpão: tempo de carga base / `sqrt(max(0.3, speed_mult))`; vento × `clamp(1 - max(0, intellect - 5) * 0.025, 0.75, 1)`. O disparo em voo preserva o vento calculado no lançamento.
- Vigília: crescimento de sono × `clamp((10 / max_hp)^0.2, 1, 1.35) * clamp(1 - (intellect - 5) * 0.025, 0.8, 1.15)`. A rampa inevitável do dia nove permanece.
- Poseidon: corrida `305 * speed_mult`; agachado `143 * speed_mult`; capacidade de fôlego `10 * max_hp`; dano e recarga iguais aos atributos salvos. Salto, gravidade e velocidade instantânea do dash continuam nas escalas existentes da fase.

Os atributos base de 20 anos mantêm os valores originais das mecânicas. Dano da espada não é aplicado ao casco ou ao alvo do arpão; vida do capitão não vira vida da embarcação. Mapa e cutscenes não recebem alterações de ritmo por sacrifício.

## Verificação

Os testes novos usam `GameManager.persistence_enabled=false` ou `save_file_path` direcionado a arquivo temporário. Eles conferem que o salvamento real permanece byte a byte igual. O autosave é exercitado em um arquivo temporário com leitura por outro manager.

- `scratch/test_sacrifice_persistence.gd`: persistência, retomada, reset da tentativa, entrada real em Troia e atributos do jogador em execução.
- `scratch/test_sacrifice_travel_lotus.gd`: física dos barcos, atualização ao vivo, limites, idempotência e memória do minimapa.
- `scratch/test_sacrifice_vigil_harpoon.tscn`: efeitos e atualização ao vivo, trajetória coerente, sobrevivência até o oitavo dia e derrota inevitável no nono.
- `scratch/test_sacrifice_poseidon.gd`: atualização ao vivo, recarga proporcional, fôlego/HUD, ausência de cura e persistência dos sacrifícios após checkpoint.
- `scratch/test_sacrifice_menu_guard.gd`: bloqueio no título, callback obsoleto, salvamento em jogo, repetição de teclado e transição com menu aberto.

As verificações automáticas cobrem funcionamento e preservação dos estados. Os limites de influência nos minigames são decisões iniciais de balanceamento e ainda se beneficiam de avaliação humana da dificuldade.

Nesta revisão passaram 84 verificações específicas: persistência 15, navegação/Lotófagos 20, vigília/arpão 24, Poseidon 17 e proteção do menu 8. Também passaram as regressões existentes de vigília (144), arpão (60 com FPS fixo), tempestade (57), modelo de Poseidon (75), integração da fuga (23), controles (16) e dash (22). A travessia completa de Poseidon aos atributos base continuou concluível em 162,2 s, com o navio final intacto. As verificações dirigidas dos atributos não substituem sessões humanas de balanceamento.
