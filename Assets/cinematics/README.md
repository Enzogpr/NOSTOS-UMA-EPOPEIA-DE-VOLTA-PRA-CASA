# Direção cinematográfica dos atos I–III

As conversas da campanha usam o palco em camadas do adeus de Atena: cenário,
personagens, poses, câmera, luz e partículas permanecem independentes. A direção
prioriza tragédia, conflito moral e culpa, conforme solicitado. As ilustrações
originais de ação permanecem como planos narrativos com movimento e atmosfera.

## O que foi revisado

- 16 conjuntos originais de imagens/textos, 53 ilustrações únicas, os dois resgates
  de marinheiros e os quatro cartões de abertura/encerramento.
- Troia: tensão no cavalo, pressão da visão divina, hesitação diante da criança e
  uma nova composição ampla da sacada, sem marcas ou texto na imagem.
- Mar e Lotófagos: preocupação de Euríloco, comando de Odisseu, torpor dos homens
  e acolhimento do ancião. A conversa com dois interlocutores alterna o foco.
- Polifemo: luto pela ovelha, raiva, falsa cordialidade e dor após a cegueira.
- Atena: manifestação espectral e reações ao desafio de Odisseu; a vitória continua
  para a despedida em sua mente antes do encerramento do terceiro ato.

Os textos originais foram preservados. Somente duas substituições foram aprovadas:
“seus espartanos” → “seus guerreiros de Ítaca” na abertura;
“Se não foi Ninguém” → “Se foi Ninguém” na resposta dos ciclopes.
O script de auditoria compara os textos com o registro anterior às alterações.

## Recursos

Quinze novos PNGs foram gerados com a ferramenta integrada `image_gen` e copiados
para esta pasta. Os prompts completos, incluindo a revisão de Polifemo, estão em
`generation_prompts.json`. Nenhuma imagem depende da pasta externa de geração.

Os retratos `odysseus_clean`, `companions`, `lotus_elder` e `polyphemus_uninjured` possuem
quatro células iguais em uma grade 2×2, com transparência real. `deities` é um
retrato único. Cenários: `horse_interior`, `ship_deck`, `lotus_clearing`,
`lotus_shore`, `nursery` e `balcony`. A versão ferida de Odisseu e Atena vêm dos
recursos já criados para sua despedida em `Assets/act3_athena_farewell`.

A revisão do encerramento de Troia acrescenta `odysseus_stabbed_vision.png`:
Odisseu vê o próprio apunhalamento em um presságio. Após [SOLTAR],
`balcony_release.png` mostra as mãos abertas e vazias, com a ação subentendida e
sua reação de culpa. Esse plano permanece por 3,5 segundos, sem legenda, antes
do escurecimento e do cartão final. Os prompts dessa revisão estão em
`act1_revision_prompts.json`; as falas permanecem iguais.

Polifemo foi corrigido com referência direta às ilustrações originais:
`polyphemus_uninjured.png` contém quatro expressões com o olho intacto;
`polyphemus_blinded.png` é um retrato único do mesmo gigante ferido, sem venda.
Somente o diálogo depois do golpe da estaca usa a versão ferida. O antigo atlas
`polyphemus.png`, que incluía uma venda e um rosto diferente, está fora das
referências ativas. Os prompts estão em `polyphemus_revision_prompts.json`.
`scratch/test_polyphemus_continuity.tscn` confere os 41 momentos do ato III e,
com `-- --capture`, salva os novos retratos dentro das cenas renderizadas.

`direction.json` define cenários, atores, poses, reações, foco, pausas e intensidade
de cada momento sem duplicar ou reescrever o roteiro. `Code/CinematicPresenter.gd`
pagina as falas em duas linhas medidas, preservando todas as palavras; resolve
também as referências antigas a PNGs que usavam `.jpg` ou não tinham extensão.

## Controles e integração

- Espaço, Enter ou clique: primeiro revela a legenda; depois avança.
- A ou botão AUTO: ativa/desativa a leitura automática.
- Esc: pausa existente do jogo.

A reprodução para nas decisões e nos minijogos. Os controladores originais mantêm
inventário, vinho de lótus, limite de tempo, nome falso, afiação, vitória, derrota,
desbloqueio dos atos e salvamento. A escolha [SOLTAR] somente aparece depois da
narração final da sacada. Na ilha, os diálogos pausam o relógio da exploração e
devolvem o controle após o encontro. Colisões, fases de combate e mapas não foram
alterados nesta revisão cinematográfica.

## Verificação

Na raiz do projeto, execute com o Godot instalado:

```powershell
& 'C:/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://scratch/test_campaign_cinematics.tscn
& 'C:/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe' --headless --path . res://scratch/test_athena_farewell.tscn
```

O teste da campanha percorre 70 páginas dos oito controladores cinematográficos,
mais o encontro e os resgates dos Lotófagos. Confere recursos, preservação das
palavras, área de leitura, redimensionamento, pausa, avanço automático, decisões,
crafting, nome, afiação e as duas consequências do nome escolhido. O teste do
adeus verifica suas 34 falas e a ligação real com o encerramento do ato III.

Para capturas com o renderizador real, use o mesmo teste sem `--headless`, com
`--rendering-method gl_compatibility` e `-- --capture`. As prévias ficam em
`scratch/campaign_review/previews/`. A auditoria textual é
`scratch/review_campaign_sources.py`.

`scratch/test_act1_ending_revision.tscn` verifica o presságio, a espera pela
escolha manual, o plano das mãos vazias, a pausa, o escurecimento e o retorno ao
mapa. Com `-- --capture`, salva as duas novas cenas renderizadas. Esse teste
preserva o arquivo de progresso do jogador.

O projeto ainda emite um aviso antigo sobre o UID do retrato em
`Scenes/PlayerStatsMenu.tscn`; o Godot carrega esse recurso pelo caminho existente.
