# Nove dias de vigília

Cena jogável: `Ato4_Tempestade/Gameplay/NineDaysVigil.tscn`. Abra no Godot e use F6. O botão **Iniciar viagem**, no fim do encontro com Éolo, abre esta fase.

## Regras

- Nove dias de 25 segundos, com amanhecer/tarde/noite e breves transições.
- Espaço desperta Odisseu manualmente entre 60% e 92% de sonolência. Acima disso recupera menos; antes disso aumenta levemente o cansaço. Segurar a tecla não repete a ação. Amanhecer não recupera sono automaticamente.
- A/D ou setas escolhem o lado observado; E afasta o tripulante daquele lado quando ele se aproxima. Há também botões para mouse. A partir de 60% de sonolência, E fica bloqueado até o jogador despertar.
- Nos dias 1–8, chegar a 100% de sono ou deixar alguém alcançar a bolsa causa derrota real, com opções de tentar novamente ou voltar ao mapa. Odisseu não desperta nem afasta visitantes sozinho.
- O sono sobe mais rápido, os tripulantes caminham mais depressa e as aproximações ficam mais frequentes a cada dia. Há um visitante por vez nos dias 1–2; a partir do dia 3 podem vir dois juntos, um de cada lado. Os pares são garantidos nos dias 8–9.
- A visão escurece das bordas para o centro conforme o sono e os dias avançam. Os controles permanecem legíveis. Penélope aparece como lembrança; Ítaca surge no horizonte no dia 9.
- A aceleração do sono no dia 9 ultrapassa a recuperação máxima permitida pelo intervalo entre despertares: perder é inevitável, mesmo reagindo perfeitamente. A perda abre diretamente uma cena de pensamentos sobre fundo escuro. Ninguém aparece abrindo a bolsa.
- `VigilThoughts.dialogue.json` contém todas as falas fornecidas de Odisseu e Penélope, até “Acorda!”. Em seguida, `ReleasedWinds.dialogue.json` continua com as imagens da tempestade, Éolo, a tentativa de guardar os ventos restantes e a pergunta do Desconhecido. Espaço/Enter revelam e avançam as falas; A alterna o avanço automático. Os ventos só são ouvidos quando Penélope avisa que estão abrindo a bolsa.
- O resultado mostra dias concluídos, aproximações impedidas e despertares, com replay e retorno ao mapa. Dias impecáveis ficam no registro. Só a sequência do dia 9 emite conclusão da história; uma derrota antecipada não conclui a fase.

Esc pausa o jogo, a animação e as falas. A composição usa 1152×648 com letterboxing para outras proporções.

## Registro

`user://vigil_record.json` guarda a última tentativa e os melhores números de dias impecáveis/aproximações impedidas. O save da campanha, os desbloqueios, a vida do navio e o inventário não são alterados. Testes e gravações usam `persist_record=false`.

## Artes

Assets gerados anteriormente com **imagegen integrado**, preservando referências, prompts e transparência:

- `odysseus_vigil.png`: quatro poses sentadas do Odisseu, mantendo o rosto corrigido, armadura, manto e bolsa.
- `penelope_vision.png`: retrato transparente da lembrança de Penélope.
- `deck_ithaca.png`: mesmo convés, com Ítaca distante sobre o mar.
- `generation_prompts.json` e `betrayal_prompt.json`: prompts completos e caminhos das referências.
- `regions.json`: recortes por metadados.
- `wind_bag_betrayal.png`: arte da versão anterior, preservada para recuperação no histórico; não é carregada nesta fase nem usada no novo desfecho.

Perímedes/Elpenor reutilizam os uniformes de soldados e rostos de `Assets/act4_friends/crew_poses_v3.png`. Sons de atenção/passos e mar são procedurais; a tempestade reutiliza o áudio do ato 4. Não há dublagem nem música extraída do musical.

## Verificação

- `scratch/test_vigil.tscn`: derrotas reais, bloqueio de E, dificuldade, ataques simultâneos, oito dias vencíveis e nono inevitável com 12 sementes, inputs, pausa, redimensionamento, escurecimento, falas, anonimato do desfecho e preservação de saves.
- `scratch/test_aeolia_harpoon.tscn`: fluxo da tempestade/arpão/subida/encontro até a abertura da fase.
- `scratch/test_vigil_audio.tscn`: silêncio no pensamento, ventos após o aviso de Penélope e liberação dos players ao sair.
- `scratch/inspect_vigil_assets.py`: verifica transparência e recortes sem editar os PNGs.
- `scratch/vigil_demo.tscn`: prévia abreviada com dias de nove segundos. A fase normal mantém os 25 segundos e responde ao jogador.
- `Ato4_Tempestade/Cutscenes/ReleasedWindsPreview.tscn`: prévia direta das falas finais de Penélope e da nova continuação ilustrada; não grava resultado. Artes e detalhes em `Assets/act4_released_winds/README.md`.

Imagens e vídeo de QA ficam em `scratch/vigil_preview/`, ignorado no Git. A versão anterior da vigília está preservada no commit `4008d97`.
