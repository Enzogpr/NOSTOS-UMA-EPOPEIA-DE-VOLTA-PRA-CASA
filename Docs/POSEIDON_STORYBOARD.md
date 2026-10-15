# Poseidon — storyboard técnico e plano de implementação

Checkpoint anterior: `f0eb280`. Continuação imediata da pergunta “Você sabe quem eu sou?”, na cutscene dos ventos libertos. Escopo confirmado: falas fornecidas, até **“Morra” e o primeiro impacto**. Não implementar a fuga com a bolsa nem os acontecimentos seguintes.

## Método e limites da análise

Arquivo local: `vidssave.com Ruthlessness _ EPIC The Musical _ Animatic 720P.mp4`, 04:35, 1280×720, 12 fps. Analisei 550 quadros distribuídos do começo ao fim (2/s); os contatos, transformações, queda e confronto também foram extraídos a 6/s para inspeção. Folhas de contato em `scratch/ruthlessness_reference/`. Isso é análise visual por quadros, **não reprodução audiovisual contínua**. Os timestamps de ação são aproximados (normalmente ±0,3–0,5 s). Um contato muito rápido pode permanecer ambíguo; não atribuir intenção ou lateralidade da mão sem evidência. O ritmo das falas será conferido por transcrição local aproximada do áudio; o texto final é exclusivamente o português fornecido pelo usuário. Não incorporar música, voz ou desenhos extraídos do vídeo ao jogo.

Os desenhos alternam planos finalizados e esboços muito rápidos, principalmente em 01:54–02:09. Nessa seção identifica-se agarrar a cabeça, resistência com as mãos, torção/impacto e projeção em direção ao companheiro. O número e a lateralidade de todos os golpes não são igualmente legíveis. Preservar a trajetória e o peso dos contatos legíveis, sem inventar armas ou novos ferimentos.

## Leitura visual da referência inteira

| Referência aproximada | Composição, ação e atuação observadas | Direção e solução no jogo |
|---|---|---|
| 00:00–00:09 | Preto inicial; ondas revelam a frota em plano muito aberto. | Essa apresentação já foi preparada pelo navio levado à costa. Preservar a continuidade; condensar o preto, sem repetir uma abertura longa. |
| 00:09–00:17 | Aproximação da frota, Odisseu e companheiro olham para cima; olhos turquesa surgem no cavalo de água. | Odisseu responde “Poseidon” à pergunta anterior. Contraplano da tripulação e revelação da massa marítima, mantendo os nossos uniformes. |
| 00:17–00:23 | Cavalo colossal à direita, navio pequeno à esquerda; cabeça abaixa e água escorre. Odisseu recua o queixo. | Escala colossal, olhar para baixo, drenagem e espuma; primeira pausa de reconhecimento. |
| 00:23–00:29 | A forma humana ergue-se numa coluna de água. Manto e cabelo respondem ao vento. | Dissolução água/silhueta/corpo com base ancorada na água; aproximação vertical da câmera. |
| 00:29–00:38 | Boca em close, olho fechado, abertura lenta do olhar; ar de autocontrole e irritação contida. | Planos fechados próprios; olhar que abre gradualmente, expiração e sorriso que desaparece. |
| 00:38–00:42 | Reação de Odisseu; tecido/água atravessa o espaço, braço é preso e erguido. Poseidon domina o eixo do plano. | Contato desenhado em conjunto para que mão e pulso permaneçam unidos; antecipação, puxão e reação da capa. |
| 00:42–00:50 | Pés de Odisseu suspensos; ele procura o chão, mão livre protege o peito; Poseidon fala de cima, sorriso tenso. | Close dos pés e volta ao rosto. Elevação coerente do corpo inteiro e balanço amortecido; não deslizar pés no convés. |
| 00:50–00:56 | Soltura; Odisseu recolhe o braço. Poseidon toca o próprio peito e abre uma palma em falsa justificativa. | Recuo físico pequeno, braço protegido, reação simultânea do companheiro. |
| 00:56–01:04 | Poseidon dissolve em água escura, serpenteia ao redor dos navios e vira cavalo; frota vista de cima. | Camadas da frota e transformação por água, com rastro contínuo e movimento curvo. |
| 01:04–01:11 | Odisseu olha por cima da amurada; navios balançam, câmera avança. | Plano de reação e escala espacial; contenção de movimento de câmera durante a ameaça. |
| 01:11–01:19 | Cascos e corpo do cavalo galopam lateralmente sobre as ondas; olho turquesa em close. | Ciclo com poses de galope, passagem rápida em primeiro plano, trilha de espuma; câmera acompanha. |
| 01:19–01:29 | Cavalo salta, arqueia, mergulha e ressurge como figura humana sobre água; navio sofre o impulso. | Antecipação, arco parabólico, mergulho e onda que transfere força ao navio. |
| 01:29–01:37 | Odisseu é lançado, amortece a queda e fica apoiado em mãos/joelhos. Poseidon observa. | Pose de queda, contato no convés, recuperação de cabeça/tronco em tempos separados. |
| 01:37–01:50 | Água circunda o navio; Odisseu exausto olha de baixo. Forma humana reaparece a partir de uma poça, molda uma massa nas mãos e a desfaz. | Água procedural ao redor, materialização sem teleporte seco, gesto específico de formar/esmagar a água. |
| 01:50–01:54 | Close de Odisseu suando; Poseidon invade seu espaço e aproxima a mão da cabeça. | Contraste de escala, inclinação do deus, recuo do olhar e antecipação antes do contato. |
| 01:54–02:09 | Montagem de esboços: cabeça agarrada, Odisseu segura o antebraço para resistir; violência/torção, movimentos circulares e arremesso. Companheiro o recebe. | Sequência de contato em desenhos próprios, movimento contínuo entre preparação/aperto/resistência/soltura. Embelezamento de trajetória não substitui o contato físico. Não acrescentar violência gráfica. |
| 02:09–02:18 | Companheiro sustenta Odisseu. Close do sorriso de Poseidon; olhar do capitão baixa. Pés hesitam. | Reação apoiada e postura dolorida, câmera íntima; pausa antes da rendição. |
| 02:18–02:26 | Odisseu dobra os joelhos e se curva até o chão; Poseidon permanece imóvel acima. | Joelho toca antes das mãos; centro de massa desce em curva, capa chega depois. |
| 02:26–02:38 | Olhar lateral de Poseidon, vista alta sobre Odisseu prostrado; ele lentamente levanta o rosto. | Tempo para a humilhação respirar; respiração e olhar continuam enquanto o plano sustenta. |
| 02:38–02:49 | Odisseu oferece uma mão aberta, toca o peito e fecha os olhos ao explicar. | Apelo em quatro intenções, com olhar dirigido ao deus, sem repetir a mesma gesticulação. |
| 02:49–02:57 | Poseidon não se convence; contraplanos do capitão ajoelhado e dos homens. | Silêncio de reação, olhar severo, fechamento progressivo da luz. |
| 02:57–03:03 | Céu escurece; figura humana dissolve em cavalo monumental com olhos/dentes luminosos. | Preparação do veredito e transformação por massa d’água, com luz turquesa e pressão crescente. |
| 03:03–03:07 | Comando de morte; paredão de água cai sobre os navios. Odisseu protege a cabeça. | “Morra”, breve suspensão, primeira pancada/espuma, proteção do capitão e corte escuro. **Fim solicitado.** |
| 03:07–03:18 | Ataque continua: figuras e navios engolidos, queda submersa; preto. | Analisado, fora do escopo confirmado. |
| 03:18–03:28 | Odisseu se levanta; plano de barco destruído. | Analisado, não implementar nesta entrega. |
| 03:28–03:56 | Espaço escuro; cavalo ronda Odisseu; close dele em pânico; forma humana e conversa continuam. | Analisado, não adicionar falas nem antecipar esse acontecimento. |
| 03:56–04:11 | Bolsa levantada e aberta; deus protege o rosto; navio foge. | Analisado, reservado para continuação posterior. |
| 04:11–04:21 | Cavalo observa de longe e escurece. | Analisado, fora desta cena. |
| 04:21–04:35 | Créditos/modelos de personagem da referência. | Analisado; sem uso como conteúdo do jogo. |

## Falas e timing

O texto português fornecido é a fonte de verdade. Não acrescentar refrões, vozes da tripulação ou repetições cantadas. Cada entrada terá `ref_start`, `ref_end`, `duration`, plano, intenção, poses/reação e ações com tempos próprios. As falas longas serão divididas em legendas legíveis, sem mudar palavras. Em automático, o relógio do plano governa as ações; em manual, o plano conclui os contatos antes de permitir avançar e sustenta uma atuação viva ao final. Espaço/Enter primeiro revela o texto, depois avança; Esc pausa todos os relógios e efeitos. A ordem completa das falas estará no arquivo editável `Ruthlessness.dialogue.json`.

## Preservação e recursos

- Godot 4.7, renderizador GL Compatibility, composição lógica 1152×648 com letterbox, cenas 2D.
- Reaproveitar o apresentador de cinema (legendas, controles, pausa, enquadramento responsivo), as poses canônicas e o mecanismo de Performer do projeto. Não alterar vida, inventário, desbloqueios ou save da campanha.
- Odisseu mantém rosto maduro corrigido, cabelo comprido, barba, nariz natural, dentes íntegros, couraça de bronze com coruja, túnica escura, manto vermelho e grevas. Euríloco e os soldados mantêm seus rostos/uniformes distintos.
- Não existe arte prévia de Poseidon no projeto. Seu desenho novo deve traduzir a intenção visível da referência para a pintura pixelada do jogo: homem imponente de cabelo e barba negros longos, tecido grego claro/frio e olhar marítimo. Sem transformar nossos personagens nos modelos da referência. Não adicionar coroa, armadura ou arma em planos onde não foram identificadas.
- Novas imagens: Poseidon com gestos/expressionamento específicos; cavalo marinho em fases de transformação/galope/salto; Odisseu caído/ajoelhado/em apelo; grupos de contato físico e de apoio. Folhas com recortes explícitos e margens, transparência preservada, referências canônicas anexadas à geração.
- Limitação real: o projeto usa ilustrações 2D, não atores 3D com captura de movimento. Utilizar poses novas de contato + deformação localizada, curvas e camadas para continuidade. Não afirmar equivalência a animação desenhada quadro a quadro, nem sincronização labial fonética sem dublagem.
- Adaptar o preto e branco ao nosso colorido. Usar mar, espuma, ruído, névoa, cabelo/tecido e paralaxe em camadas. Sons de mar/água/impacto existentes ou procedurais; nenhum áudio do musical.

## Plano de implementação, em ordem

1. Salvar este storyboard e dados da análise antes de modificar o jogo; preservar checkpoint local e criar branch.
2. Conferir o ritmo falado aproximado e completar a tabela de falas. Consolidar os novos desenhos com as referências do jogo, inspecionar rostos e contato das mãos.
3. Criar uma diretoria de cena específica com relógio determinístico e configuração por plano. Reutilizar o apresentador e Performer existentes; manter câmera, corpo, reações, água e som como trilhas separadas.
4. Construir a revelação, domínio do pulso, transformação, galope/salto, queda, nova aproximação/contato, apoio do companheiro, ajoelhar/apelo e veredito. Dar antecipação e recuperação próprias aos contatos; amarrar transformações à água em movimento.
5. Conectar o final do Desconhecido à nova cena sem cartão de resultado no meio. A prévia da cena anterior deve continuar disponível; disponibilizar também F6 direto na cena nova.
6. Validar ordem e integralidade do texto, relógios, contatos, pausa/redimensionamento, transição desde a vigília, conclusão única e preservação de saves. Gravar execução automática, comparar com quadros da referência e corrigir composição/timing observados.
7. Entregar vídeo, cena F6 e registro honesto do que foi reproduzido, adaptado e limitado. Preservar código, imagens e prompts para refinamento por plano.

## Mapa final das falas para montagem

Transcrição local `base.en` concluída. Ela reconheceu incorretamente vários trechos cantados e repetiu texto no ataque; essas palavras não foram usadas. As faixas abaixo são aproximações de montagem verificadas contra a sequência visual e o texto fornecido, não alinhamento fonético certificado. A primeira identificação também não foi reconhecida de modo confiável pelo ASR. Pausas/refrões sem texto fornecido viram ação silenciosa; nenhuma nova fala é criada.

| ID | Referência (s) | Duração no jogo (s) | Personagem | Texto português | Plano |
|---|---|---|---|---|---|
| 0 | 13.50–24.40 | 6.20 | Odisseu | Poseidon | recognition |
| 1 | 24.40–31.22 | 6.82 | Poseidon | Em todos os meus anos de vida / Não é sempre que fico irritado | calm_eye |
| 2 | 31.22–33.50 | 2.80 | Poseidon | Eu tento relaxar com as ondas | calm |
| 3 | 33.50–38.78 | 5.28 | Poseidon | Mas caramba, você passou do limite | stern |
| 4 | 38.78–46.40 | 7.62 | Poseidon | Eu tenho sido tão gentil / E ainda assim, você machucou o meu filho | wrist |
| 5 | 46.40–51.46 | 5.06 | Poseidon | Isso mesmo, o ciclope que você cegou é meu | suspended |
| 6 | 51.46–52.80 | 1.80 | Odisseu | Não | denial |
| 7 | 52.80–56.68 | 3.88 | Poseidon | Fiquei sem escolha / E sem dúvida | release |
| 8 | 56.68–60.24 | 3.56 | Poseidon | Parece que a alcateia está nadando com o tubarão agora | coil |
| 9 | 60.24–63.82 | 3.58 | Poseidon | Eu tenho que fazer você sangrar / Eu preciso ver você se afogar | encircle |
| 10 | 63.82–67.98 | 4.16 | Poseidon | Mas antes de você ir, preciso fazer você aprender como | railing |
| 11 | 67.98–79.46 | 11.48 | Poseidon | Crueldade é piedade para com nós mesmos | gallop |
| 12 | 79.46–87.02 | 7.56 | Poseidon | Você é o pior tipo de bom / Porque você nem é ótimo | leap |
| 13 | 87.02–94.92 | 7.90 | Poseidon | Um grego que fede a falsa moralidade / Isso é o que eu odeio | fall |
| 14 | 94.92–99.86 | 4.94 | Poseidon | Porque você luta para salvar vidas / Mas você não mata e não termina o serviço | ground |
| 15 | 99.86–103.60 | 3.74 | Poseidon | Digo, você com certeza poderia ter evitado tudo isso | reform |
| 16 | 103.60–106.98 | 3.38 | Poseidon | Se simplesmente tivesse matado meu filho | water_cup |
| 17 | 106.98–108.30 | 1.60 | Poseidon | Mas não | crush |
| 18 | 108.30–111.30 | 3.00 | Poseidon | Você é bonzinho demais | wounded |
| 19 | 111.30–113.68 | 2.38 | Poseidon | A piedade tem um preço | loom |
| 20 | 113.68–117.14 | 3.46 | Poseidon | É a última gota, agora estamos prestes a quebrar o gelo | head_grip |
| 21 | 117.14–118.80 | 1.90 | Poseidon | Você revela seu nome | resist |
| 22 | 118.80–120.94 | 2.14 | Poseidon | Depois deixa ele viver | twist |
| 23 | 120.94–124.32 | 3.38 | Poseidon | Ao contrário de você, não tenho mais piedade para dar | throw |
| 24 | 124.32–136.26 | 11.94 | Ação silenciosa |  | support |
| 25 | 136.26–143.94 | 7.68 | Poseidon | E agora finalmente chegou a hora / De dizer adeus | kneel |
| 26 | 143.94–145.70 | 1.80 | Poseidon | Hoje você morre | verdict |
| 27 | 145.70–148.10 | 2.60 | Poseidon | A menos, é claro, que você peça desculpas | offer |
| 28 | 148.10–153.16 | 5.06 | Poseidon | Pela dor do meu filho / E todos os seus choros | above |
| 29 | 153.16–156.40 | 3.24 | Odisseu | Poseidon, não queríamos fazer mal | plea_hand |
| 30 | 156.40–159.62 | 3.22 | Odisseu | Nós só o machucamos para desarmá-lo | plea_explain |
| 31 | 159.62–162.80 | 3.18 | Odisseu | Não tivemos prazer em sua dor | plea_chest |
| 32 | 162.80–167.80 | 5.00 | Odisseu | Nós só queríamos escapar | plea_eyes |
| 33 | 167.80–171.20 | 3.40 | Poseidon | A linha entre a ingenuidade e | judge |
| 34 | 171.20–175.28 | 4.08 | Poseidon | A esperança é quase invisível | small |
| 35 | 175.80–178.00 | 2.20 | Poseidon | Então feche seu coração | darken |
| 36 | 178.00–179.50 | 1.80 | Poseidon | O mundo é sombrio e | dissolve |
| 37 | 179.50–181.78 | 2.28 | Poseidon | Crueldade é piedade | jaw |
| 38 | 181.78–185.00 | 3.70 | Poseidon | Morra | impact |

Duração de montagem: cerca de 168.8 s, mais entrada/saída. As legendas em português impõem alongamentos pequenos de leitura. A abertura 00:00–00:24 da referência é condensada para continuar a cena existente; a montagem central preserva a ordem e as durações de ação, inclusive os intervalos de galope e apoio que antes tinham refrão.
