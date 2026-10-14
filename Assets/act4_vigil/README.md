# Nove dias de vigília

Cena jogável: `Ato4_Tempestade/Gameplay/NineDaysVigil.tscn`. Abra no Godot e use F6. O botão **Iniciar viagem**, no fim do encontro com Éolo, abre esta fase.

## Regras

- Nove dias de 25 segundos, com amanhecer/tarde/noite e breves transições; cerca de quatro minutos até o desfecho.
- Espaço desperta Odisseu quando a sonolência está entre 60% e 92%. Despertar depois disso ainda ajuda, mas recupera menos concentração. Apertar antes do sinal aumenta levemente o cansaço; segurar a tecla não repete a ação.
- A/D ou setas escolhem o lado observado; E afasta o tripulante daquele lado quando ele se aproxima. Há também botões para mouse.
- O sono sobe mais rápido, os tripulantes caminham mais depressa e as aproximações ficam mais frequentes nos dias seguintes. Há no máximo um visitante nos dias 1–3 e dois depois.
- Um cochilo ou uma aproximação não impedida afeta a concentração e o registro do dia. A bolsa fica fechada até o evento final: não há morte, perda antecipada nem repetição obrigatória.
- A partir do dia 5, Penélope aparece como uma lembrança durante o cansaço. Ítaca surge no horizonte no final da viagem.
- Ao terminar o dia 9, os controles desaparecem. Odisseu dorme, Euríloco solta o cordão da bolsa e os ventos escapam. O mesmo final acontece após uma vigília perfeita.
- O resultado mostra aproximações impedidas, despertares e dias impecáveis, oferecendo replay opcional e retorno ao mapa.

Esc pausa todo o jogo, a animação e a cena final. A composição usa 1152×648 com letterboxing para outras proporções.

## Registro

`user://vigil_record.json` guarda a última vigília e os melhores números de dias impecáveis/aproximações impedidas. O save da campanha, os desbloqueios, a vida do navio e o inventário não são alterados. Testes e gravações usam `persist_record=false`.

## Artes

Quatro assets foram gerados com **imagegen integrado** e copiados para esta pasta, preservando os originais gerados e o alpha:

- `odysseus_vigil.png`: quatro poses sentadas do Odisseu, mantendo o rosto corrigido, armadura, manto e bolsa.
- `penelope_vision.png`: retrato transparente da lembrança de Penélope.
- `deck_ithaca.png`: mesmo convés, com Ítaca distante sobre o mar.
- `wind_bag_betrayal.png`: poses combinadas de Euríloco soltando o cordão e da bolsa aberta libertando os ventos.
- `generation_prompts.json` e `betrayal_prompt.json`: prompts completos e caminhos das referências.
- `regions.json`: recortes por metadados. Os dois quadros do final compartilham escala e linha de chão, mesmo com a coluna de vento maior.

Perímedes/Elpenor reutilizam o uniforme e rostos de `Assets/act4_friends/crew_poses_v3.png`; Euríloco reutiliza `Assets/act4_luck/eurylochus_luck_poses.png`. Sons de atenção/passos e mar são procedurais; a tempestade reutiliza o áudio do ato 4. Não há dublagem nem música extraída do musical.

## Verificação

- `scratch/test_vigil.tscn`: simulação dos nove dias com desempenho perfeito e sem ações; cooldown, aproximações, erros, final inevitável, inputs reais, pausa, redimensionamento, visões, contato com a bolsa, resultado e preservação de saves.
- `scratch/test_aeolia_harpoon.tscn`: fluxo da tempestade/arpão/subida/encontro até a abertura da fase.
- `scratch/test_vigil_audio.tscn`: áudio do mar/ventos e liberação dos players ao sair da cena.
- `scratch/inspect_vigil_assets.py`: verifica transparência e reconstrói os recortes sem editar os PNGs.
- `scratch/vigil_demo.tscn`: prévia abreviada com dias de nove segundos. A fase normal mantém os 25 segundos e responde ao jogador.

Imagens e vídeo de QA ficam em `scratch/vigil_preview/`, ignorado no Git. O ponto anterior desta implementação é `1315857`, preservado no histórico da branch anterior.
