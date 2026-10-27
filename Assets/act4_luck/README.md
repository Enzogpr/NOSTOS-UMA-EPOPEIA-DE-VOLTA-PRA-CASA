# A sorte acaba — conversa antes da subida

`Ato4_Tempestade/Cutscenes/LuckRunsOut.tscn` adapta visualmente o vídeo local fornecido `Luck runs out _ Epic_ The Musical.mp4`. A referência foi examinada em quadros ao longo da sequência: chegada à corda, preocupação de Euríloco, confiança de Odisseu, contato no ombro, reação à dúvida, presença dos companheiros, deslocamento para um canto e advertência em particular. O jogo usa suas próprias artes e o diálogo português do usuário; não carrega o vídeo nem seu áudio.

O texto integral está distribuído em 33 falas em `LuckRunsOut.dialogue.json`, preservando as palavras e a ordem. As falas longas foram divididas pelas frases fornecidas para caber nas duas linhas de legenda. O trecho privado começa depois de “Preciso falar com você em particular.”; a sequência termina em “Ok?”, “Ok” e “Obrigado”.

## Artes

Quatro imagens novas foram geradas com a ferramenta integrada **image_gen**, usando os personagens e o convés do jogo como referências. Os prompts completos estão em `generation_prompts.json`.

| Arquivo | Uso |
| --- | --- |
| `odysseus_luck_poses.png` | Seis poses: céu/corda, apoio, confiança, escuta, advertência e deslocamento de costas. |
| `eurylochus_luck_poses.png` | Seis poses: impedimento, pergunta, preocupação, afeto, resistência e aceitação. |
| `brothers_luck.png` | Dois planos com contato físico: mão no ombro e advertência em particular. |
| `deck_luck.png` | Convés lateral aberto, com piso para plantar os personagens e mastro fora do centro. |

Os atlas preservam o RGBA gerado. `regions.json` seleciona os desenhos em `Sprite2D.region_rect`; `scratch/inspect_luck_assets.py` reproduz os enquadramentos pelos componentes do canal alpha, evitando pedaços de uma pose vizinha e sem modificar os PNGs. O gesto de apontar também reaproveita sua versão do prólogo, com a mão inteira dentro do enquadramento. A descoberta de Eólia reaproveita `Assets/act4_storm/aeolia_discovery.png` como imagem completa.

## Movimento e câmera

`LuckStage.gd` mantém os pés dos personagens em coordenadas de convés. As poses se misturam em 0,28 s, com respiração, inclinação, tecido ao vento e pequeno movimento ao falar. `luck_actor.gdshader` limita a deformação a cada região do atlas. Há gestos adicionais durante algumas falas, plano conjunto de apoio, closes isolados, reação silenciosa, companheiros ao fundo, tracking dos dois caminhando para o mastro e retorno à corda no fim. A câmera interpola posição e escala a partir do estado atual; o fundo acompanha os limites da imagem para não revelar bordas vazias. O canto reservado ganha sombra e uma ambiência mais discreta. A fala e o avanço usam o relógio de leitura; todos os movimentos, tweens e som pausam com Esc.

## Campanha e prévia

Após acertar o aro, `AeoliaHarpoon` mantém a corda e a ilha estáveis e entra no estado `DIALOGUE`. A conversa é montada sobre o minigame, sem perder a resistência do navio, a corda ou o progresso do tiro. Ao receber uma única conclusão, remove a conversa e inicia `CLIMBING` na mesma cena, com fade de entrada. Depois segue para o encontro com Éolo. O minigame também expõe `play_climb_dialogue` para comparação no inspetor.

Abra `LuckRunsOut.tscn` com F6 para revisar a sequência completa. A leitura automática vem ativa; A ou AUTO alterna para manual. Espaço/Enter/clique revela a fala e depois avança. Pular conversa também leva à subida. No F6, `standalone_ascent` prepara diretamente a corda já presa e mostra a continuação; durante a campanha, essa opção fica desligada e o minigame existente retoma o controle.

`scratch/test_luck_dialogue.tscn` verifica 33 falas sem cortes, entrada, proteção contra comandos repetidos, diversidade de planos, deslocamento, pausa, redimensionamento e conclusão única. Com `-- --capture`, salva vinte planos em `scratch/luck_preview/`. `scratch/test_aeolia_harpoon.tscn` verifica o caminho real tempestade → descoberta → tiro → conversa → subida → Éolo, incluindo a preservação do save e a resistência do navio. `scratch/luck_demo.tscn` reproduz a sequência automática para captura de vídeo, com a passagem à subida.

Validação: 43 verificações da conversa e 57 do fluxo da campanha passaram; as capturas GL e a sequência automática até a subida foram revisadas. A versão anterior permanece no commit `d7791ea`; a implementação desta conversa fica na branch local `codex/luck-runs-out-animation`. A prévia gravada em `scratch/luck_preview/luck_runs_out.mp4` tem cerca de 1 minuto e 56 segundos, usando a leitura automática real do jogo. Referências, prévias e vídeo exportado ficam fora do Git.
