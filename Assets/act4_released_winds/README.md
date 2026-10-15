# Os ventos libertos

Continuação da vigília depois da última fala de Penélope. Para testar só esse trecho, abra `Ato4_Tempestade/Cutscenes/ReleasedWindsPreview.tscn` no Godot e use F6. A prévia começa nos avisos finais e usa a mesma cena, falas, áudio e ações da campanha; não grava resultados.

`Ato4_Tempestade/Cutscenes/ReleasedWinds.dialogue.json` preserva as falas fornecidas, dividindo as falas longas em quadros legíveis. O fundo escuro termina no “Não!” de Odisseu. O convés reaparece em uma breve entrada de luz fria, com balanço, rajadas, chuva e câmera contínua entre os planos.

Éolo aparece em planos próprios sobre o convés. Odisseu pede ajuda com a bolsa que já está aberta; Euríloco ajuda a puxar o cordão. A força visual e sonora dos ventos diminui ao guardar o que restou. A voz final é identificada somente como **Desconhecido**, sobre um enquadramento do mar e da costa, sem rosto, símbolo ou nome que revele sua identidade. A sequência termina em “Você sabe quem eu sou?”. Nenhum plano mostra quem abriu a bolsa.

Espaço/Enter e o botão Continuar revelam/avançam falas; A alterna avanço automático e Esc pausa inclusive a animação e o clima. O resultado e o retorno ao mapa permanecem disponíveis depois da última fala.

## Imagens

- `storm_deck.png`: o mesmo convés da viagem, agora em tempestade, sem personagens pintados no cenário.
- `wind_bag_rescue.png`: dois desenhos conjuntos de Odisseu e Euríloco, com transparência nativa: bolsa aberta/tentativa de fechar e cordão apertado. Os rostos e uniformes usam os personagens canônicos como referências.
- `regions.json`: dois recortes por metadados, sem modificar a imagem gerada.
- `generation_prompts.json`: prompts completos, referências e correção de disposição da folha. Geradas com o **image_gen integrado**, sem CLI/API externa.

Éolo e os planos individuais dos soldados reutilizam as folhas existentes de `act4_friends` e `act4_luck`. Chuva, rajadas, luz e sombras são camadas procedurais independentes. O vídeo de referência foi revisto nos quadros finais (~175–203 s), em `scratch/friends_reference/`. O áudio original do musical não foi incorporado.

## Verificação

`scratch/test_vigil.tscn` cobre a perda no dia 9, os pensamentos anteriores, todas as novas falas, retorno às imagens, planos, bolsa fechada, anonimato, pausa, layout e preservação dos saves. `scratch/test_vigil_audio.tscn` verifica o crescimento da tempestade ao despertar e sua redução ao fechar a bolsa e ouvir a voz. `scratch/winds_demo.tscn` grava uma execução automática do trecho; `scratch/encode_winds_preview.py` exporta MP4 e quadros para inspeção em `scratch/vigil_preview/`, ignorado no Git.

O checkpoint anterior a esta continuação é `bed515b`.
