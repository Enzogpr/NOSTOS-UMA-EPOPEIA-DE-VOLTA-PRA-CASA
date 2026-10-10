# O adeus de Atena — encerramento do Ato III

A cena `res://Ato3_Ciclope/Cutscenes/Act3_AthenaFarewellCutscene.tscn` entra após a sequência de vitória da fuga da caverna e a revelação do nome de Odisseu. Ao terminar, segue para `Act3_EndingCard.tscn` e o mapa existente. O caminho de derrota na caverna mantém seu game over.

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
