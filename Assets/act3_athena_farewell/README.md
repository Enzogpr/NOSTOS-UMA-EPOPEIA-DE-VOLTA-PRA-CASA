# O adeus de Atena — encerramento do Ato III

A cena `res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewellCutscene.tscn` entra após a sequência de vitória da fuga da caverna e a revelação do nome de Odisseu. Ao terminar, segue para `Act3_EndingCard.tscn` e o mapa existente. O caminho de derrota na caverna mantém seu game over.

## Experimento com o animatic

A apresentação padrão agora acompanha os enquadramentos do vídeo local `My Goodbye [ EPIC_ The Musical _ Animatic ].mp4` fornecido como referência. As mesmas 34 falas do JSON foram preservadas integralmente. Há planos de corpo inteiro com Atena maior que Odisseu, closes, personagem no primeiro plano, vista por cima do ombro, reprovação inclinada, confronto, reação silenciosa, ecos de memória e despedida. As cores, rostos, roupas e desenho em pixels pertencem aos personagens do jogo. O estágio mental usa um fundo azul discreto e chão com perspectiva.

`Act3_AthenaAnimatic.gd` define um plano para cada fala, com cortes, aproximação lenta, respiração, entrada dos gestos, movimento da despedida e dissolução. O relógio desses movimentos pausa com o jogo. As legendas, avanço manual/automático, ambiência e transições da campanha continuam no apresentador anterior. A sequência termina no adeus existente e na ausência de Atena; o jogo não carrega o MP4 nem suas imagens ou seu áudio.

Para comparar ou voltar imediatamente à apresentação anterior, desmarque **use_animatic** na raiz da cena e execute novamente com F6. A caverna, os retratos e a animação anteriores continuam disponíveis no mesmo arquivo de cena. O estado inteiro anterior ao experimento está salvo no commit **12eb46787e93a8e918a47cfa5ff9da8aa4531ced**, publicado em `origin/main`. Existe também a cópia `origin/codex/checkpoint-before-athena-animatic`, com a mesma árvore final de arquivos. O experimento fica na branch `codex/athena-animatic-experiment`.

`odysseus_animatic.png` e `athena_animatic.png` são atlas novos de quatro poses de corpo inteiro por personagem, gerados com a ferramenta integrada **image_gen** a partir de seus retratos existentes. Os prompts completos estão em `animatic_generation_prompts.json`. Os PNGs preservam transparência real. `animatic_regions.json` enquadra cada figura com `Sprite2D.region_rect`, incluindo cabelos/elmos que começam um pouco acima da divisão central do atlas. Os arquivos originais não são recortados nem sobrescritos. `scratch/inspect_animatic_assets.py` reproduz esses enquadramentos usando Pillow.

`scratch/test_athena_animatic.tscn` verifica as 34 falas e seus planos, regiões de imagem, proporção dos personagens, diversidade de câmera, pausa, despedida e restauração do modo anterior. `-- --capture` com renderização GL salva telas em `scratch/athena_animatic_preview/`. A suíte anterior `test_athena_farewell.tscn` continua verificando controles, redimensionamento e transições reais da campanha.

Validação: 78 verificações passaram sem janela e com renderização GL. A suíte anterior do adeus também passou, incluindo abertura, legendas, controles, pausa, redimensionamento e rotas reais de vitória/derrota/encerramento. As capturas dos planos novos, ausência de Atena e versão anterior foram conferidas visualmente.

Para experimentar sem repetir a batalha, abra a cena no Godot e pressione **F6**. O inspetor da raiz permite ajustar `autoplay`, `characters_per_second` e `playback_speed`.

- **Espaço, Enter, seta direita, botão de confirmação do controle ou clique:** revela a fala; um segundo comando avança.
- **A / botão AUTO:** alterna a leitura automática.
- **Esc:** usa o menu de pausa existente.
- **Pular cena:** encerra a conversa com a dissolução de Atena.

As 34 falas estão em `Act3_AthenaFarewell.dialogue.json`. Cada entrada informa o personagem, a pose, a reação do interlocutor, o enquadramento, a intensidade e, quando necessário, uma pausa ou efeito. O texto fornecido foi mantido, com ajustes de pontuação e acentuação para leitura.

## Artes

As três imagens foram geradas com a ferramenta integrada **image_gen**, usando as ilustrações existentes do Ato III como referências. Os prompts completos estão em `generation_prompts.json`.

| Arquivo | Uso |
| --- | --- |
| `mind_cave.png` | Caverna vazia, com abertura para o mar à noite. |
| `odysseus_expressions.png` | Atlas RGBA 2×2: luto, fúria, mágoa e determinação. |
| `athena_expressions.png` | Atlas RGBA 2×2: reprovação, ira, orgulho ferido e despedida. |
| `presence.gdshader` | Manifestação/dissolução em fragmentos, ondulação leve e integração da cintura ao cenário. |

Os PNGs originais preservam a transparência. O Godot seleciona as poses por `hframes = 2`, `vframes = 2`, sem alterar as imagens. As poses têm transições de opacidade; a respiração, flutuação, aproximação da câmera e partículas são animadas em camadas. A luz de Atena se desfaz com sua presença, deixando Odisseu sozinho durante uma pausa final. A cena inclui uma ambiência tonal suave, local à cena, pelo barramento Music.

## Verificação

`res://scratch/test_athena_farewell.tscn` verifica abertura, 34 falas, legendas sem cortes, revelar/avançar, proteção contra duplo comando, avanço automático, pausa, redimensionamento, desaparecimento completo, sinal de conclusão e transições reais de vitória/derrota/encerramento.

Execute com `godot --headless --path . res://scratch/test_athena_farewell.tscn`. Para gerar capturas com o renderer real, execute sem `--headless`, acrescentando `-- --capture`. As imagens ficam em `scratch/athena_farewell_preview/`.
