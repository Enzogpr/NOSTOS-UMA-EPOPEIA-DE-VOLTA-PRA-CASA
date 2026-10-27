# A bolsa dos ventos

Adaptação colorida do encontro com Éolo, até “Tentaremos”, com as falas em português fornecidas pelo usuário. A referência local foi assistida por quadros extraídos de `Keep your friends close _ EPIC The Musical _ Animatic.mp4`. O vídeo de referência e seus quadros não fazem parte dos recursos distribuídos pelo jogo.

## Artes

Geradas com o imagegen integrado, usando as artes existentes como referência de identidade e estilo. Os originais gerados foram preservados. Os PNGs abaixo são cópias sem alteração de pixels; o recorte das poses usa exclusivamente os metadados de `regions.json`.

- `aeolia_terrace.png`: terraço de mármore acima das nuvens.
- `aeolus_poses.png`: seis poses de Éolo, incluindo riso, oferta, aviso e despedida.
- `odysseus_bag_poses_v2.png`: seis poses de Odisseu com rosto corrigido usando `Assets/cinematics/odysseus_clean.png` como referência, incluindo pedido, reação, proteção e apresentação da bolsa.
- `crew_poses_v3.png`: quatro poses de Perímedes e Elpenor com identidades próprias, usando o mesmo uniforme militar de bronze, couro e manto vermelho dos soldados. Perímedes tem cabelo preto curto/cacheado e rosto sem barba; Elpenor tem cabelo castanho-claro, bigode discreto, capacete e olhar atento.
- `winions_poses.png`: quatro expressões dos espíritos do vento.
- `wind_bag.png`: bolsa amarrada, usada como objeto separado na conjuração e entrega.
- `generation_prompts.json`: prompts completos, referências e transparência de cada geração.
- `revision_prompts.json` e `uniform_prompt.json`: prompts da correção dos rostos e do uniforme. Os atlas originais e a proposta civil dos tripulantes foram preservados para comparação e não são usados na cena.

O convés reutiliza `Assets/act4_luck/deck_luck.png`. Respiração, tecido, movimentos de câmera, flutuação, trajetórias dos winions e a passagem por nuvens são animados dentro do Godot. Não há dublagem sintetizada nem reprodução da música do vídeo de referência.

## Fluxo

Arpão → conversa com Euríloco → subida pela corda → `AeoliaMeeting.tscn` → entrega da bolsa → retorno ao convés → “Tentaremos” → cartão de viagem.

Abra `Ato4_Tempestade/Cutscenes/AeoliaMeeting.tscn` e use F6 para visualizar. A/Auto alterna reprodução automática, Espaço/Enter/clique revela e avança; Esc usa a pausa global. Repetir a conversa e voltar ao mapa ficam disponíveis no fim.

A cena aponta `watch_scene_path` para `Ato4_Tempestade/Gameplay/NineDaysVigil.tscn`, e o botão **Iniciar viagem** abre a fase dos nove dias. `watch_requested` avisa o início e `wind_bag_received` sinaliza a conclusão da conversa uma vez. A bolsa permanece fechada nesta conversa; visualizar/repetir não altera inventário, desbloqueios ou o save da campanha.

## Verificação

- `scratch/test_friends_dialogue.tscn`: falas, legendas, entrega da bolsa, transição, input, pausa, redimensionamento e conclusão.
- `scratch/test_aeolia_harpoon.tscn`: fluxo real do arpão até o encontro, replay/mapa e preservação de save.
- `scratch/test_luck_dialogue.tscn`: regressão da conversa antes da subida.
- `scratch/friends_demo.tscn`: grava a reprodução automática até o fim.
- `scratch/inspect_friends_assets.py`: verifica alpha e reconstrói regiões sem editar imagens.

Prévia local ignorada pelo Git: `scratch/friends_preview/friends_close.mp4`. O ponto anterior preservado no histórico é `a33a034`.
