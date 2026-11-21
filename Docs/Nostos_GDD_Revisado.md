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
guia Odisseu por quatorze estações míticas rumo a Ítaca, cada estação com
uma dinâmica de jogo e provação própria.

--------------------------------------------------
VISÃO GERAL
--------------------------------------------------
Título: Nostos: Uma Epopeia de Volta pra Casa
Gênero: Aventura de ação 2D híbrida, a estrutura muda de dinâmica a
cada estação (furtividade, sobrevivência, combate, escolhas morais),
unidas sob um gênero guarda-chuva próprio: "Épico".
Resumo: Após a queda de Troia, Odisseu enfrenta uma jornada de anos pelo
mar, parando em quatorze estações míticas que testam sua astúcia, sua
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
soldados de água e fugir de Poseidon; capturar a sereia antes que o canto tome o leme)
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

Inimigos/Obstáculos por estação (quatorze estações no total, na ordem da
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

6. Circe (Exploração / Plataforma / Combate): após a captura dos homens,
   Odisseu busca a holimoli com a orientação de Hermes. A fase atual
   atravessa ruínas com passagens baixas, raízes móveis e madeira que
   cede, caminhos ilusórios e a subida à clareira da flor. Observar
   revela temporariamente a rota real, exigindo memória e execução.
   A holimoli protege automaticamente dos feitiços e abre atalhos na
   volta; árvores que tombam mantêm o perigo físico no retorno.
   Armadilhas encadeadas reagem ao salto, à aterrissagem, ao dash e ao
   recuo. A primeira flor é uma ilusão, e a entrada aparente do palácio
   muda de posição no último trecho. Checkpoints próximos permitem
   aprender cada conjunto com novas tentativas rápidas e consistentes.
   A busca termina na entrada do palácio, onde começa o confronto.
   O confronto usa movimentação livre em quatro direções, com mira
   pelo mouse, espada, defesa e dash. A flor repele automaticamente os
   encantamentos; mesas arremessadas, raízes e golpes do cajado mantêm
   o perigo físico. Odisseu ataca nas recuperações de Circe. Na segunda
   parte, surgem cópias: segurar E, parado, revela temporariamente a
   verdadeira, enquanto movimentos e sombras oferecem pistas. Na
   terceira, colunas caem, uma passagem fecha e o piso se rompe em
   reação a ações específicas, em sequências fixas que se aprendem.
   Checkpoints preservam os atributos entre tentativas e reiniciam
   as mudanças do salão de forma consistente.
   O resgate dos homens acontece depois da vitória e ainda não está
   implementado.

7. Submundo (Provação espiritual): estação sem suprimentos
   físicos, dividida em duas fases. Na primeira, Odisseu percorre as
   margens do rio entre correntes de almas que o arrastam e aumentam
   o apego. Passar pelas aberturas evita a influência; firmar os pés
   com Shift interrompe o arrasto, mas não elimina o apego na exposição.
   Lanternas oferecem recuperação e checkpoints. Perder-se nas vozes
   exige retomar o último ponto seguro, sem alterar a vida física.
   Anticleia pode ser ouvida em uma área segura; Polites não participa.
   Na segunda fase, três provas de ecos temporais abrem o caminho até
   Tirésias. Os ecos repetem os passos anteriores e ocupam selos junto
   ao jogador, primeiro em dupla e depois com dois ecos. A inteligência
   ajuda a resistir às almas e a ativar os selos; a velocidade e a
   recarga do dash preservam os sacrifícios da campanha. As profecias
   aparecem em falas e visões breves, encerradas pelo reflexo de Odisseu
   seguindo adiante. O resgate e a transição narrativa após Circe ainda
   serão feitos; as fases já podem ser acessadas após a vitória.

8. Sereias (Perseguição em três fases): Odisseu tem 75 segundos para
   capturar uma sereia. WASD ou setas movem o navio, o mouse mira,
   clique ou Espaço lança a rede e E recolhe a corda. A sereia rompe a
   primeira rede. Na segunda fase, o canto cria duas imagens; o rastro
   na água identifica a verdadeira. Ela volta a escapar ao ser puxada.
   Na terceira fase, o canto inverte as direções do leme. O jogador
   contorna os recifes e recolhe quando a corda afrouxa. Se o tempo
   acaba, Odisseu se entrega ao canto e a tentativa termina. A captura
   final revela a gruta de Cila, e a primeira vitória registra a vida restante.

9. Cila (A gruta das seis tochas): após as Sereias, Odisseu manda
   Euríloco acender seis tochas. O navio acompanha o canal enquanto o
   jogador segura W ou seta para cima. A velocidade depende da agilidade
   da campanha. Dentro da gruta, as tochas iluminam trechos do convés,
   da água e das paredes. As investidas de Cila apagam as tochas uma de
   cada vez. Depois da última, o jogador avança no escuro até a luz da
   saída. Euríloco reconhece a relação entre os seis homens e as tochas.

10. Euríloco / A Fúria de Zeus (Combate + Grande Provação): após Cila,
    Euríloco confronta Odisseu pelas seis perdas. No duelo de quatro
    direções, Euríloco tem 15 de vida e enfrenta Odisseu com um espadão
    de duas mãos. Cada golpe de Euríloco causa 2 de dano. Odisseu pode usar
    defesa, dash e a recuperação de Euríloco para desarmá-lo. Na segunda
    parte, Euríloco pode emendar um avanço após errar a varrida. A tripulação
    intervém após o desarme. Na ilha de Hélios, Euríloco contraria a ordem
    de proteger o rebanho sagrado. O Motim termina no retorno ao navio,
    com o primeiro trovão. O julgamento e a fúria de Zeus são a próxima
    parte da provação, prevista para depois desse desfecho.

11. Calipso (Puzzle narrativo + Navegação): em A Ilha que Sempre Volta,
    as trilhas devolvem Odisseu à casa de Calipso. As marcas nas pedras
    permanecem e os sinais do mar indicam a rota até o mirante. Os sete
    anos na ilha não alteram o sacrifício de idade. Atena obtém de Zeus
    a ordem de libertá-lo. Em A Última Maré, Odisseu prepara a jangada
    e escolhe entre os recifes da enseada ou as ondas da praia aberta.
    Depois da arrebentação, Hermes aponta o caminho para Caríbdis.

12. Caríbdis (Sobrevivência cronometrada): a corrente leva a jangada
    em círculos por 55 segundos. Odisseu muda entre três faixas para
    desviar de destroços e dentes, que surgem onde a água se agita.
    A corrente acelera e as passagens diminuem até Caríbdis perder a
    força e soltar a jangada. Três impactos quebram a jangada.

13. Poseidon - O Último Mar (Sobrevivência + Duelo): depois de
    Caríbdis, Odisseu avista Ítaca e enfrenta Poseidon num recife.
    Após a queda no mar, abre a bolsa de ventos e volta à superfície
    com rajadas. O jogador atrai a estocada para a rocha, aproveita a
    abertura para desarmar o deus e pega o tridente. A arma divina
    causa dano durante as recuperações de Poseidon. A vitória faz
    o deus dissipar a tempestade que impede a chegada a Ítaca.

14. Pretendentes de Penélope (Prova do arco / Batalha Final): no
    salão de Ítaca, Odisseu dispara pelos doze machados e enfrenta
    três investidas. As colunas detêm flechas e bloqueiam a visão.
    Arqueiros buscam cobertura, espadachins atacam pelos flancos e
    os escudos abrem durante a recuperação. Cada golpe inimigo
    causa 1 de dano. A vitória leva ao reencontro com Penélope e
    Telêmaco.

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
jogável. O mapa atual apresenta dezenove entradas: Troia, Lotófagos, Ciclope,
Tempestade, Éolia, Nove dias, Poseidon, Circe - Holimoli, Circe - Confronto,
Submundo - A Fuga das Almas, Tirésias - Ecos, Sereias - O Recife do Canto, Cila -
A Gruta das Seis Tochas, Motim - O Convés Dividido, Ogígia - Trilhas
Ogígia - Jangada, Caríbdis - O Redemoinho, Poseidon - O Último Mar e
Ítaca - Os Pretendentes.
Tempestade, Éolia e Nove dias pertencem à estação de Éolo; as entradas
de Circe cobrem a busca da flor e a luta, antes do resgate. As duas entradas
do Submundo separam a travessia e a consulta ao profeta, que libera o
recife das Sereias. A captura libera Cila, cujo progresso é gravado após
a cena de saída, que libera o Motim. Na versão atual, o Motim libera
as Trilhas, e a intervenção de Atena libera a Jangada. A partida de
Ogígia libera Caríbdis, cuja travessia abre o segundo confronto com
Poseidon. O duelo libera Ítaca. O julgamento de
Zeus na estação anterior segue planejado.

Ordem da jornada: Troia -> Lotófagos -> Ciclope -> Ilha de Éolo ->
Poseidon (Primeira Fúria) -> Circe -> Submundo -> Sereias -> Cila ->
Euríloco -> Calipso -> Caríbdis -> Poseidon (Tempestade Final) ->
Pretendentes de Penélope.

A dificuldade aumenta em duas camadas: dentro de cada estação (ex: em
Troia, mais guardas e rotas de patrulha mais apertadas quanto mais perto
do portão); e entre estações, seguindo a ordem acima, terminando nas
duas estações mais punitivas do jogo (a segunda fúria de Poseidon e a
Batalha Final). O protótipo atual já apresenta variações de mecânica e
dificuldade até o confronto final no salão de Ítaca.

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
