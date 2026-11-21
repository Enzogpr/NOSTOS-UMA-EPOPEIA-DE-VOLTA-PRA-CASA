# Submundo — fuga e ecos

Duas fases após a vitória contra Circe. Odisseu foge das almas na margem do rio e encontra Tirésias na outra margem. Anticleia espera em uma clareira durante a fuga.

## A fuga das almas

Odisseu corre automaticamente por uma via de pedra com três faixas e acelera conforme avança. A/D ou as setas laterais trocam de faixa, Espaço pula pedras baixas, S ou ↓ desliza sob vigas e Q usa o dash da campanha para ganhar distância das almas. Colunas altas exigem mudar de faixa. Um tropeço reduz a velocidade por um instante e aproxima os perseguidores.

A primeira viga permite desviar pela faixa livre. As vigas seguintes podem atravessar todas as faixas. Depois de Anticleia, o percurso combina saltos, deslizes e mudanças de faixa com intervalos mais curtos. O deslize dura 0,62 s. Um comando de deslize logo antes de aterrissar ou um salto no fim do deslize entra assim que Odisseu recupera a postura.

A culpa de Odisseu deforma a perspectiva. Dois arcos aparentes recuam quando a distância real diminui. A deformação cede no trecho final, onde as três faixas se estreitam até a passagem verdadeira. O avanço da travessia é medido pela distância percorrida e a leitura dos obstáculos próximos continua estável.

As lanternas registram o ponto inicial e duas retomadas. Quando as almas alcançam Odisseu, R ou a opção de reiniciar no menu de pausa retomam a última lanterna.

Na última lanterna, a corrida pausa na clareira. E abre a conversa com Anticleia em texto. O jogador pode ler a memória ou continuar a fuga, e a leitura completa fica registrada.

## Os ecos de Tirésias

O jogo guarda os passos, a direção e as pausas de Odisseu. O primeiro eco repete a gravação após um intervalo. O segundo, quando presente, repete um momento duas vezes mais antigo. Os selos indicam quem pode ativá-los.

1. **A primeira pegada.** Odisseu e o primeiro eco ocupam dois selos ao mesmo tempo.
2. **A ponte que cede.** O eco mantém a ponte aberta enquanto Odisseu cruza.
3. **As duas margens.** Duas pontes respondem a ecos diferentes.
4. **O reflexo invertido.** O eco repete a gravação na margem oposta, espelhada.
5. **A ordem dos passos.** Os dois ecos e Odisseu acendem três selos na ordem marcada.
6. **O último passo.** Odisseu prepara duas gravações para atravessar as duas pontes até a ilha do profeta.

R reinicia a prova atual e E mostra uma dica. Uma ponte temporária que cede devolve Odisseu ao último chão firme. O intervalo dos ecos aumenta nas travessias mais longas e para personagens mais lentos. Inteligência reduz o tempo de sustentação conjunta dos selos. Mudar a velocidade pelos sacrifícios limpa as gravações feitas no ritmo anterior. As provas resolvidas permanecem registradas.

Cada prova revela uma das seis falas de Tirésias acompanhada de uma visão. Depois da sexta, o caminho permanece aberto para Odisseu se aproximar do profeta. As duas falas finais têm avanços separados. Após a conversa, o reflexo continua caminhando por alguns instantes enquanto Odisseu permanece parado. O jogador pode seguir para as Sereias ou voltar ao mapa.

## Integração e recursos

- Entrada direta no resultado da batalha de Circe e dois destinos próprios no mapa.
- `GameManager` salva a conclusão de cada fase, a lanterna, a última visão lida e o encontro com Anticleia. As campanhas que já haviam concluído a versão de três visões preservam o acesso às Sereias e o avanço posterior.
- A vida atual, o dano, a idade e o inventário não são reiniciados. A inteligência, a velocidade e o dash continuam sendo afetados pelos sacrifícios. Vida e dano não viram recursos espirituais.
- A trilha da travessia usa o ambiente do rio e efeitos de ação. Anticleia e Tirésias aparecem em diálogos de texto.
- Arte em `Assets/act6_underworld`; prompts e layout em `asset_manifest.json`. Foram gerados fundo da margem, lago do oráculo e atlas de almas/Anticleia/Tirésias/pedra com a ferramenta ImageGen. Odisseu é reaproveitado da batalha de Circe. As visões usam recursos existentes do navio e de Ítaca.
- `UnderworldCrossingModel.gd` define o percurso e os obstáculos. `UnderworldRunStage.gd` desenha a perspectiva. Os selos de Tirésias e os diálogos ficam em `UnderworldLevel.json`.

Referência narrativa: *The Underworld* e *No Longer You*, da saga do Submundo de EPIC. Esta implementação adapta os temas para gameplay original; não declara reprodução plano a plano de animatics. O resgate dos homens, a despedida de Circe e as grandes cutscenes de ligação ainda ficam para a etapa narrativa posterior, conforme a prioridade de construir primeiro as fases.

## Verificação

`scratch/test_underworld.gd` verifica a corrida completa nas velocidades 0,3 / 1 / 1,72 / 2, a aceleração, o recuo aparente do arco, os obstáculos, o deslize, a retomada, o diálogo em texto, as três provas de Tirésias, o teclado, a pausa e a preservação do save.

`scratch/preview_underworld.gd` produz capturas OpenGL da fuga, da distorção, de Anticleia, da chegada e das provas de Tirésias em `scratch/underworld_preview/`, com a gravação de progresso desativada.
