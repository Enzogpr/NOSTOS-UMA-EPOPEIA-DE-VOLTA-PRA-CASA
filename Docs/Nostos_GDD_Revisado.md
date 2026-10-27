==================================================
NOSTOS: UMA EPOPEIA DE VOLTA PRA CASA
Jornada do Herói + Game Design Document (GDD)
Tema: Estação (interpretada como parada/estação de ancoragem na rota
marítima de Odisseu, conceito já validado com o professor a partir de
Troia como "estação de guerra")
==================================================


==================================================
PARTE 1: A JORNADA DO HERÓI
==================================================

Mundo comum: Odisseu reina em paz como o mais sábio e forte dos reis,
guiado à distância por sua mentora, Atena, até Páris, príncipe de
Troia, raptar Helena e provocar a guerra.

Chamado para aventura: Odisseu parte para a guerra contra Troia,
deixando Ítaca e a vida pacífica de rei para trás.

Mentor: Atena, deusa protetora de Odisseu, orienta o herói no início da
jornada. Após os acontecimentos com o Ciclope, os dois rompem sua
relação. A partir daí, os ensinamentos de novas mecânicas são
apresentados pelo contexto e pela interface, sem depender da presença
da deusa em todas as estações.

Travessia do limiar: Odisseu vence a guerra de Troia,  mas o que deveria
ser uma volta simples para casa sai completamente do controle,
lançando-o numa jornada de anos pelo mar, estação após estação.

Testes e aliados: em cada estação onde Odisseu para, por vontade
própria ou não, um desafio o coloca à prova: os Lotófagos, o Ciclope, a
ilha de Éolo, Circe, o Submundo, as Sereias, Cila e Caríbdis. Ele conta
com sua tripulação para ajudá-lo sempre que precisar, mas por quanto
tempo eles resistirão?

Grande provação: no encontro com Zeus, depois que Euríloco convence a
tripulação faminta a abater o gado sagrado de Hélios contra as ordens de
Odisseu, a fúria do próprio Zeus se abate sobre o navio. Não é uma
batalha vencível, e sim uma provação de perda quase total.

Recompensa: Odisseu sobrevive à fúria de Zeus, sozinho, tendo perdido
toda sua tripulação, mas vivo, e mais perto de casa do que nunca.

Batalha final: de volta a Ítaca, Odisseu encontra seu trono tomado por
pretendentes que consomem suas terras e assediam sua esposa Penélope. A
batalha final é reconquistar seu próprio salão do trono à força, sozinho
contra muitos.

Retorno do herói: Odisseu reencontra Penélope e seu filho Telêmaco,
reassume o trono de Ítaca, e a jornada finalmente chega ao fim, o
"nostos" completo.


==================================================
PARTE 2: GAME DESIGN DOCUMENT (GDD)
==================================================

--------------------------------------------------
HIGH CONCEPT
--------------------------------------------------
Título: Nostos: Uma Epopeia de Volta pra Casa
Um jogo de ação 2D com pixel art e cutscenes ilustradas onde o jogador
guia Odisseu por treze estações míticas rumo a Ítaca, cada estação com
uma dinâmica de jogo e provação própria.

--------------------------------------------------
VISÃO GERAL
--------------------------------------------------
Título: Nostos: Uma Epopeia de Volta pra Casa
Gênero: Aventura de ação 2D híbrida, a estrutura muda de dinâmica a
cada estação (furtividade, sobrevivência, combate, escolhas morais),
unidas sob um gênero guarda-chuva próprio: "Épico".
Resumo: Após a queda de Troia, Odisseu enfrenta uma jornada de anos pelo
mar, parando em treze estações míticas que testam sua astúcia, sua
coragem e o que ele está disposto a sacrificar para voltar para casa.

--------------------------------------------------
CORE LOOP
--------------------------------------------------
Chegar a uma nova estação no mapa marítimo -> decidir se sacrifica tempo
de vida para alterar os atributos de Odisseu (mecânica de Anos, ver
seção dedicada abaixo), pelo painel acessível durante a fase ->
enfrentar o desafio único daquela estação -> gerenciar
itens obtidos no sistema de armazenamento -> tomar decisões que afetam
o que resta disponível na próxima estação (tripulantes, suprimentos,
vida) -> progresso salvo nos marcos previstos -> avançar no mapa rumo a
Ítaca -> repetir, com estações progressivamente mais custosas.

--------------------------------------------------
MECÂNICA DE SACRIFÍCIO DE TEMPO (OS ANOS DA JORNADA)
--------------------------------------------------
Durante as fases, o jogador pode abrir o painel de atributos com Tab e
ceder 1 ano de vida de Odisseu em troca de alterações permanentes de
força, velocidade, inteligência e resistência, dependendo da sua idade.
O jogo pausa durante a escolha. O sacrifício é salvo imediatamente e
não é desfeito ao reiniciar uma tentativa ou retornar a um checkpoint.
As alterações se acumulam, mas vantagens anteriores podem ser reduzidas
pelas penalidades dos anos seguintes.

No protótipo, Odisseu começa com 20 anos, 10 pontos de vida, 3 de dano,
multiplicador de velocidade 1, recarga de dash de 3 segundos e
inteligência 5. A curva atual aplica mudanças conforme a idade atingida:
- Dos 21 aos 29 anos: velocidade +0,08 e recarga do dash -0,15 segundo
  por ano sacrificado.
- Dos 30 aos 39: dano +1 e velocidade -0,04 por ano; inteligência +1
  nas idades pares; vida máxima -1 aos 30 e aos 35 anos.
- Dos 40 aos 49: inteligência +1, vida máxima -1 e recarga do dash
  +0,1 segundo por ano.
- A partir dos 50: inteligência +1, vida máxima -1 e velocidade -0,05
  por ano.
Os limites mínimos são 1 de vida máxima, 0,5 segundo de recarga do dash
e multiplicador de velocidade 0,3. Os primeiros sacrifícios não aumentam
a vida máxima na implementação atual.

Os efeitos são adaptados às mecânicas: inteligência reduz o acúmulo de
suspeita em Troia e amplia a memória do minimapa nos Lotófagos;
agilidade e inteligência afetam o controle naval e o arpão; vitalidade
e inteligência influenciam a resistência ao sono. No combate, os
atributos alteram vida, dano, movimento e recarga do dash. Na fase de
Poseidon, a capacidade de fôlego corresponde a dez vezes a vida máxima.
Vida do capitão não se transforma em vida do casco, e sacrificar anos
não cura o personagem nem desperta Odisseu automaticamente.

A idade e os atributos são salvos junto ao progresso. A contagem de anos
sacrificados continua prevista para determinar uma das duas telas
finais (ver Fim de Jogo Alternativo, na seção de Regras e Condições);
essa ligação com os finais ainda não está implementada.

--------------------------------------------------
CONTROLES
--------------------------------------------------
WASD ou Setas Direcionais = Movimentação do personagem
Espaço ou Clique Esquerdo = Atacar nas fases de combate de Troia e Ciclope
Shift ou Clique Direito = Esquiva / Dash nessas fases, quando habilitado
Tecla ESC = Pausar o jogo (abre menu de pausa, com ajuste de volume)
Tecla R = Tentar novamente nas telas de derrota que utilizam esse comando
Tecla I = Abrir o sistema de armazenamento / inventário, quando disponível
Tecla Tab = Abrir o painel de atributos e sacrifício de anos

Na navegação da tempestade, WASD/setas conduzem a embarcação, Espaço
recolhe as velas para proteção e E permite reparar em condições seguras.
No arpão de Éolia, A/D ou setas ajustam o ângulo; segurar Espaço carrega
a força e soltar dispara.

Na plataforma de Poseidon, A/D ou setas movem Odisseu, S/seta para baixo
abaixa e Espaço pula, com altura variável ao segurar. No combate do
último navio, J ou Clique Esquerdo ataca, Shift defende e Q ou Clique
Direito executa o dash. Enter retoma o checkpoint após a derrota.

Conforme a jornada avança, os controles específicos de cada estação são
apresentados na interface. Reiniciar também é uma opção do menu de pausa.

--------------------------------------------------
REGRAS E CONDIÇÕES
--------------------------------------------------
Vitória: completar o desafio específico de cada estação (ex: abrir os
portões em Troia sem ser detectado; atravessar a frota, derrotar os
soldados de água e fugir de Poseidon; capturar as Sereias antes do prazo)
e seguir viagem rumo à próxima parada. A vitória do jogo é reconquistar
Ítaca na Batalha Final.

Derrota: varia por estação. Em fases de furtividade (Troia), a barra de
suspeita cheia encerra a tentativa. Em combate, perder os pontos de vida
leva à derrota. O jogador pode reiniciar conforme a tela ou o menu da
fase, preservando os anos já sacrificados. Em sobrevivência/escolha,
a derrota significa não cumprir as condições daquele desafio antes do
tempo ou dos recursos se esgotarem. Em Poseidon, cair ou esgotar o
fôlego encerra a tentativa e permite retomar o checkpoint.

Na vigília, falhas nos dias 1 a 8 exigem nova tentativa. No dia 9, a
perda é inevitável e avança a história, sem revelar quem abriu a bolsa.
Essa perda narrativa não funciona como uma derrota comum do jogador.

Fim de Jogo Alternativo: a tela final de vitória muda de acordo com o
total de anos sacrificados ao longo da jornada.
- Poucos anos sacrificados: final "heroico", "Você completou a jornada
  em X anos, e finalmente está em casa", com Odisseu reconhecido e
  celebrado por sua família e seu povo.
- Muitos anos sacrificados: final agridoce, Odisseu vence a Batalha Final, mas
  demorou tempo de mais, seu filho já foi morto pelos traidores e sua esposa foi
  forçada a se casar com o próximo rei.

--------------------------------------------------
SALVAR / CARREGAR PROGRESSO
--------------------------------------------------
O progresso é salvo nos marcos de conclusão das etapas, registrando:
- Atos e etapas desbloqueados / próximos desafios disponíveis.
- Idade atual e atributos permanentes de Odisseu, incluindo vida máxima,
  dano, velocidade, inteligência e recarga do dash.
- Conteúdo do sistema de armazenamento (itens obtidos e ainda não
  utilizados).
Os sacrifícios também são salvos imediatamente quando realizados.

Na Tela de Título, se houver um progresso salvo, a opção "Continuar"
abre o mapa com a etapa mais avançada disponível selecionada. No Ato IV,
Tempestade, Éolia, Nove dias e Poseidon possuem desbloqueios próprios.
A conclusão de Poseidon é registrada após o fim da cutscene de fuga.
Checkpoints internos de uma fase não equivalem a uma retomada completa
no meio dela depois de fechar o jogo.

A opção separada "Novo Jogo" reinicia a jornada do zero, sobrescrevendo
o save existente. A confirmação do jogador continua prevista, mas ainda
precisa ser implementada.

--------------------------------------------------
ELEMENTOS DE JOGO
--------------------------------------------------

Protagonista (Odisseu):
- 10 pontos de vida e 3 de dano inicialmente nas estações de combate.
  Os atributos mudam com o sacrifício de anos, conforme a seção dedicada;
  na curva atual, a vida máxima pode diminuir, mas não aumenta.
- Ataque corpo a corpo com tempo de recarga entre golpes.
- Esquiva/dash para reposicionamento, sem invulnerabilidade automática.
- Muda de mecânica principal conforme a estação: furtivo em Troia
  (evitar cones de visão de guardas, usar sombras como cobertura);
  combate direto contra o Rei de Troia, Euríloco e os Pretendentes;
  navegação, mira do arpão e vigília na estação de Éolo; plataforma e
  combate contra soldados de água na primeira fúria de Poseidon.

Inimigos/Obstáculos por estação (treze estações no total, na ordem da
jornada, cada uma com uma dinâmica própria adaptada da Odisseia):

1. Rei de Troia (Furtividade + Chefão de nível): guardas patrulham com
   cones de visão, detectáveis a menos que o jogador esteja nas sombras
   (mecânica de Luz/Sombra e Campo de Visão). O chefe final tem 3 fases,
   atira e foge; avança com dash direto; volta a atirar e invoca
   guardas de apoio. Seus ataques comuns causam 1 de dano; o impacto do
   dash causa 2.

2. Ilha dos Lotófagos (Coleta / Exploração): exploração em primeira
   pessoa e em grade, sem combate, com prazo de cinco minutos. O
   jogador precisa resgatar três companheiros, obter a Flor de Lótus e
   alcançar a saída. O item fica no armazenamento para uso na estação
   seguinte; inteligência amplia a memória do minimapa.

3. Ciclope (Combate / Sobrevivência): a Flor de Lótus é combinada ao
   vinho e oferecida ao Ciclope. O confronto possui mudança de fase,
   incluindo o uso do porrete; depois, Odisseu precisa sobreviver por
   três minutos até o inimigo adormecer. O cegamento e a revelação do
   nome de Odisseu são apresentados em cutscene, seguidos pelo
   rompimento com Atena.

4. Ilha dos Céus Éolo (Navegação / Arpão / Vigília): a aproximação
   começa com uma tempestade, exigindo conduzir o navio e ajustar as
   velas. Água calma não causa dano, ondas empurram o barco e reparos
   são feitos em condições seguras. Após a descoberta da ilha no céu,
   o jogador mira e dispara um arpão contra um alvo distante e móvel,
   com tentativas ilimitadas. Diálogos acompanham a descoberta, o
   conflito com Euríloco e o encontro com Éolo, que entrega a bolsa dos
   ventos. Em seguida, Odisseu precisa mantê-la fechada durante nove
   dias: o sono cresce, a visão escurece pelas bordas e os tripulantes
   se aproximam mais depressa, inclusive dos dois lados ao mesmo tempo.
   Dormindo, ele não consegue afastá-los nem acorda sozinho. A perda
   inevitável do nono dia leva às falas de Odisseu e Penélope no escuro,
   seguidas pela tempestade que arrasta o navio para longe.

5. Poseidon — Primeira Fúria (Plataforma / Combate / Fuga): impossível
   de derrotar, o deus ataca a frota enquanto Odisseu atravessa dez
   embarcações intermediárias até chegar à própria. A travessia possui
   três sequências com breves respiros; exige saltar, agachar, recuar e
   avançar entre barcos e destroços. As embarcações são destruídas por
   ataques de Poseidon, não simplesmente por Odisseu passar por elas.
   O mar e os cavalos de água manifestam seus golpes, sem avisos
   artificiais de ataque na interface. No navio final, que não é
   destruído, Odisseu enfrenta dois soldados de água de 18 pontos de
   vida e um reforçado de 30, enquanto Poseidon continua atacando.
   Os inimigos exibem vida e recebem o dano da espada salvo na campanha.
   Ao derrotá-los, começa a cutscene: Odisseu vê a frota destruída,
   Poseidon revela que restam quarenta e três sob seu comando e pergunta
   "Últimas palavras?". Odisseu abre a bolsa e foge no próprio navio;
   Poseidon reage com "O que?" e encerra à distância com "Lembre de mim".

6. Circe (Escolha / Puzzle narrativo): sem combate direto, uma disputa
   de mente e sorte, onde as decisões do jogador podem custar o
   sacrifício de companheiros de tripulação.

7. Submundo (Provação espiritual): estação sem suprimentos
   físicos, uma descida ao mundo dos mortos para consultar o profeta
   Tirésias e descobrir a rota segura adiante.

8. Sereias (Captura sob tempo): causam 1 de dano por contato. O
   objetivo não é derrotá-las, e sim capturá-las dentro de um tempo
   limite, falhar nisso enfeitiça o jogador com o canto delas.

9. Cila e Caríbdis (Escolha sob risco): navegação apertada entre dois
   perigos simultâneos, exigindo decisão de rota sob risco constante.

10. Euríloco / A Fúria de Zeus (Combate + Grande Provação): Euríloco
    trai Odisseu e ataca diretamente, causando 2 de dano por golpe, o
    confronto que também representa a Grande Provação da jornada, com a
    ira de Zeus caindo sobre a tripulação logo em seguida.

11. Calipso (Resistência / Puzzle narrativo): não causa dano
    diretamente, o desafio é resistir às tentações do paraíso que ela
    oferece, sem ser um confronto de combate convencional.

12. Poseidon -Tempestade Final (Sobrevivência extrema / Chefão de
    nível): extremamente letal, apenas 2 golpes bastam para matar o
    jogador. Arremessa objetos à distância e invoca soldados de água.

13. Pretendentes de Penélope (Combate / Batalha Final): múltiplos
    inimigos simultâneos, cada um causando 1 de dano, que se escondem e
    tentam cercar o jogador, a Batalha Final da jornada, em Ítaca.

Itens/Coletáveis e Sistema de Armazenamento:
O jogo possui um sistema de armazenamento (inventário) onde itens
obtidos em uma estação podem ser guardados e usados em estações
futuras, reforçando a ideia de que decisões antigas afetam paradas
futuras da jornada.
- Flor de Lótus (obtida nos Lotófagos): combinada ao vinho para preparar
  a bebida oferecida ao Ciclope.
- Saco dos Ventos de Éolo (obtido na Ilha dos Céus): protegido durante a
  vigília, aberto no desfecho inevitável do nono dia e usado por Odisseu
  para escapar de Poseidon. Atualmente é controlado pelas fases e
  cutscenes, sem uso livre pelo inventário global.
- Vida: recuperação conforme as regras de cada fase e reinício, sem
  uma fonte universal de cura. O casco na navegação e o fôlego em
  Poseidon têm regras próprias.
- Tempo (Anos): não é um item armazenável, e sim a métrica central de
  progresso do jogo — não há placar/pontuação separado.

--------------------------------------------------
LEVEL DESIGN
--------------------------------------------------
O jogo é estruturado como um mapa marítimo com nós, representando as
paradas da jornada. Uma estação narrativa pode conter mais de uma fase
jogável. O mapa atual apresenta sete entradas: Troia, Lotófagos, Ciclope,
Tempestade, Éolia, Nove dias e Poseidon. Tempestade, Éolia e Nove dias
pertencem à estação de Éolo; portanto, essas sete entradas cobrem as
cinco primeiras estações da jornada prevista de treze. As demais
estações permanecem como planejadas neste GDD.

Ordem da jornada: Troia -> Lotófagos -> Ciclope -> Ilha de Éolo ->
Poseidon (Primeira Fúria) -> Circe -> Submundo -> Sereias -> Cila e
Caríbdis -> Euríloco -> Calipso -> Poseidon (Tempestade Final) ->
Pretendentes de Penélope.

A dificuldade aumenta em duas camadas: dentro de cada estação (ex: em
Troia, mais guardas e rotas de patrulha mais apertadas quanto mais perto
do portão); e entre estações, seguindo a ordem acima, terminando nas
duas estações mais punitivas do jogo (a segunda fúria de Poseidon e a
Batalha Final). O protótipo atual já apresenta variações de mecânica e
dificuldade até a primeira fúria de Poseidon; as estações posteriores
ainda serão desenvolvidas.

A primeira estação (Troia) é uma arena fechada de infiltração; a Sala do
Trono (Rei de Troia) é uma arena de combate sem esconderijos,
propositalmente mais restrita que a anterior para forçar o jogador a
focar em desviar dos ataques do chefe.

--------------------------------------------------
INTERFACE DE USUÁRIO (UI/HUD)
--------------------------------------------------
Fixo durante o jogo (varia por estação):
- Barra de suspeita (estações de furtividade).
- Barra de vida do jogador e, quando aplicável, barra de vida do chefe
  com seu nome (estações de combate).
- Condição do casco na navegação, força e ângulo no arpão, sono na
  vigília, fôlego e vida dos soldados de água em Poseidon.
- Contador de estações / progresso no mapa marítimo.
- Idade e atributos de Odisseu no painel acessível por Tab.
- Ícone de acesso rápido ao sistema de armazenamento.

Telas de menu:
- Splash Screen: tela rápida de logo/estúdio ao abrir o jogo, antes do
  menu principal.
- Tela de Título, com opções "Continuar" (se houver progresso salvo) e
  "Novo Jogo".
- Cutscene de abertura narrando a partida de Troia e a ira dos deuses.
- Cartão de transição ao entrar em cada nova estação, anunciando seu
  nome.
- Tutoriais guiados por Atena no início, respeitando seu rompimento com
  Odisseu após o Ciclope; instruções contextuais nas fases seguintes.
- Painel de atributos e sacrifício de tempo, acessível por Tab nas fases.
- Tela de sistema de armazenamento / inventário.
- Tela de Pausa, com opção de ajuste de volume (efeitos sonoros e
  música separadamente) e botão de recomeçar a estação atual.
- Tela de vitória/derrota por estação.
- Tela final de vitória do jogo — heroica ou agridoce, conforme o total
  de anos sacrificados (Fim de Jogo Alternativo).

--------------------------------------------------
ESTÉTICA (ARTE E ÁUDIO)
--------------------------------------------------
Visual: pixel art na ação e ilustrações detalhadas nas cutscenes, com
paleta de cor própria por estação para reforçar a identidade de cada
parada — tons noturnos de pedra e tocha em Troia,
azul profundo e tempestuoso nas estações de Poseidon, ambiente
exuberante e enfeitiçado em Circe e Calipso, tons acinzentados e
fantasmagóricos no Submundo.
Áudio: efeitos sonoros de passos, combate (impacto de golpes, flechas) e
ambientação própria de cada estação (mar revolto, canto das Sereias,
silêncio tenso da caverna do Ciclope, vento constante na Ilha de Éolo);
trilha sonora com clima próprio por estação, mais intensa nas duas
estações de Poseidon e na Batalha Final. Na fase atual da primeira fúria,
o áudio preserva a chamada inicial "Poseidon" e segue com o instrumental.
