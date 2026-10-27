# Fuga de Poseidon — direção criativa e plano de desenvolvimento

Documento de trabalho para a revisão da fase após `765b54b`. Esta entrega contém diagnóstico, pesquisa e proposta. Nenhuma implementação ou arte do jogo foi alterada.

As três escolhas de direção foram alinhadas com o usuário nesta conversa:

1. Manter os dez barcos intermediários, agrupados em três sequências com respiros jogáveis.
2. Mostrar o Poseidon da cutscene em momentos marcantes; o mar e os cavalos de água executam sua vontade.
3. No último navio, recuperar a bolsa enquanto o casco se rompe e retornar por um caminho transformado.

## 1. O problema que precisamos resolver

A fase precisa transformar o poder de Poseidon em decisões do jogador. A versão atual oferece uma base funcional de plataforma, mas não sustenta uma progressão dramática própria.

| Diagnóstico | Evidência no projeto atual | Consequência de direção |
|---|---|---|
| Dez variações do mesmo módulo | `PoseidonPlatformLevel.json`; `PoseidonEscapeModel.gd:81–92`: três destroços por intervalo, igualmente espaçados, alternando caixa/viga e altura | O jogador aprende uma fórmula; aumentar a distância prolonga a fórmula |
| Destruição geralmente confirma um trecho já superado | `Model:242–277`: afundamento após o primeiro destroço, após entrar no barco seguinte ou após permanência longa | O naufrágio raramente modifica a decisão que vem pela frente |
| Não há frente de perseguição | `Model:266–287`: gatilhos locais por barco, sem ameaça espacial contínua | A urgência não corresponde a algo que se aproxima pelo cenário |
| Recuar não tem uma situação própria | `Model:298–307`: o impacto vertical mira pouco à frente e demora a cair | Seguir correndo frequentemente resolve a ameaça |
| Poseidon reage ao estado do jogador | `Stage:107–108`: pose varia conforme salto/impacto; posição permanece aproximadamente fixa na tela | O deus parece acompanhar a interface em vez de comandar o mar |
| Água e destruição pouco variam | `Stage:45–51,161–187`; `storm_water.gdshader`: imagem com distorção pequena, mesma quebra em metades | O ambiente muda pouco durante a escalada de tensão |
| Clímax é uma lista de interações | `Model:356–385`: três amarras, bolsa, popa; quebra do mastro não transforma as superfícies | A consequência visual não exige uma nova solução espacial |
| Animação e câmera ainda são de protótipo | `Stage:85–145`: acompanhamento genérico, quatro passos e três poses aéreas, trocas diretas | Falta continuidade corporal e composição própria para cada acontecimento |
| Áudio não tem linguagem de materiais/ameaças | `Escape.gd:281–319`: tempestade, bipes e o mesmo trovão para tipos de impacto diferentes | O som não antecipa nem diferencia adequadamente o que o jogador precisa ler |

O salto completo atual chega a aproximadamente 144 px de altura e 272 px de alcance na corrida. Esses números podem ser aproveitados como ponto de partida; ainda não representam uma sensação de controle aprovada pelo jogador.

O projeto tem seis WAV e não contém uma trilha musical pronta. A ambiência de tempestade tem 12 s e não recebe repetição explícita nesta fase; outros trechos do projeto já configuram `LOOP_FORWARD`. O arquivo gravado continua tendo áudio depois dos 12 s, por causa dos demais eventos: **não foi constatado silêncio total**. O problema é a ausência de uma cama sonora contínua bem controlada e a substituição frequente dos efeitos em um único player.

## 2. Método da análise e limites da evidência

Foram examinados configuração, modelo de física/progressão, câmera/renderização, controlador, áudio, testes, piloto e recursos reaproveitáveis da cutscene.

A gravação atual foi inspecionada em sequências de quadros a 4 fps nos intervalos 12–15 s, 36–39 s e 64–67 s, além dos registros de execução existentes. Isso permite comparar pose, caminho e enquadramento entre quadros, mas não equivale a um playtest humano nem a uma avaliação auditiva completa. Também foi analisada a energia do áudio do MP4, sem inferir qualidade musical a partir do volume.

Nesta revisão foram reexecutadas **32 verificações de física/progressão e 115 da cutscene anterior, sem falhas**. Os 40 testes com renderização da entrega anterior continuam como evidência técnica, não como avaliação de diversão. O piloto consulta diretamente geometria e ataques. Sua conclusão em 75,9 s, com chegada ao último navio em 58,3 s, comprova uma rota possível; não mede a experiência de alguém descobrindo o percurso.

Na pesquisa foram lidos materiais primários de desenvolvedores/publicadoras e descrições oficiais de palestras. Não foi realizada uma análise integral, quadro a quadro, dos vídeos dos quatro jogos. As propostas a seguir são adaptações autorais dos princípios documentados.

## 3. O que extrair das referências

| Referência | Princípio documentado | Aplicação proposta |
|---|---|---|
| God of War III | Stig Asmussen trata escala, fluxo visual, manutenção do controle e playtesting como problemas conjuntos | O gesto de Poseidon deve deslocar a água e modificar o espaço enquanto Odisseu continua controlável. A câmera abre para mostrar causa e consequência, preservando a aterrissagem seguinte. [Entrevista oficial](https://blog.playstation.com/2009/02/13/god-of-war-iii-press-event-qa-and-new-trailer/) |
| Ori and the Blind Forest | Mark Coates destaca ajuste minucioso do movimento, domínio de habilidades e retorno rápido à ação após falhas | Aprovar o controle em um trecho curto antes de produzir o restante. Checkpoints próximos das situações difíceis, sem repetir a apresentação inteira. [Entrevista oficial](https://news.xbox.com/en-us/2016/03/09/ori-blind-forest-definitive-edition-launch-trailer/amp/) |
| Ori and the Will of the Wisps | Gareth Coker descreve integração entre efeitos e música e contraste do muito suave ao muito poderoso | Madeira, água e respiração preparam o ataque; a música cede espaço ao aviso e volta no impacto. O máximo de intensidade fica reservado aos grandes acontecimentos. [Entrevista com Coker](https://news.xbox.com/fr-fr/2020/03/13/interview-gareth-coker-compositeur-ori-and-the-will-of-the-wisps/) |
| Uncharted 4 | Straley e Druckmann relacionam ritmo, reação física do ambiente e continuidade entre ações e escolhas | Destruir um mastro cria uma passagem; uma onda remove essa passagem e obriga a buscar outra. O espetáculo muda a ação seguinte. [Discussão da demonstração da E3](https://blog.playstation.com/?p=157699) |
| Tomb Raider | Noah Hughes descreve desafios ambientais determinados pela situação física e refinados a partir do que jogadores tentam fazer | Casco, corda, vela e mastro têm funções compreensíveis. Odisseu improvisa usando esses materiais. As situações são iteradas observando tentativas reais. [Entrevista com Hughes](https://blog.playstation.com/2011/06/24/tomb-raider-qa-searching-for-lara-croft/) |

O objetivo é transportar esses princípios para nosso jogo 2D, com nossos personagens. Nenhuma coreografia, música ou arte dessas referências será copiada.

## 4. A visão: a frota se desfaz enquanto Odisseu improvisa

A regra de direção é: **cada grande manifestação de Poseidon modifica uma decisão que o jogador ainda precisa tomar**.

Os dez barcos formam três sequências: frota reunida, frota rompida e frota submersa. Casco, mastro e destroços mudam de função ao longo delas. Os poucos respiros deixam o jogador reconhecer o próximo problema, sentir a perda e recuperar o domínio dos controles.

Meta inicial de ritmo: aproximadamente **3–4 minutos numa primeira conclusão**, a revisar após teste humano. Isso não será uma espera obrigatória ou uma duração mínima programada. Os acontecimentos avançam pela posição, pelas ações e pelo estado do cenário; animações têm o tempo necessário para serem legíveis. Uma pessoa que domina a fase deve atravessá-la mais rápido.

### Progressão dramática proposta

Os tempos abaixo são uma intenção de montagem, não os valores finais de implementação.

| Momento | Espaço / duração indicativa | O que o jogador faz | Acontecimento e intenção |
|---|---|---|---|
| Presságio | Primeiro barco; 0:00–0:15 | Recupera apoio e avança, já com controle | A cutscene terminou no primeiro impacto de “Morra”. Agora o mar recua antes da próxima investida. Cordas esticam, madeira geme e uma sombra atravessa a água. Não repetimos a introdução do deus. |
| Ameaça | Barcos 1–3; 0:15–0:50 | Combina salto e agachamento; reconhece uma saída que muda | Uma aparição de Poseidon precede a destruição de um apoio à frente. Um mastro cai, assenta e se torna a nova passagem. Ensinar a relação entre gesto, água e transformação. |
| Desespero | Barcos 4–6; 0:50–1:35 | Freia, recua e sobe para outra rota | Um casco inclina e perde o caminho inferior. A proa ameaçada é mostrada antes da ruptura. Recuar até um ponto elevado permite passar por cima da inundação. A onda perseguindo atrás pressiona essa decisão. |
| Sobrevivência | Barcos 7–8; 1:35–2:10 | Usa mastros e fragmentos em movimento; escolhe uma rota | Um abrigo de poucos segundos oferece orientação. A água cresce ao redor e elimina o caminho anterior; a próxima investida exige combinar o repertório aprendido. O respiro termina com um sinal reconhecível. |
| Clímax | Barcos 9–10 e navio de Odisseu; 2:10–3:30 | Encadeia as últimas travessias, alcança a bolsa e volta por uma rota transformada | A parede de água fecha o horizonte. No próprio navio, o cordame da bolsa é o objetivo físico central. Ao recuperá-la, o casco se rompe e muda a volta à popa. Abrir a bolsa libera os ventos e produz a saída. |
| Consequência | Saída; cerca de 10–15 s | Recupera controle em espaço seguro e percebe o vazio | A perseguição cessa. Restam mar, madeira, respiração e um único navio. A perda da frota permanece visível. A primeira resposta narrativa não será uma tela de estatísticas. |

### Uma situação exemplar, em detalhe

Odisseu chega a um convés que parece oferecer um salto simples para a frente. Uma faixa do mar se esvazia; o cavalo de água levanta o pescoço. A proa seguinte cede, fazendo o caminho de baixo ficar perigoso.

O jogador tem espaço para frear e recuar até a base do mastro. Uma vela desce: abaixar permite passar sob ela. O mastro se rompe, cai e fica apoiado no casco vizinho. Odisseu sobe pela nova passagem e salta para o outro barco enquanto a onda engole o convés de onde veio.

Essa situação exige ler, frear, recuar, abaixar e saltar. A ameaça é dirigida, mas a execução permanece do jogador. Segurar direita não resolve. O apoio seguinte é mostrado antes do compromisso com o salto.

## 5. Controle, pressão e justiça

- Preservar correr/frear, salto de altura variável e abaixar; E fica reservado a interações físicas claras. Não acrescentar um botão diferente para cada espetáculo.
- Calibrar aceleração, frenagem, correção aérea e contato dos pés antes de expandir a fase. Avaliar uma pequena tolerância de agarrar borda sem transformá-la em resgate automático de uma queda perdida.
- A frente de destruição deve ocupar o espaço, aparecer e produzir sinais sonoros. Sua velocidade precisa ser previsível em cada situação; não pode se teletransportar para punir quem joga bem.
- A pressão terá trechos apertados e respiros reais. Nenhuma mudança de câmera pode gastar secretamente o tempo de reação do jogador.
- Os primeiros ataques ensinam uma linguagem; as combinações posteriores usam essa mesma linguagem. Evitar estrear uma regra no último salto obrigatório.
- Água que causa dano e espuma decorativa precisam ter silhuetas distintas. A colisão acompanha o movimento visível da superfície; efeito algum esconde uma área segura essencial.
- Um golpe não deve ser uma queda inevitável disfarçada de perda pequena de fôlego. Refinar empurrão, apoio disponível e intensidade conforme a ameaça comunicada.
- Checkpoints por acontecimento, perto do trecho que exige domínio. Ao falhar, a tentativa termina e Enter retoma o ponto seguro; sem morte narrativa e sem Odisseu se salvar sozinho no salto.
- Retomadas restauram a mesma geometria, fase dos apoios móveis e preparação dos ataques. Variações cosméticas podem mudar; o desafio precisa continuar compreensível.

## 6. Direção visual, animação e câmera

Poseidon terá antecipação, ação e recuperação. Sua figura aparece em poucos enquadramentos fortes, preservando o desenho da cutscene. Os cavalos de água são extensões dessa presença, conectados às ondas e às transformações do caminho.

A composição será organizada em três profundidades: ameaça distante; plano de madeira jogável; espuma e detritos frontais discretos. A água muda de comportamento — recua, se concentra, levanta e invade — em lugar de manter a mesma tempestade durante toda a fase.

A câmera acompanha os saltos de forma estável. Abre nos impactos que exigem mostrar a escala, incluindo a próxima aterrissagem no enquadramento. O tamanho aparente e a prioridade do personagem precisam permanecer legíveis. Tremor curto é a confirmação de um impacto específico; não será movimento permanente de toda a imagem.

Animações prioritárias: corrida cíclica sem escorregar; freio e mudança de direção; preparação/aterrissagem; abaixar e levantar; esforço sob vento; reação a impacto; pegar e carregar a bolsa. Usar uma referência de identidade e escala consistente. Sprites articulados podem ajudar em movimentos secundários, desde que não deformem rosto e armadura; ações principais precisam de poses adequadas.

Destruição terá fases distintas: tensão da estrutura, rachadura, quebra, queda, impacto na água e novo apoio. Os barcos não terão todos o mesmo destino visual nem a mesma função de plataforma.

O HUD deve mostrar objetivo e condição quando necessários. Avisos ambientais substituem gradualmente instruções constantes de “pule/abaixe”, mantendo ajuda inicial e opções de legibilidade. Os números do desempenho podem ficar disponíveis depois da consequência narrativa.

## 7. Direção sonora

Precisamos de fontes independentes para mar contínuo, madeira sob esforço, passos/aterrissagem, arrebentação, vento e presença divina. Impactos simultâneos não podem se cortar por disputar um único player. Há uma correção de loop já usada no projeto que pode ser reaproveitada.

Antes de golpes grandes, a música e parte da tempestade cedem espaço à madeira e à água recuando. O ataque ocupa o espectro grave e a retomada musical; o próximo aviso continua audível. Música e eventos se sincronizam nos marcos da sequência, sem exigir que o jogador siga um metrônomo.

Uma trilha adaptativa de qualidade depende de material musical apropriado, que ainda não existe no repositório. Primeiro validar o desenho sonoro e os pontos de entrada/saída; depois trabalhar com composição original ou material escolhido para essa finalidade. Não confundir bipes procedurais com a trilha final.

## 8. Plano técnico após a apresentação desta direção

1. **Trecho de prova de 30–45 s, com cenário simples.** Implementar uma situação representativa que obrigue avanço, freio/recuo, agachamento e salto, com uma destruição que realmente altere o caminho. Deve funcionar sem depender da arte final.
2. **Teste do usuário e revisão do controle.** Comparar primeira tentativa, erro e retomada. Registrar onde a pessoa não viu o apoio, sentiu falta de resposta ou não entendeu a falha. Acertar isso antes da expansão.
3. **Direção completa nesse mesmo trecho.** Aplicar atuação de Poseidon, água, câmera, animação, materiais e som sincronizados aos mesmos eventos. Revisar em movimento e em velocidade normal.
4. **Expandir para as três sequências.** Produzir situações distintas para os dez barcos, com introdução, combinação e inversão de regras. Montar o desafio da bolsa com a rota transformada.
5. **Integração, desempenho e acabamento.** Conferir entrada após “Morra”, checkpoints, bolsa, fuga e consequência. Medir o tempo de quadro normal no equipamento disponível; a velocidade de gravação MovieMaker não é essa medição. Limitar camadas transparentes e partículas e oferecer redução de tremor.

A arquitetura `Model → Stage → Control` é reaproveitável. O modelo deve continuar sendo a autoridade sobre apoio, colisão, perigo e progressão. Um diretor por situação pode coordenar apresentação e áudio pelos eventos, sem mover hitboxes para melhorar uma captura.

**Limitação técnica real:** as superfícies atuais são retângulos alinhados aos eixos. Um navio inclinado que transporta o jogador precisa de suporte móvel e rampas/segmentos de colisão compatíveis. Rotacionar apenas a arte produziria uma divergência inaceitável. Esse suporte deve ser provado no primeiro trecho.

Godot 4.7 com GL Compatibility permite composição 2D em camadas, shaders CanvasItem, malhas simples e partículas moderadas. Não há necessidade de migrar o jogo para 3D nem de prometer um oceano fisicamente simulado.

## 9. Critérios para continuar a produção

- O trecho de prova precisa exigir decisões além de manter uma direção e repetir salto.
- O jogador deve conseguir explicar por que errou e qual ação tentará na próxima vez.
- Cada grande golpe deve ter preparação reconhecível, área legível e consequência coerente no caminho.
- A próxima aterrissagem precisa aparecer antes do salto; personagem, colisão e superfície não podem divergir durante inclinação/queda.
- A retomada não pode começar num estado já perdido ou exigir rever uma longa apresentação.
- A sensação de controle deve ser aprovada em teste humano. Piloto e testes automatizados ficam responsáveis por regressões, determinismo, colisão e integração.
- O primeiro trecho com direção final deve sustentar a intenção em movimento e com som antes de replicarmos sua produção para o restante da fase.

A primeira entrega dessa direção foi implementada como trecho representativo e está descrita em [POSEIDON_TRECHO_DE_PROVA.md](POSEIDON_TRECHO_DE_PROVA.md). A expansão para as três sequências depende da avaliação desse trecho.
