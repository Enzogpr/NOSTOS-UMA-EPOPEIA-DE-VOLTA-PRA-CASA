# Poseidon: desfecho após os soldados de água

## Continuidade

Decisão do usuário: derrotar os três soldados passa diretamente à cutscene. Ela substitui a coleta e o retorno jogáveis com a bolsa. A travessia e o combate permanecem; Odisseu não derrota Poseidon. Seu navio continua inteiro, com 43 sobreviventes sob seu comando. A fuga só é registrada depois da última fala.

Referência: arquivo local `vidssave.com Ruthlessness _ EPIC The Musical _ Animatic 720P.mp4`. Os quadros consultados cobrem aproximadamente 3:18–4:19, em pranchas a 2 fps, com inspeção dos planos de reação, destroços, bolsa, partida e observação à distância. Isso permite comparar ordem e composição; não equivale à revisão de cada quadro nem à escuta perceptiva. As falas desta adaptação vêm do pedido do usuário.

## Storyboard técnico planejado

| Plano | Referência visual aproximada | Ação adaptada |
| --- | --- | --- |
| scan |3:20–3:25 |Odisseu recupera o fôlego e procura a tripulação com o olhar. Saem os controles da fase. |
| wrecks |3:25–3:28 |Panorama da frota destruída: cascos e mastros na água, um único navio intacto. |
| question |3:28–3:35 |Odisseu encara Poseidon e pergunta o que aconteceu com seus homens. |
| forty_three |3:36–3:45 |Poseidon: “Sobraram quarenta e três sob seu comando.” |
| reaction |3:45–3:50 |Odisseu absorve a notícia; pausa sem nova fala. |
| last_words |3:51–3:54 |Poseidon: “Últimas palavras?” |
| bag_reveal |3:56–3:58 |Odisseu decide agir e traz a bolsa para o enquadramento. |
| bag_open |3:58–3:59 |Inserto da abertura; o vento é liberado. |
| surprise |3:59–4:00 |Poseidon: “O que?”; reação ao vento. |
| escape |4:00–4:08 |O navio inteiro acelera e se afasta, com velas e mastro preservados. |
| look_back |4:08–4:10 |Odisseu olha para trás durante a partida. |
| remember |4:11–4:19 |Poseidon permanece à distância: “Lembre de mim.” Só depois encerra. |

As durações do jogo ficam no JSON de falas para ajuste individual. Foram adaptadas para leitura em português e ritmo de diálogo, mantendo a ordem dos planos. A presença de Poseidon usa sua identidade já estabelecida no jogo. A apresentação reutiliza atuação por poses, câmera e efeitos; a mudança para animação desenhada quadro a quadro foi explicitamente adiada pelo usuário.

## Implementação e validação

1. Congelar o controle da fase após a última derrota e montar o desfecho uma única vez.
2. Reutilizar o sistema visual e a interface de cutscenes, com uma direção própria para este trecho.
3. Usar as artes existentes de Poseidon, Odisseu, bolsa, mar e navio lateral; manter apenas instrumental e efeitos.
4. Registrar a fuga uma única vez ao terminar a última fala, sem permitir concluir na vitória do combate ou ao revelar a bolsa.
5. Conferir avanço manual/automático, pausa, limpeza de áudio, integridade do navio e preservação dos sacrifícios/salvamento nos testes.

## Resultado implementado e verificação

São 12 planos com 38 s de duração autorada e fade final de 0,65 s. O campo `duration` de cada entrada em `PoseidonAftermath.dialogue.json` permite ajustar os tempos; o sistema garante também um mínimo de leitura. Em modo manual, o avanço não pula a ação em curso, e a trilha pausa ao esperar pelo leitor. O instrumental existente começa ao revelar a bolsa; seu cue de vento em 3,273 s coincide com o final da abertura. Não foram adicionadas vozes em inglês.

As artes de personagens foram reaproveitadas. O close da bolsa recorta as mãos e sua abertura já desenhadas na arte de resgate, sem mostrar Euríloco. Os destroços e o navio usam o mar pintado como máscara de submersão, com espuma na linha d'água. Poseidon conserva a aparência estabelecida; o plano final o mostra como figura humana distante, adaptando a silhueta equina da referência ao personagem do jogo.

`scratch/test_poseidon_aftermath.tscn` passou 26 verificações: percurso e luta por comandos, montagem automática do desfecho, ordem dos 12 planos e cinco falas, pausa, bloqueio de avanço antecipado, conclusão única após a última fala, 43 sobreviventes e navio intacto. Metadados e duração do gameplay foram preservados. O teste não alterou o salvamento, HP, inventário ou registro reais.

Também passaram as regressões do modelo (75), ensaio manual de integração (23) e sacrifícios em Poseidon (17). Os 12 planos e uma amostra da interface completa foram renderizados e conferidos em OpenGL. Uma gravação a 30 fps gerou uma prévia de aproximadamente 39 s em `scratch/poseidon_cadence_preview/poseidon_desfecho.mp4` (arquivo local ignorado pelo Git). A inspeção da referência e a conferência visual não constituem uma avaliação perceptiva da mixagem de áudio.
