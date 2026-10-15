# Poseidon — Crueldade é piedade

Abra `Ato4_Tempestade/Cutscenes/Ruthlessness.tscn` no Godot e use F6. Na campanha, a cena começa automaticamente depois de “Você sabe quem eu sou?”, no fim dos ventos libertos, sem cartão intermediário. A resposta “Poseidon” abre a nova cena. O registro da vigília é transferido, sem modificar inventário, vida ou desbloqueios.

O escopo confirmado termina em **“Morra” e no primeiro impacto do ataque**, antes do restante do massacre e da fuga. O roteiro contém todas as falas portuguesas fornecidas, com um intervalo silencioso para a coreografia que no original tinha refrão repetido. São 39 blocos, cerca de 169 segundos de montagem, mais a entrada/saída. Não há música ou voz copiada do vídeo.

## Storyboard antes da implementação

`Docs/POSEIDON_STORYBOARD.md` registra a leitura visual dos 04:35 completos, timestamps, ações identificadas, limites da inspeção e plano de implementação. A inspeção usa 550 quadros a 2/s; os trechos rápidos também foram extraídos a 6/s e examinados em folhas mais densas. Não é uma alegação de reprodução audiovisual contínua ou análise de cada um dos 12 quadros/s originais. A transcrição local aproximada errou várias palavras cantadas; suas palavras não foram copiadas para o roteiro.

## Direção e recursos

- `Ruthlessness.dialogue.json`: português integral, duração editável, timestamp de referência e plano de cada bloco. As durações priorizam a coreografia e a leitura, com pequenos alongamentos onde o português exige.
- `Ruthlessness.gd`: reaproveita o apresentador de legendas/controles existente. Em automático segue o relógio de cada plano; em manual, permite revelar o texto e exige concluir os contatos antes de avançar. A alterna automático; Espaço/Enter/clique revelam/avançam; Esc pausa.
- `PoseidonStage.gd`: direção específica da cena, com trilhas separadas para câmera, personagens, poses de contato, revelação, frota, galope/salto/mergulho, materialização, queda, resistência, arremesso, apoio, ajoelhar, apelo e impacto.
- `acting.gdshader`: cabelo e tecido, variação discreta de cabeça/tronco, tensão, resistência localizada com pontos de contato preservados e revelação do corpo através da água.

O movimento da câmera usa aceleração/desaceleração. O galope inclui detalhe dos cascos, plano do corpo e aproximação do olho. O salto usa arco, rotação da pose no mergulho e impulso de água. Poseidon permanece ancorado na projeção de Odisseu, que termina no apoio de Euríloco. O apelo tem palma aberta, mão no peito e olhos fechados em desenhos próprios. O primeiro impacto tem antecipação, proteção do capitão, frente de água que avança pela frota e corte escuro.

## Artes e prompts

Geradas com **image_gen integrado**, com as artes canônicas anexadas como referências e alpha preservado. Os PNGs gerados não foram recortados ou reescritos por Python; o jogo usa recortes por metadados:

- `poseidon_poses.png`: seis poses de corpo. Poseidon é novo no jogo; mantém a intenção de cabelo/barba escuros e tecido grego da referência, traduzida para o nosso estilo colorido. Não foi acrescentada coroa ou arma ao confronto.
- `poseidon_faces.png`: seis expressões em close, incluindo olhos fechados, abertura gradual, olhar severo e sorriso tenso.
- `odysseus_kneeling.png`: quatro poses de queda/prostração/apelo, preservando rosto, cabelo, barba, couraça de coruja, túnica escura, manto vermelho e grevas.
- `contact_poses_v2.png`: pulso erguido, mão na cabeça/resistência, soltura e apoio de Euríloco. A segunda versão corrige a bainha de Odisseu para o figurino escuro canônico, mantendo a distinção de Euríloco. `contact_poses.png` preserva o desenho anterior à correção como referência de geração.
- `water_horse.png`: seis fases de cavalo de água, incluindo galope, salto, mergulho e ameaça final. O jogo anima espuma e deslocamento em camadas.
- `regions.json`: recortes e bibliotecas reaproveitadas pelo Performer.
- `generation_prompts.json` e `refinement_prompts.json`: prompts de criação, expressão e correção do figurino.

O mar, o convés, o navio, a frente de onda e os sons de tempestade vêm de assets já presentes. Os sons curtos de contato/cascos são procedurais. A reprodução anterior de “Você sabe quem eu sou?” continua usando sua forma indistinta na névoa; a identificação só ocorre nesta cena nova.

## O que é fiel, adaptado e limitado

Reproduzidos na ordem da referência: diferença de escala, revelação equina/humana, abertura do olhar, domínio do pulso e pés suspensos, circulação pela frota, galope/salto/mergulho, queda e recuperação, gesto de moldar/desfazer água, pressão na cabeça e resistência, projeção e apoio, prostração/apelo e transformação/veredito/primeiro impacto.

Adaptados: preto e branco para o colorido do jogo; abertura condensada para continuar a cutscene existente; refrões repetidos substituídos por ação silenciosa; alguns enquadramentos altos traduzidos para a composição 2D; contato violento traduzido para poses conjuntas, deformação localizada, trajetória e recuperação sem violência gráfica. Os esboços rápidos não permitem certificar a lateralidade e o número de todos os golpes; não foram inventados golpes adicionais.

Limites reais: animação por ilustrações e camadas, sem captura de movimento/ator 3D e sem dublagem ou sincronização labial fonética. Poses de galope e contato têm quadros finitos, com blending/deformação e efeitos entre eles; não equivalem a um redesenho de cada quadro do vídeo. A continuidade facial em ângulos novos e a densidade dos gestos podem receber refinamento artístico adicional, sem mudar o roteiro ou a arquitetura.

## Validação e prévia

- `scratch/test_poseidon.tscn`: roteiro, legibilidade, renderização, olhos, contato visível, galope/mergulho, projeção ancorada, apoio, ajoelhar, apelo, impacto único, avanço manual/automático, pausa, letterbox, conclusão única, integração real desde o Desconhecido e preservação dos saves.
- `scratch/test_vigil.tscn` e `scratch/test_vigil_audio.tscn`: regressão da vigília e áudio com liberação correta da música ao transferir cena.
- `scratch/poseidon_demo.tscn`: grava desde a última pergunta da cena anterior até o primeiro impacto e o cartão final. Não grava resultados de campanha.
- `scratch/encode_poseidon_preview.py`: MP4 e folhas de contato para revisão em `scratch/poseidon_preview/`, ignorado no Git.
- `scratch/analyze_ruthlessness_reference.py`: extração da referência local. O vídeo, quadros, transcrição e modelo local de reconhecimento ficam fora do Git.

Resultado da execução: **304 verificações, nenhuma falha** — 154 da cutscene com renderização OpenGL, 144 da vigília e 6 de áudio. A gravação completa no Godot produziu 5.287 quadros a 30 fps, aproximadamente **02:56**, incluindo a pergunta anterior, a transferência e a saída. O MP4 final é `scratch/poseidon_preview/poseidon.mp4`.

Foram examinadas as folhas de contato da gravação e **12 pares de comparação** em `comparison_1.jpg` e `comparison_2.jpg`, produzidos por `scratch/compare_poseidon_reference.py`. Os pares comparam intenções e ações equivalentes; os tempos são aproximados e a montagem portuguesa tem outra duração. Não são uma alegação de correspondência quadro a quadro. A revisão confirmou os contatos, o figurino corrigido, a suspensão, a projeção com Poseidon ancorado, o apoio, a prostração e a primeira onda. Permanecem os limites de poses finitas e de enquadramentos altos traduzidos para planos 2D; a materialização usa revelação progressiva da ilustração pela água.

O Godot ainda informa avisos já existentes de UID do retrato em `Scenes/PlayerStatsMenu.tscn` e do fundo em `Scenes/WorldMap.tscn`, resolvidos pelos caminhos dos arquivos. Não houve erro novo nas execuções de validação ou na gravação final.

Checkpoint anterior a esta implementação: `f0eb280`.
