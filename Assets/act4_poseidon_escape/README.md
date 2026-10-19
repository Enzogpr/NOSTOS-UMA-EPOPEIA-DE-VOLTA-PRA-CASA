# Poseidon — Travessia da frota e sobrevivência

Abra `Ato4_Tempestade/Gameplay/PoseidonEscape.tscn` no Godot e use F6. A campanha entra aqui após “Morra” e o primeiro impacto de `Ruthlessness.tscn`.

Esta revisão combina as propostas escolhidas: primeiro atravessar embarcações sendo destruídas; depois, no navio de Odisseu, sobreviver a três atos obrigatórios de ataques. O primeiro impacto lançou o capitão para uma embarcação vizinha; a bolsa continua no navio dele.

## Jogabilidade

- WASD/setas: mover. Espaço: esquivar; na marca da proa com passagem aberta, saltar. E: usar a corda na segunda passagem; no convés, interagir com a bolsa/leme ou segurar cordas nos círculos marcados. Esc: pausa existente.
- Parte I: três passagens por quatro navios. Cada passagem exige enfrentar quatro ataques, posicionar-se na proa e aproveitar a aproximação da próxima embarcação. A segunda usa uma corda presa ao mastro de destino. O navio abandonado se parte e afunda, junto de uma embarcação ao fundo.
- Parte II: três atos completos. Primeiro, soltar a bolsa sob os ataques; segundo, levá-la e prendê-la junto ao leme; terceiro, sobreviver à última sequência. Recuperar a bolsa cedo não pula atos. Poseidon quebra o mastro, removendo seu abrigo; as ondas do último ato exigem usar suas aberturas.
- Seis padrões: jatos com marcas fixas, paredes de água com abertura, rajadas em faixas, disparos direcionados, colunas esmagadoras e impacto que exige agarrar uma corda. Golpes tiram equilíbrio e empurram. Não há regeneração passiva do equilíbrio. Cada novo trecho/ato restaura o equilíbrio.
- Sem equilíbrio, sem tempo para a passagem ou perdendo a liberação final: tentativa interrompida, com decisão de retomar o trecho. Odisseu não morre e não escapa automaticamente. Os checkpoints são por passagem/ato; repetir a liberação conserva a frota já destruída.
- Os onze navios precisam completar sua animação de naufrágio antes da liberação da fuga. Na janela final é necessário começar a segurar E; mantê-lo apertado desde antes não abre a bolsa automaticamente.

## Organização

`PoseidonEscapeModel.gd` mantém movimento, saltos, corda, ataques, checkpoints e progressão. `PoseidonAssaults.json` contém os eventos e tempos de cada passagem e ato. `PoseidonFleetStage.gd` apresenta a primeira parte com câmera de acompanhamento; `PoseidonEscapeStage.gd` reutiliza o convés e a saída anterior. `PoseidonWaterEffects.gd` desenha os mesmos avisos e padrões nas duas arenas. O controlador `PoseidonEscape.gd` mantém interface, áudio, pausa, resultado e integração. Os atributos, a vida e o inventário da campanha permanecem sob os sistemas existentes.

## Artes e prompts

Geradas com **ImageGen integrado**, mantendo o alpha original e usando as artes existentes como referências:

- `traversal_ship.png`: navio exterior com convés visível, vela recolhida e estilo da frota.
- `odysseus_jump_v2.png`: antecipação, salto, aterrissagem e balanço na corda, preservando rosto e figurino vermelho. `odysseus_jump.png` conserva a primeira versão como referência da correção dos espaços entre quadros; o jogo usa a v2, com recortes separados.
- `deck_broken.png`: mesmo convés com o mastro quebrado e piso alinhado ao original.
- `deck.png`, `odysseus_escape_v2.png` e `odysseus_escape.png`: recursos e fonte da edição dos passos da versão anterior.
- `fleet_prompts.json` e `jump_refinement_prompt.json`: prompts completos desta revisão, com os papéis das referências. `generation_prompts.json` e `gait_refinement_prompt.json`: prompts anteriores.

Mar, cavalo de água, bolsa, navios de fundo, Euríloco e sons são reaproveitados. As poses têm quadros finitos com movimento, arcos e efeitos dirigidos pelo jogo; não são animação redesenhada quadro a quadro. Nenhum áudio do vídeo foi usado.

## Validação

`scratch/test_poseidon_escape.tscn` verifica a passagem obrigatória, bloqueio de corrida direta, derrota de personagem parado por ataques reais, ausência de morte e de fuga automática, checkpoints, término visual dos naufrágios, interação final, conclusão única, três percursos completos, teclado, pausa, janela vertical, transferência da cutscene e preservação da campanha. As capturas de renderização ficam em `scratch/poseidon_fleet_preview/`. Os percursos guiados duraram cerca de três minutos, atravessaram três vezes, enfrentaram 36 padrões e completaram os três atos; o piloto lê os avisos do modelo, portanto seus resultados não medem a dificuldade para jogadores humanos.

`scratch/test_poseidon.tscn` cobre a regressão da cutscene anterior. `scratch/poseidon_escape_demo.tscn` demonstra o caminho com teclado simulado, sem teletransportes nem invulnerabilidade. Desativa a persistência do resultado. `scratch/encode_poseidon_escape_preview.py scratch/poseidon_fleet_preview fleet` exporta a gravação e folhas de contato. Vídeos e capturas ficam fora do Git.

Resultado final: **56 verificações da fase e 115 da cutscene anterior, nenhuma falha**. Foram capturados quatorze momentos da renderização, incluindo a câmera que mantém o navio abandonado visível enquanto ele é esmagado. Os percursos guiados completos levaram 185,3 s sem retomada e 200,5 s com uma retomada; a execução parada falha por golpes reais. A gravação completa no Godot gerou 5.862 quadros a 30 fps (**3min15,4s**), incluindo a entrada desde “Morra” e o resultado. A rota gravada terminou em 185,4 s com três passagens, três atos e 36 padrões concluídos. O MP4 é `scratch/poseidon_fleet_preview/fleet.mp4`.

O aviso preexistente do UID do retrato em `Scenes/PlayerStatsMenu.tscn` continua sendo resolvido pelo caminho da imagem. As execuções finais com renderização, a regressão em tempo normal e a gravação não apresentaram erros novos. Uma execução acelerada da regressão retinha buffers de áudio ao sair; a confirmação final usou o relógio normal para permitir sua liberação.

Checkpoint anterior a esta revisão: **`1379362`**. A nova fase conserva o mesmo arquivo de cena para continuar funcionando com a campanha existente.
