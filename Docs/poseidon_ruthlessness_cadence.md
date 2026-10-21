# Poseidon: travessia musical e abordagem dos soldados de água

## Entrada e direção

Abra `Ato4_Tempestade/Gameplay/PoseidonEscape.tscn` e pressione F6. `cadence_enabled=true` seleciona a revisão completa. A campanha entra nela automaticamente depois do primeiro impacto da cutscene Ruthlessness. As versões anteriores continuam acessíveis com `cadence_enabled=false`: `proof_enabled=true` seleciona a prova de ruptura e `false` seleciona a travessia anterior.

A revisão mantém dez embarcações intermediárias em três blocos (3/3/4), com respiros jogáveis nos barcos3 e6. Depois há o navio de Odisseu: onze cascos jogáveis. A frota histórica tem doze navios, incluindo uma embarcação distante. Apenas o navio de Odisseu escapa.

O jogador corre, freia, recua, pula com altura variável, se abaixa e usa destroços junto à superfície do mar. A trilha organiza ataques e transições de seção, sem QTE ou obrigação de apertar teclas na batida. Ataques não têm setas, áreas marcadas ou alarmes de interface: a formação e o movimento da água fornecem a leitura física.

## Destruição e preservação do último navio

Entrar em outro barco não chama mais `_sink`. A frota recebe investidas de Poseidon em janelas musicais. Uma investida escolhe o próximo navio deixado para trás ou aquele de cuja proa o jogador está se aproximando, mostra o movimento da água e resolve o impacto2,2s depois. Permanecer mais de18s em uma embarcação também permite que ela seja alvo; não há abrigo permanente. Cada casco atingido afunda ao longo de4s, com arte e colisão acompanhando a mesma superfície.

O índice10 é exclusivamente o navio de Odisseu: `_sink` recusa esse índice, não remove seus três segmentos de convés e não derruba seu mastro. A perda da embarcação distante tem um relógio separado, `background_sunk_at`. Ela nunca é representada como dano ao navio do capitão.

## Combate final

O convés final é uma arena contínua. Dois soldados de água abordam o navio; depois de derrotá-los forma-se um guarda mais forte. Os soldados de água têm aproximação, preparação, golpe ativo, recuperação, reação ao dano e queda. Não causam dano por mero contato. Seus golpes baixos, altos e pesados pedem salto, agachamento, guarda ou recuo, conforme a ação. A espada exige alcance e direção corretos e tem recuperação; pressionar uma vez não produz ataques automáticos.

Poseidon continua atacando durante essa luta em intervalos mais espaçados, independentes das ações dos soldados de água. A vitória abre uma brecha: não surgem novos golpes, e a água que já estava em movimento conclui a animação sem causar dano. Assim o checkpoint não aprisiona quem venceu com pouco fôlego num retorno repetidamente fatal. A guarda reduz golpes físicos e não anula a água divina. Odisseu perde a tentativa ao esgotar o fôlego ou cair; Enter restaura explicitamente o checkpoint.

A bolsa fica visível na carga da proa, mas pegar ou manter E pressionado antes de derrotar os três inimigos não a libera. Depois da vitória, Odisseu a recolhe e volta pelo mesmo convés intacto até a popa. Abrir os ventos inicia a saída com o navio inteiro, preservando a continuidade narrativa. Não há mais rompimento central nem retorno por destroços no último navio.

### Controles

- A/D ou setas: correr, frear, voltar e direcionar o ataque.
- S/seta para baixo: abaixar.
- Espaço: pular; segurar permite salto mais alto.
- J ou clique esquerdo: atacar com a espada.
- Shift: manter guarda contra golpes dos soldados de água.
- Q ou botão direito do mouse: dash horizontal, no chão ou no ar.
- E: pegar a bolsa após a luta e abrir os ventos na popa.
- Esc: pausa. Enter após falhar: retomar.

O dash dura 0,2 s, conserva gravidade e colisões e não concede invulnerabilidade. Usa a mesma relação entre dash/corrida do personagem da campanha (400/120), adaptada à escala desta fase: 1016,67 px/s para corrida de 305 px/s. A recarga vem de `GameManager.player_dash_cooldown` (padrão 3 s, mínimo 0,5 s); a interface mostra quando está pronto e o tempo restante. Não pode começar durante guarda, agachamento, ataque de espada ou reação ao dano. Atingir uma parede ou receber dano o interrompe. O checkpoint preserva sua duração e recarga.

Os soldados exibem barras segmentadas e vida atual/máxima acima da cabeça, acompanhando seu movimento e desaparecendo ao se desfazerem.

### Atributos locais da fase

| Personagem | Resistência | Dano causado | Movimento |
| --- | --- | --- | --- |
| Odisseu |100 de fôlego |Atributo salvo, padrão 3 HP por golpe |305 px/s, agachado 143 px/s |
| Cada um dos dois soldados |18 HP |20 de fôlego; pesado 25 |90 px/s |
| Soldado reforçado |30 HP |20 de fôlego; pesado 25 |110 px/s |
| Poseidon |Sem barra de vida |Onda alta/baixa 28; impacto vertical 34 |Ataques ambientais |

A espada tem alcance 96 px, preparação 0,075 s, janela ativa 0,12 s e duração total 0,46 s. Salto: impulso 690 px/s, gravidade 1620 px/s² e altura máxima aproximada 147 px. A guarda frontal no chão bloqueia golpes normais, recebe 8 de dano de golpes pesados e reduz a corrida a 48%; não bloqueia Poseidon. Não há regeneração contínua de fôlego: entrada no navio final restaura 100; checkpoints de início dos blocos seguintes garantem pelo menos 75.

A espada consulta `GameManager.player_damage` ao entrar na fase; o dano é preservado no checkpoint. Assim Odisseu conserva o dano usado contra o ciclope: padrão 3, sem aumento automático ao terminar aquela luta. Com dano 3, os soldados comuns exigem 6 acertos cada e o reforçado exige 10; melhorias salvas de dano reduzem esse número. As barras mostram HP atual/máximo e limitam as divisões visuais a dez para manter a leitura.

O fôlego, a movimentação e a vida dos soldados continuam locais. A vida persistente de 10 HP, o multiplicador de velocidade e a inteligência não são aplicados automaticamente por este controlador. Dano da espada e recarga do dash consultam os atributos persistentes, sem alterar o salvamento.

## Música

Fonte: o MP4 local de Ruthlessness fornecido pelo usuário. O gerador `scratch/build_ruthlessness_score.py` e o manifesto `Assets/act4_poseidon_escape/music/score.json` registram SHA-256, cortes, arranjo, amostras e métricas.

A única fala mantida é a invocação de Poseidon da abertura, isolada em21,6–24,24s da referência. Os vamps anteriores continham coros ou versos e foram substituídos por frases instrumentais do intervalo239,711–254,545s, depois da abertura da bolsa e antes da próxima entrada vocal. Não há separação artificial de voz, nova música gerada, mudança de velocidade ou pitch.

| Seção | Papel | Duração |
| --- | --- | --- |
| intro | Invocação inicial, uma única vez |2,64s |
| surge | Primeiros três barcos |8,476825s em loop |
| wrecks | Barcos4–6 |8,476825s em loop |
| onslaught | Barcos7–10 |8,476825s em loop |
| bag | Luta e recuperação da bolsa |8,476825s em loop |
| escape | Arranjo instrumental de saída |16,35s |

A grade nominal é113,25BPM (0,529801s por beat). Os três loops são frases sobrepostas do mesmo intervalo instrumental. A entrada da frase da fuga foi organizada em3,273s para coincidir com o vento; esse ponto é uma decisão do novo arranjo, não um som narrativo preservado do vídeo original.

As emendas têm88ms. As trocas ocorrem no compasso seguinte com transição curta; saltos e ataques do jogador nunca reiniciam a faixa. A captura de checkpoint inclui clip, posição, ciclo, tempo absoluto e troca pendente. O mesmo nó de áudio permanece na árvore durante a passagem da cutscene, sem reiniciar a gravação.

As durações decodificadas e os níveis PCM/Vorbis foram verificados: nenhum clipping e RMS aproximadamente−18,5dBFS. Não houve escuta perceptiva neste ambiente; análise PCM e limites das entradas vocais orientaram os cortes. `preview_score.ogg` e `preview_wrath_7s.wav` permitem ouvir as escolhas. A avaliação humana das emendas continua sendo necessária.

## Arquivos ajustáveis

| Arquivo | Responsabilidade |
| --- | --- |
| PoseidonCadenceLevel.json | Ordem, largura, altura, vãos e carga dos barcos |
| PoseidonCadenceModel.gd | Física reutilizada, ataques divinos, perdas da frota, bolsa e checkpoints |
| PoseidonWaterBoarding.gd | Inimigos, espada, guarda, alcance, estados e ondas de abordagem |
| PoseidonCadenceStage.gd | Câmera, água, atuação, inimigos, naufrágios e navio inteiro na saída |
| PoseidonScore.gd | Relógio do mixer, loops, compassos, pausa e restauração musical |
| PoseidonEscape.gd | Entrada, teclado/mouse, interface, resultado e integração com a campanha |
| Ruthlessness.gd | Passagem da cutscene para a fase |

A apresentação é2D com sprites, recortes e interpolação. Os testes de comandos verificam travessia e combate sem teleporte, alteração de HP ou invulnerabilidade, mas não medem empolgação ou dificuldade percebida por pessoas.

## Verificação e comparação

Há testes específicos de combate, percurso, trilha, checkpoint, pausa e passagem da cutscene em `scratch/test_poseidon_water_boarding.gd`, `scratch/test_poseidon_cadence.gd`, `scratch/test_poseidon_score.gd` e cenas `test_poseidon_cadence_integration.tscn`/`test_poseidon_cadence_handoff.tscn`. A gravação usa `scratch/poseidon_cadence_demo.tscn`, um piloto de teste que normalmente envia eventos reais de teclado. Para gravar em uma janela oculta use `-- --model-input`, enviando os mesmos comandos à simulação sem depender do foco da janela. Ambos usam a física e o combate normais, sem teleporte ou invulnerabilidade. Esse piloto não faz parte da campanha.

A versão anterior à direção musical está no commit `d788ffb`. Para comparar sem descartar arquivos atuais, use outro checkout ou worktree desse commit. A revisão atual deve ser guardada em commit próprio depois da verificação. Não é necessário resetar o diretório de trabalho.


### Verificação desta revisão

- Restauração do dash: 22 verificações de duração, movimento, colisões, exclusão de ações, dano, recarga, checkpoint e congelamento sem falhas.
- Controles revisados: 16 verificações com eventos de teclado/mouse, Shift, Q, botão direito, remoção de K, importação de dano da campanha e HUD, sem falhas em headless. A captura OpenGL anterior confirmou controles e status sem cortes.
- Combate isolado: 36 verificações, nenhuma falha, incluindo dano variável, HP mínimo zero e dano salvo no checkpoint. Piloto que recua dos golpes pesados venceu em 28,9 s.
- Modelo completo: 75 verificações, nenhuma falha; piloto de movimento/combate completou 162,2 s, três soldados de água derrotados e navio final intacto, usando os novos valores de 18/30 HP e dano 3.
- Controller, trilha, checkpoint, pausa e persistência: 23 verificações, nenhuma falha, percurso de 163,6 s.
- Diretor musical:15 verificações, incluindo loop Vorbis real, relógio do mixer e seek.
- Handoff da cutscene:7 verificações, mesmo nó de áudio e mesma posição de reprodução.
- Regressão da cutscene:115 verificações; integração da prova anterior:20 verificações. Nenhuma falha.
- Seis fixtures OpenGL revisadas mostram formação dos soldados de água, combate, espada, golpe baixo, dissolução e embarcação inteira durante a fuga. Essas fixtures posicionam atores para inspeção visual e não comprovam jogabilidade; o percurso acima usa apenas comandos.

As artes de combate foram geradas com ImageGen integrado. `Assets/act4_poseidon_soldiers/generation_prompts.json` conserva prompts, referência explícita ao Odisseu existente, poses, âncoras e orientação. Os corpos são inteiramente de água e espuma, com formação e dissolução em vez de nascimento ou queda humana. Há seis poses com transições procedurais; não se trata de animação desenhada quadro a quadro. Os testes comprovam condições funcionais, sem substituir avaliação humana da dificuldade e do ritmo musical.

A prévia curta (`scratch/poseidon_cadence_preview/water_soldiers.mp4`, arquivo local ignorado pelo Git) mostra o combate final e a fuga antes das revisões de dash, barras e balanceamento. O piloto primeiro ensaia a travessia por comandos antes de gravar esse recorte, sem deslocar o jogador artificialmente.
