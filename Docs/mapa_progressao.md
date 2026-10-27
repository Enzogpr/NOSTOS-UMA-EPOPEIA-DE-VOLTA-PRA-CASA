# Mapa e progresso da jornada

O mapa mantém a arte existente e apresenta sete paradas: Troia, Lotófagos, Ciclope, Tempestade, Éolia, Nove dias e Poseidon. As quatro últimas pertencem ao Ato IV; `highest_unlocked_level` continua representando os atos I–IV, sem criar um ato V fictício.

## Etapas do Ato IV

`GameManager.act4_unlocked_stage` guarda o índice mais recente disponível:

| Índice | Entrada no mapa | Desbloqueio |
| --- | --- | --- |
|0 |Tempestade, com a cutscene de abertura |Ato IV liberado |
|1 |Éolia, com descoberta, arpão e encontro com Éolo |Vencer a travessia da tempestade |
|2 |Vigília dos nove dias |Terminar o encontro com Éolo |
|3 |Poseidon, com introdução, fuga, soldados e desfecho |Terminar a narrativa da vigília |

`act4_completed` só é marcado após o desfecho de Poseidon, incluindo “Lembre de mim”. Vencer apenas a luta não conclui a etapa. Os campos são salvos junto com idade, atributos e inventário. Rejogar fases anteriores não reduz o progresso; o reset da tentativa preserva esses valores. Novo jogo limpa as etapas.

Salvamentos antigos sem esses campos recuperam o acesso a Poseidon quando há um registro concluído da vigília ou uma fuga registrada na mesma pasta do salvamento. Uma fuga antiga permite rejogar o novo desfecho; só um registro com `aftermath_completed=true` marca a etapa final como concluída. A migração não grava automaticamente nem importa registros antigos para campanhas que ainda não chegaram ao Ato IV.

## Interface e navegação

- Paradas disponíveis mostram seus nomes; futuras permanecem bloqueadas.
- Paradas concluídas e caminhos liberados recebem destaque dourado.
- A seleção inicial é a etapa mais avançada disponível.
- A/D e setas navegam pela ordem da jornada; clique seleciona uma parada liberada; Enter ou o botão inicia/rejoga.
- Entrada e navegação validam os bloqueios separadamente; Enter não inicia uma fase durante o movimento do marcador.
- O quadro lógico de 1152×648 é escalado e centralizado para outras janelas. O movimento do marcador usa coordenadas locais e acompanha o redimensionamento.

## Validação

- `scratch/test_world_map_progress.gd`: 37 verificações passaram, cobrindo sete destinos, bloqueios, caminhos de cena válidos, navegação, redimensionamento, persistência, migração e preservação dos sacrifícios.
- `scratch/test_world_map_milestones.gd`: 10 verificações passaram nos controladores reais da tempestade, encontro com Éolo, vigília e conclusão de Poseidon.
- Regressões de sacrifícios/persistência: 15 verificações passaram. Desfecho completo de Poseidon: 26 verificações passaram.
- Renderização OpenGL revisada em 1152×648 com todas as sete etapas concluídas, como prévia do percurso completo. A imagem não modifica o progresso real.

Os testes gravam apenas arquivos temporários e verificam que o salvamento e os registros reais permanecem iguais. Os controladores da vigília e de Poseidon aceitam um caminho de registro temporário para esse isolamento; o caminho padrão da campanha permanece inalterado.
