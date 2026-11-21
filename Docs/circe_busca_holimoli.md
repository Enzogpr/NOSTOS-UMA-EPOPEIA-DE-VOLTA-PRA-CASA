# Circe: a flor de Hermes

Abra `Ato5_Circe/Gameplay/CirceForest.tscn` e pressione F6 para testar. Na campanha, a fase fica disponível depois de “Lembre de mim”, pelo resultado da fuga ou pela oitava entrada do mapa.

## Escopo

A fase implementa a preparação para o confronto: homens capturados → orientação breve de Hermes → busca da holimoli → retorno protegido ao palácio. O resultado oferece **Enfrentar Circe** e desbloqueia o confronto no mapa, descrito em `circe_batalha.md`. A luta usa movimento em quatro direções, proteção automática da flor e mudanças no salão. O resgate acontece depois e ainda não está implementado. A orientação usa mensagens durante o jogo; as cutscenes completas ficam para a etapa de direção narrativa posterior.

## Percurso e comandos

O percurso agora usa armadilhas encadeadas inspiradas em Level Devil, com onze gatilhos por posição, salto, aterrissagem, dash ou recuo. Uma reação pode ativar a ameaça seguinte. A sequência é determinística, sem sorteio de armadilhas: aprender o que acontece permite construir uma solução. Chão, galhos, espinhos e raízes usam as mesmas posições na simulação e na apresentação.

Os conjuntos incluem ponte que cede seguida de golpe alto, espinhos ativados durante o salto, chão de repouso que abre, ataque que pune o recuo, galho que desliza após a aterrissagem, coluna que responde ao salto, perseguição disparada pelo dash e outra coluna na última passagem elevada. A flor aparente é uma cópia: aproximar-se ou tentar colhê-la dissolve a planta, abre seu apoio e inicia um golpe pela clareira. A holimoli verdadeira fica além desse trecho. Na volta, uma aterrissagem ativa espinhos e a entrada aparente do palácio recua enquanto o último piso cede.

As colisões letais dessas armadilhas encerram a tentativa mesmo com vida cheia. A vida continua relevante para os encantamentos comuns e para o impacto das árvores. O objetivo da dificuldade é exigir descoberta, controle e execução, sem depender de aumentar o dano dos inimigos.

Na passagem de memória, observar abre as raízes seladas e revela quatro galhos reais entre cópias em alturas diferentes. A revelação dura quatro segundos após soltar E, aumentando com inteligência até sete. É possível observar novamente em um apoio seguro. A expiração esconde as pistas; ela não remove o galho em que Odisseu está pisando. As cópias nunca ganham colisão. Refração, névoa, filamentos e dissolução são animados por shader a partir do relógio da simulação, respeitando pausa e reinício.

- A/D ou setas: mover.
- S ou seta para baixo: abaixar. A caixa de colisão fica menor; soltar a tecla sob um galho não força Odisseu a se levantar dentro dele.
- Espaço: pular; segurar produz um salto mais alto.
- Q ou botão direito: dash, sem invulnerabilidade.
- E: ouvir Hermes, colher a flor ou examinar/entrar no palácio; fora dessas interações, manter E parado observa os caminhos.
- Tab: atributos e sacrifício de anos; Esc: pausa.
- R: reiniciar imediatamente o conjunto atual. R/Enter/Espaço após falhar: retomar o checkpoint. A opção de reiniciar do menu de pausa também usa esse checkpoint. Enter ao concluir: mapa.

Os encantamentos crescem e recuam com um ciclo visível antes da janela de dano. A holimoli torna esses feitiços inofensivos automaticamente e libera raízes que encurtam as passagens na volta. Árvores que estavam em pé na ida rangem e tombam durante o retorno, com dano físico independente dos feitiços. Depois da queda, os troncos permanecem como obstáculos sólidos. Quedas e madeira continuam perigosas. Os checkpoints também são adquiridos na volta. Falhar interrompe a tentativa; não existe resgate automático.

## Campanha e edição

Vida, velocidade e recarga do dash vêm da campanha. Inteligência amplia o tempo de observação. Atualizações por Tab são imediatas, sem cura, recarga gratuita ou devolução de anos no checkpoint. Dano de espada não se aplica nesta etapa sem combate.

A flor verdadeira é salva no inventário no momento da coleta; a cópia não emite esse evento. O retorno ao palácio tem seu próprio marco e a interação acompanha a posição visível da entrada. Retomar uma busca ainda não concluída com a flor recupera o retorno. Rejogar uma busca concluída inicia o desafio completo novamente: a proteção é conquistada dentro dessa tentativa, sem apagar o item, os atributos ou o progresso permanente da campanha.

Os checkpoints são mais próximos dos conjuntos de armadilhas. Recomeçar limpa projéteis e acontecimentos temporários, restaura o relógio da tentativa e usa a fração de recarga do dash registrada na entrada do conjunto, calculada sobre o atributo atual. Sacrifícios não são devolvidos. Há contagem de tentativas no HUD; não há espera obrigatória nem diálogo repetido entre tentativas.

`CirceForestLevel.json` reúne as superfícies, riscos, ilusões, checkpoints e posições. A lista `tricks` descreve condições, dependências, atrasos e efeitos de cada armadilha. `CirceTrickery.gd` interpreta essa coreografia e fornece deslocamentos e colisões. `CirceForestModel.gd` contém a simulação; `CirceForestStage.gd`, a apresentação; `CirceForest.gd`, os comandos, interface e integração com a campanha.

## Arte e áudio

As imagens finais ficam em `Assets/act5_circe/enchanted_forest.png` e `Assets/act5_circe/forest_atlas.png`. Foram criadas com o ImageGen integrado; o atlas passou por extração de fundo para preservar transparência real. Os prompts e regiões estão em `Assets/act5_circe/asset_manifest.json`. Odisseu reutiliza as poses da fase anterior. Ambiência, pássaros, sino e passos foram sintetizados localmente, sem extrair outra trilha de referência.

## Verificação

`scratch/test_circe_forest.gd` mantém 39 verificações dos sistemas de movimento, atributos, memória, checkpoints, áudio e persistência. A travessia de base desse teste desativa o diretor de armadilhas para isolar a geometria e a velocidade mínima.

`scratch/test_circe_devil.gd` passou em 24 verificações da versão completa com todas as armadilhas ativas. Uma solução de teste percorre a ida e a volta por comandos reais da simulação, incluindo as iscas de salto, a flor falsa e a entrada que muda de posição. O comportamento antigo, que só resolvia os saltos, falha nos novos espinhos. Também são conferidos encadeamento, morte por colisão, resposta de agachar, pisos que perdem sustentação, reinício determinístico, recarga proporcional, flor verdadeira e reinício pelo menu de pausa. O roteiro `scratch/CirceDevilProbe.gd` é apenas verificação, nunca controla Odisseu durante o jogo.

Os testes usam persistência isolada e confirmam que o arquivo real da campanha permanece intacto. `--capture` gera imagens OpenGL em `scratch/circe_preview/`. A solução simulada confirma uma rota possível; o balanceamento da experiência humana continua sujeito ao teste do jogador.

Regressões executadas: progresso do mapa (38 verificações), marcos reais do mapa (10), persistência dos sacrifícios (15) e desfecho de Poseidon (26), sem falhas. A renderização OpenGL foi revisada na entrada, nas ruínas, nas ilusões, na clareira, no retorno protegido e no mapa. Há um aviso de UID antigo em `PlayerStatsMenu.tscn`, anterior a esta fase; o recurso continua sendo carregado pelo caminho correto.
