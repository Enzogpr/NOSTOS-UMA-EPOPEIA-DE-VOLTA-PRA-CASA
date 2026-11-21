# Mapa e progresso da jornada

O mapa mantém a arte existente e apresenta dezenove paradas: Troia, Lotófagos, Ciclope, Tempestade, Éolia, Nove dias, Poseidon, Circe · Holimoli, Circe · Confronto, Submundo · Fuga, Tirésias · Ecos, Sereias, Cila, Motim, Ogígia · Trilhas, Ogígia · Jangada, Caríbdis, Poseidon · Duelo e Ítaca. Tempestade até Poseidon pertencem ao Ato IV. A oitava entrada abre a busca da flor no Ato V, após o desfecho completo da fuga. A nona abre a batalha depois do retorno com a holimoli. A Fuga das Almas e Tirésias pertencem ao Ato VI. A profecia libera as Sereias no Ato VII, a vitória no recife libera Cila no Ato VIII e a saída da gruta libera o Motim no Ato IX. O desfecho atual do Motim libera as Trilhas no Ato X. A cena de Atena no mirante libera a Jangada, e a conversa com Hermes no mar registra a conclusão de Ogígia e libera Caríbdis no Ato XI. A saída de Caríbdis libera Poseidon — O Último Mar, no Ato XII. A vitória contra Poseidon libera o salão de Ítaca no Ato XIII.

## Etapas do Ato IV

`GameManager.act4_unlocked_stage` guarda o índice mais recente disponível:

| Índice | Entrada no mapa | Desbloqueio |
| --- | --- | --- |
|0 |Tempestade, com a cutscene de abertura |Ato IV liberado |
|1 |Éolia, com descoberta, arpão e encontro com Éolo |Vencer a travessia da tempestade |
|2 |Vigília dos nove dias |Terminar o encontro com Éolo |
|3 |Poseidon, com introdução, fuga, soldados e desfecho |Terminar a narrativa da vigília |

`act4_completed` só é marcado após o desfecho de Poseidon, incluindo “Lembre de mim”. Vencer apenas a luta não conclui a etapa. Os campos são salvos junto com idade, atributos e inventário. Rejogar fases anteriores não reduz o progresso; o reset da tentativa preserva esses valores. Novo jogo limpa as etapas.

## Busca da holimoli

Circe fica disponível com `act4_completed` ou com a chegada já registrada ao Ato V. O resultado da fuga oferece “Seguir para Circe”; o mapa também permite entrar diretamente na busca. `circe_moly_found` registra a coleta permanente e inclui a flor no inventário. `circe_search_completed` só é marcado quando Odisseu retorna à entrada do palácio. Concluir a busca não representa vencer Circe nem resgatar os homens.

Retomar uma busca ainda em andamento depois de colher a flor posiciona Odisseu na clareira com a proteção ativa. Rejogar uma busca já concluída inicia o desafio completo sem apagar o progresso ou o item permanente da campanha. `circe_battle_completed` marca separadamente a vitória contra Circe e não equivale ao resgate dos homens. Novo jogo limpa os três marcos e o item. Salvamentos antigos sem os novos campos mantêm o avanço anterior, sem concluir automaticamente a batalha.

Salvamentos antigos sem esses campos recuperam o acesso a Poseidon quando há um registro concluído da vigília ou uma fuga registrada na mesma pasta do salvamento. Uma fuga antiga permite rejogar o novo desfecho; só um registro com `aftermath_completed=true` marca a etapa final como concluída. A migração não grava automaticamente nem importa registros antigos para campanhas que ainda não chegaram ao Ato IV.

## Interface e navegação

O confronto com Circe oferece entrada direta no Submundo. O resgate e a ponte narrativa ainda aguardam suas cutscenes; vencer Circe não é registrado como resgate. `underworld_crossing_completed` libera Tirésias, enquanto `underworld_prophecy_completed` só é gravado após as três visões e a conversa final. As lanternas e as visões ouvidas possuem checkpoints salvos (`underworld_checkpoint` e `underworld_vision_index`); ouvir Anticleia é opcional e tem registro próprio. A profecia libera o recife no mapa e no resultado de Tirésias, inclusive para saves anteriores que já concluíram a consulta. `sirens_completed` registra a primeira vitória. Rejogar preserva os marcos. Novo jogo limpa os campos.

- Paradas disponíveis mostram seus nomes; futuras permanecem bloqueadas.
- Paradas concluídas e caminhos liberados recebem destaque dourado.
- A seleção inicial é a etapa mais avançada disponível.
- A/D e setas navegam pela ordem da jornada; clique seleciona uma parada liberada; Enter ou o botão inicia/rejoga.
- Entrada e navegação validam os bloqueios separadamente; Enter não inicia uma fase durante o movimento do marcador.
- O quadro lógico de 1152×648 é escalado e centralizado para outras janelas. O movimento do marcador usa coordenadas locais e acompanha o redimensionamento.

## Validação

- `scratch/test_world_map_progress.gd`: cobre dezenove destinos, bloqueios, caminhos de cena válidos, navegação, redimensionamento, persistência, migração e preservação dos sacrifícios.
- `scratch/test_underworld.gd`: travessia completa, falhas, checkpoints, três soluções temporais, progressão dos dois novos destinos e preservação do save real.
- `scratch/test_world_map_milestones.gd`: 10 verificações passaram nos controladores reais da tempestade, encontro com Éolo, vigília e conclusão de Poseidon.
- Regressões de sacrifícios/persistência: 15 verificações passaram. Desfecho completo de Poseidon: 26 verificações passaram.
- Renderização OpenGL revisada em 1152×648 com todas as sete etapas concluídas, como prévia do percurso completo. A imagem não modifica o progresso real.

Os testes gravam apenas arquivos temporários e verificam que o salvamento e os registros reais permanecem iguais. Os controladores da vigília e de Poseidon aceitam um caminho de registro temporário para esse isolamento; o caminho padrão da campanha permanece inalterado.
