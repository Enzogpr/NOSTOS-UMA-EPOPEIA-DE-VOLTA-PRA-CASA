# Circe — O palácio enfeitiçado

Confronto com movimentação livre em quatro direções, depois da busca da holimoli e antes do resgate dos homens. Entre pelo resultado da floresta (**Enfrentar Circe**) ou pela nona parada do mapa (**Circe · Confronto**). O marco `circe_battle_completed` e os saves anteriores são preservados. O confronto funciona inteiramente offline.

## Três fases

1. **A feiticeira perde a vantagem.** Circe começa com 80 de vida e alterna encantamentos, mesas arremessadas, raízes e golpes do cajado. Ela muda de posição antes de lançar feitiços e se aproxima para usar o cajado. A holimoli repele automaticamente os encantamentos, com reação visual dourada. Cada golpe de espada que causa dano faz Circe se teletransportar e preparar um contra-ataque de mesa ou raízes.
2. **O palácio das cópias.** Aos 53 de vida, surgem três aparências de Circe. Segurar E carrega uma observação de 0,72 s, interrompendo imediatamente o movimento nos dois eixos. Completar a carga consome 20 de clareza e revela a verdadeira por 1,8 s. O intelecto melhora a velocidade e a duração. Soltar antes cancela a carga. As cópias têm pequenas diferenças de sombra e movimento. O deslocamento de Circe durante os ataques físicos também oferece uma pista. Atacar uma cópia consome a oportunidade e não causa dano à verdadeira.
3. **Circe assume o controle do cenário.** Aos 27 de vida, os padrões físicos se combinam com mudanças persistentes no salão. Uma coluna cai na entrada da fase, cruzar o centro fecha a passagem norte, o primeiro dash deixa uma área de piso rachando e o segundo acerto em Circe derruba outra coluna. Formação, queda e colisão usam o mesmo estado da simulação. As rotas superior, inferior e laterais permitem contornar os bloqueios.

O portão interrompe seu fechamento quando há alguém na área, impedindo esmagamento e aprisionamento. Uma queda de coluna pode ferir e deslocar Odisseu para um ponto livre. Pisar no buraco causa dano físico e retorna ao último apoio seguro; o dash pode atravessá-lo. Há alternativas de navegação para chegar a todas as posições de Circe mesmo depois de todos os eventos.

## Controles

| Ação | Controle |
| --- | --- |
| Movimento normalizado em oito sentidos | WASD ou setas |
| Mira da espada e defesa | Mouse |
| Espada | J, Espaço ou clique esquerdo |
| Defender do cajado pela frente | Shift |
| Dash na direção do movimento, ou da mira quando parado | Q ou botão direito |
| Revelar a verdadeira, exigindo ficar parado | Segurar E |
| Reiniciar o confronto | R ou menu de pausa |
| Atributos/sacrifícios e pausa | Tab / Esc |

Como em Troia, a barra azul de recarga acompanha os pés de Odisseu e desaparece quando o dash fica pronto. O dash dura 0,20 s, com velocidade de 400 pixels por segundo.

Uma nova tentativa volta à primeira fase, restaura a vida máxima de Odisseu e os 80 pontos de vida de Circe e limpa as mudanças do salão. Atributos, sacrifícios e a holimoli são preservados. Entrar com vida baixa não cura automaticamente o jogador.

## Implementação e recursos

- `CirceBattleModel.gd`: combate determinístico, movimento nos dois eixos, ataques físicos, observação, dano e fases.
- `CircePalace.gd`: condições de ação, evolução das quedas/fechamentos e colisões do cenário.
- `CirceBattleTuning.json`: arena, posições, vida, tempos e sequência de eventos ajustáveis individualmente.
- `CirceBattle.gd/.tscn`: entrada, controles, UI, novas tentativas, save e áudio.
- `CirceBattleStage.gd`: visão elevada, ordenação por profundidade dos pés, sprites direcionais, efeitos e transições.
- `Assets/act5_circe/battle/palace_topdown.png`: salão amplo visto de cima.
- `Assets/act5_circe/battle/palace_props.png`: mesas, colunas, raízes e grade com transparência.
- `Assets/act5_circe/battle/odysseus_directions.png`: poses frontais, traseiras e laterais de Odisseu, mantendo sua identidade, armadura dourada e capa vermelha.
- `Assets/act5_circe/battle/asset_manifest.json`: prompts completos dos recursos, criados com o ImageGen integrado; Circe mantém as poses já existentes.

A movimentação normalizada, a mira pelo mouse e a escolha direcional das animações seguem o esquema do confronto de Troia. A simulação local de Circe preserva a vida de entrada e os atributos da campanha.

Vida atual/máxima, dano, velocidade, cooldown do dash e intelecto continuam vindo de `PlayerAttributes.capture(GameManager)`, com atualizações imediatas após sacrifícios. Não existe criação livre de criaturas, tela de desenho, cliente HTTP ou necessidade de credencial. Os arquivos externos da antiga integração ficaram preservados porque a revisão automática bloqueou a exclusão fora do projeto; não são lidos nem executados pela nova batalha.

## Verificação

`scratch/test_circe_battle.gd` passou em 43 verificações, incluindo a vitória com os atributos iniciais, a movimentação nos dois eixos, a diagonal normalizada, a proteção da flor, o dano físico, a espada direcional, a observação parada, as cópias, os eventos e as rotas do salão, o reinício da luta após derrota, os controles e o progresso. O teste também cobre os passos de Circe e das cópias, o teletransporte e o contra-ataque após um golpe, a distância do dash e o progresso da recarga. `CirceBattleProbe.gd` simula os controles para verificar a luta completa.

A rota simulada concluiu o combate em cerca de 56 s com 10/10 de vida. `--capture` grava as três fases em OpenGL para inspeção visual. Os testes usam persistência desativada e confirmam que o save real não foi alterado.

Cutscenes do encontro e o resgate posterior continuam para outra etapa.
