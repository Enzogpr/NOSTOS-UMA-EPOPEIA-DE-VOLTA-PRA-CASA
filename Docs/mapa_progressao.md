# Mapa e progresso da jornada

O mapa agora tem **doze destinos geográficos**, cada um desenhado na nova
arte `Assets/world_map/islands_v2.png`. O desenho anterior de três regiões
não é usado na cena. Os pins são alinhados às costas, palácios, caverna,
redemoinho e demais elementos do novo arquipélago.

| Destino único | Etapas acessíveis dentro dele |
| --- | --- |
| Troia | A queda de Troia |
| Ilha dos Lotófagos | Os comedores de lótus |
| Ilha do Ciclope | Polifemo |
| Eólia | Tempestade; ilha no céu/arpão; nove dias de vigília |
| Costa dos Gigantes | Primeiro Poseidon, fuga e desfecho da frota |
| Eeia · Circe | Flor de Hermes; palácio de Circe |
| Submundo | Fuga das almas; profecia de Tirésias |
| Ilha das Sereias | O canto da sereia |
| Cila e Caríbdis | Gruta de Cila; retorno posterior ao redemoinho |
| Trinácia · Hélio | Motim |
| Ogígia · Calipso | Sete anos; última maré/jangada |
| Ítaca | Poseidon nas águas da chegada; pretendentes no palácio |

`Code/JourneyMapData.gd` centraliza destinos, posições e as dezenove cenas
anteriores. A costa dos gigantes, o Submundo e o estreito são regiões da
jornada, não ilhas inventadas para cada fase. Os dois ataques de Poseidon
são etapas das regiões onde ocorrem, sem pins de chefes.

O painel da ilha permite escolher qualquer etapa já liberada, incluindo
replays independentes. O botão principal recomenda a primeira etapa
incompleta disponível. A seleção inicial procura a próxima etapa na ordem
narrativa, inclusive quando ela exige voltar ao mesmo estreito depois de
Calipso. A rota de retorno é indicada em azul, sem duplicar o destino.

O contador superior conta destinos, não fases. Um lugar com várias etapas
continua em andamento até concluir todas; Cila permanece concluída dentro
do estreito enquanto Caríbdis aguarda a liberação. Entrar no mapa, escolher
uma ilha, viajar entre pins e rejogar não avançam o calendário da campanha.
A idade e o tempo de retorno continuam no cabeçalho.

## Etapas do Ato IV

`GameManager.act4_unlocked_stage` guarda o índice mais recente disponível:

| Índice | Entrada no mapa | Desbloqueio |
| --- | --- | --- |
|0 |Eólia → Tempestade, com a cutscene de abertura |Ato IV liberado |
|1 |Eólia → Ilha no céu, com descoberta, arpão e encontro com Éolo |Vencer a travessia da tempestade |
|2 |Eólia → Vigília dos nove dias |Terminar o encontro com Éolo |
|3 |Costa dos Gigantes → Poseidon, fuga, soldados e desfecho |Terminar a narrativa da vigília |

`act4_completed` só é marcado após o desfecho de Poseidon, incluindo “Lembre de mim”. Vencer apenas a luta não conclui a etapa. Os campos são salvos junto com idade, atributos e inventário. Rejogar fases anteriores não reduz o progresso; o reset da tentativa preserva esses valores. Novo jogo limpa as etapas.

## Busca da holimoli

Circe fica disponível com `act4_completed` ou com a chegada já registrada ao Ato V. O resultado da fuga oferece “Seguir para Circe”; o mapa também permite entrar diretamente na busca. `circe_moly_found` registra a coleta permanente e inclui a flor no inventário. `circe_search_completed` só é marcado quando Odisseu retorna à entrada do palácio. Concluir a busca não representa vencer Circe nem resgatar os homens.

Retomar uma busca ainda em andamento depois de colher a flor posiciona Odisseu na clareira com a proteção ativa. Rejogar uma busca já concluída inicia o desafio completo sem apagar o progresso ou o item permanente da campanha. `circe_battle_completed` marca separadamente a vitória contra Circe e não equivale ao resgate dos homens. Novo jogo limpa os três marcos e o item. Salvamentos antigos sem os novos campos mantêm o avanço anterior, sem concluir automaticamente a batalha.

Salvamentos antigos sem esses campos recuperam o acesso a Poseidon quando há um registro concluído da vigília ou uma fuga registrada na mesma pasta do salvamento. Uma fuga antiga permite rejogar o novo desfecho; só um registro com `aftermath_completed=true` marca a etapa final como concluída. A migração não grava automaticamente nem importa registros antigos para campanhas que ainda não chegaram ao Ato IV.

## Interface e navegação

O confronto com Circe oferece entrada direta no Submundo. O resgate e a ponte narrativa ainda aguardam suas cutscenes; vencer Circe não é registrado como resgate. `underworld_crossing_completed` libera Tirésias, enquanto `underworld_prophecy_completed` só é gravado após as seis visões e a conversa final. As lanternas e as visões ouvidas possuem checkpoints salvos (`underworld_checkpoint` e `underworld_vision_index`); ouvir Anticleia é opcional e tem registro próprio. A profecia libera o recife no mapa e no resultado de Tirésias, inclusive para saves anteriores que já concluíram a consulta. `sirens_completed` registra a primeira vitória. Rejogar preserva os marcos. Novo jogo limpa os campos.

- Todas as regiões têm nome e representação próprios; etapas futuras permanecem bloqueadas.
- Paradas concluídas e caminhos liberados recebem destaque dourado.
- A seleção inicial é o destino da etapa mais avançada disponível, incluindo revisitas.
- A/D e setas navegam pela ordem da jornada; clique seleciona uma parada liberada; Enter ou o botão inicia/rejoga.
- Entrada e navegação validam os bloqueios separadamente; Enter não inicia uma fase durante o movimento do marcador.
- O quadro lógico de 1152×648 é escalado e centralizado para outras janelas. O movimento do marcador usa coordenadas locais e acompanha o redimensionamento.

## Validação

- `scratch/test_world_map_progress.gd`: doze lugares únicos, dezenove capítulos
  preservados, arte nova, bloqueios independentes, navegação, replay, retorno a
  Caríbdis no mesmo pin, redimensionamento, saves e migração.
- Os testes de Circe, Submundo, Sereias, Cila, Motim, Calipso, Caríbdis e Ítaca
  consultam o destino e a etapa pelo nome, sem assumir um pin para cada fase.
- `scratch/test_journey_chronology.gd` verifica a leitura da idade e do tempo no
  novo mapa e que navegar pelo arquipélago não modifica o save real.
- As capturas OpenGL de Circe, Calipso e do estreito são guardadas em
  `scratch/campaign_review/world_map/`, ignorado pelo Git.

Os testes usam persistência desativada ou arquivos temporários e preservam o
save real. A implementação não altera os marcos de liberação da campanha.
