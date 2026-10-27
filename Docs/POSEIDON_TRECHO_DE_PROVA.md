# Poseidon — Mar em ruptura: primeira entrega jogável

Esta entrega implementa o trecho representativo da direção alinhada em `POSEIDON_DIRECAO_CRIATIVA.md`. O objetivo é avaliar movimento, recuo, agachamento, mudança real de caminho e perseguição antes de produzir as três sequências completas. Não é a versão final dos dez barcos nem do desafio da bolsa.

## Como testar

Abra `Ato4_Tempestade/Gameplay/PoseidonEscape.tscn` e pressione F6. A entrada após o primeiro impacto de “Morra” continua usando essa mesma cena.

- A/D ou ←/→: correr, frear e voltar.
- S/↓: abaixar e passar sob a vela. Soltar a tecla sob o tecido não aumenta o corpo dentro da colisão.
- Espaço: salto com altura variável; segure para subir mais, solte para um salto menor.
- Esc: pausa. Após falhar, Enter retoma o ponto seguro.

A apresentação identifica o trecho de prova. **Fase anterior** abre a travessia preservada de dez barcos. No abrigo ao final do trecho, **Repetir trecho** permite avaliar novamente o controle; **Continuar travessia** mantém o registro narrativo e começa a travessia anterior no quarto barco, com os três anteriores perdidos.

## O que mudou de fato

1. Ao alcançar a proa, a estrutura e Poseidon atuam na ruptura. O apoio dianteiro é removido da colisão quando o casco cede, não apenas apagado da imagem. Não há seta, área marcada ou instrução de esquiva.
2. Odisseu precisa frear e voltar. Uma vela pendente bloqueia a passagem em pé, deixando folga para o corpo abaixado. A descida não permite atravessá-la sem abaixar mesmo se o corpo já estiver dentro de sua área no instante da ativação.
3. Depois do recuo até a base, o mastro cai e assenta na água: de (380,475) até (1100,540). Seus mesmos endpoints definem a superfície inclinada de colisão e a arte. É possível subir, descer, parar e saltar da rampa.
4. O novo caminho passa por um primeiro destroço e pelo próximo casco. Depois há uma frente de água com posição e velocidade reais no mundo. Parar no trecho de perseguição permite que ela alcance Odisseu.
5. Os fragmentos seguem o mesmo perfil de água, com 18 px de madeira acima dela, espaçamentos e deriva diferentes. O apoio transporta o personagem em X e Y; ao saltar, esse transporte deixa de ser aplicado. Fragmentos usados por muito tempo afundam.
6. A chegada a um casco protegido encerra esta prova. Não emite `escaped`, não escreve o registro de fuga e não afirma que Poseidon foi derrotado.

O piloto conhece a geometria e completa a simulação em aproximadamente 23,3 s; o caminho com eventos de teclado em tempo normal levou 23,1 s. Esses números não validam duração, legibilidade ou dificuldade humanas. O alvo de 30–45 s de descoberta permanece uma hipótese para o teste do jogador, sem esperas obrigatórias acrescentadas para alcançar um número.

## Apresentação e áudio

As artes de Odisseu, Poseidon, cavalo de água, navio, mar e destroços foram reaproveitadas. O personagem e a próxima aterrissagem mantêm prioridade sobre os efeitos. A câmera abre durante a ruptura/recuo e volta a acompanhar as aterrissagens; a posição da câmera não altera a física nem cria apoios.

A presença de Poseidon acompanha a preparação e o impacto dos acontecimentos. O pano baixo, as caixas e o mastro possuem representação visível no mesmo lugar de suas colisões. Vergas pendem de cabos ligados ao mastro; apoios do navio final têm postes e travessas até o convés. A carga elevada no trecho é um caixote sólido apoiado no casco.

## Revisão de água e ataques

A primeira autoria deixava destroços em y350–490 sobre água frontal em y616; a ponta do mastro terminava em y315. Colisão e desenho concordavam entre si, mas ambos estavam acima do mar. Agora `water_height_at(x,t)` é a referência física comum em torno de y558, com onda suave. Destroços acompanham essa altura; parte inferior da madeira fica submersa, com recorte e espuma no contato. Ambos os renderers usam esse perfil.

`PoseidonWaterAttack.gd` dirige formação, avanço/queda e dissipação. As malhas usam curvas e textura, sem cartões retangulares sobre as hitboxes. A coluna desce fisicamente em 120 ms e quebra no convés, mesmo quando Odisseu saltou antes do disparo. Os avisos de HUD, setas, faixas, contadores de colapso e bipes de antecipação foram removidos; a atuação do mar permanece visível.

A frente original reutilizava uma onda vista de cima. A tentativa intermediária de curvá-la ainda produziu uma fita, descartada na revisão em movimento. A versão atual usa [wave_side_v2.png](../Assets/act4_poseidon_escape/wave_side_v2.png), gerada pelo `image_gen.imagegen` integrado, com transparência real. O [prompt completo](../Assets/act4_poseidon_escape/water_revision_prompt.json) está salvo junto da arte. A imagem inteira é animada por uma malha 8×12 de 192 triângulos, preservando massa e perspectiva lateral. `PoseidonWaveProfile.json` guarda o perfil da borda opaca da arte; física e desenho compartilham escala e âncora. A colisão amostra o corpo de Odisseu contra essa borda com margem conservadora de 10 px, permitindo entrar na abertura da crista sem morrer antes do contato. Não é uma animação pintada quadro a quadro.

Também foram corrigidos apoios/carga que permaneciam ativos após o casco afundar e ataques ativos que desapareciam ao restaurar o checkpoint do trecho.

`PoseidonEncounterAudio.gd` mantém tempestade com loop real e vozes independentes para madeira, água, pressão divina, vento, passos e aterrissagem. Os 20 clipes de material são gerados uma vez, com ruído filtrado, ressonâncias e envelopes, e permanecem em cache. Até sete players podem coexistir; geração de amostras não ocorre durante os frames de jogo. A primeira preparação medida isoladamente levou cerca de 820 ms. O stream original de tempestade não é modificado.

O áudio desta prova é desenho sonoro procedural. Ainda não há trilha musical composta/adaptativa; esses efeitos não são apresentados como substitutos da trilha final. A animação continua usando os atlas existentes. Uma corrida com mais quadros, transições corporais específicas, outras destruições e os três blocos completos dependem da avaliação deste trecho.

## Organização e preservação

- `PoseidonRuptureModel.gd` estende o modelo anterior, mantendo corrida, gravidade, salto, buffer e tolerância de borda. Acrescenta estados do encontro, superfícies inclinadas/móveis, frente de água e snapshots locais.
- `PoseidonRuptureStage.gd` estende o renderer anterior. Consome os endpoints do modelo e dirige Poseidon, casco, vela, mastro, água e câmera.
- `PoseidonEscape.gd` conserva entrada, pausa, áudio anterior, mapa e persistência. `proof_enabled` seleciona a nova prova ou a fase preservada; a prova tem um resultado próprio.
- O checkpoint restaura relógio local, fase dos apoios, preparação dos eventos, objetivo, geometria e frente de água. Estatísticas de tentativas continuam cumulativas. Falhar não move Odisseu para um apoio automaticamente.
- A passagem entre prova e fase anterior transfere o registro narrativo e a responsabilidade por restaurar o modo de combate, sem alterar vida/inventário.
- Repetir mantém o modo selecionado, o barco de entrada, as configurações e o registro narrativo. Conclusão e falha zeram a velocidade para interromper corrida e passos sob os painéis.

Checkpoint anterior à implementação: **765b54b**, branch `codex/poseidon-platformer`. A direção alinhada foi registrada separadamente em **2b61f3b**. Esta revisão está na branch `codex/poseidon-mar-em-ruptura`.

## Verificação

- `scratch/test_poseidon_rupture.tscn`: 58 verificações de colisão e progressão, incluindo rampa nas duas direções, junções, apoio móvel X/Y, água compartilhada, salto, remoção de suporte/carga, bordas, buffer, alturas, diferenças de FPS, vela, recuo, tentativa apenas para a direita, falha congelada, restauração de ataques no checkpoint, contato com a frente curva, perfil contra o alpha real do PNG e conclusão única.
- `scratch/test_poseidon_rupture_integration.tscn -- --capture`: 21 verificações com renderização, incluindo eventos reais de teclado, percurso completo, nove capturas, pausa, janela vertical, ausência de falso registro de fuga, preservação da campanha, continuação/repetição na fase anterior e restauração única do modo de combate.
- `scratch/test_poseidon_escape.tscn`: 39 verificações da física da travessia anterior, incluindo água e alcance contínuo do impacto; o modo legado é selecionado explicitamente pela fixture.
- `scratch/test_poseidon.tscn`: 115 verificações da cutscene anterior passaram na entrega inicial; não foi alterada nesta revisão.
- `scratch/poseidon_rupture_demo.tscn`: demonstração que parte do último bloco de “Morra”, usa o handoff real e dirige por eventos de teclado. Não usa teleporte ou invulnerabilidade e desativa persistência de resultado.

Na medição curta antes da troca final da arte da onda, em execução normal com áudio e renderização Compatibility, foram registrados 1.388 frames da prova, com delta informado pelo Godot em 16,67 ms, no equipamento disponível com Intel Iris Xe. É uma observação local, não uma garantia de desempenho da fase completa. A gravação MovieMaker não é usada como benchmark.

Capturas, logs e vídeos ficam em `scratch/poseidon_rupture_preview/`, fora do Git. O aviso preexistente de UID de `PlayerStatsMenu.tscn` continua resolvido pelo caminho da imagem.

A prévia `water_revision.mp4` contém a passagem de “Morra”, a execução por teclado e o resultado do trecho. O percurso gravado levou 23,3 s, com 16 saltos e nenhum impacto. A gravação gerou 960 frames a 30 FPS; a exportação remove 0,15 s da limpeza da cena ao final, sem cortar a travessia. Para converter novamente: `python scratch/encode_poseidon_escape_preview.py scratch/poseidon_rupture_preview water_revision 0.15`.

## O que avaliar jogando

- Você percebeu a proa cedendo com tempo para mudar de plano?
- O freio e o salto responderam ao que tentou fazer?
- A vela comunicou que era preciso abaixar?
- Ficou claro quando o mastro passou a ser um apoio?
- A câmera mostrou onde pousar e a frente de água pareceu uma pressão compreensível?
- Ao falhar, você entendeu o erro e quis repetir?

Os testes automáticos respondem pela consistência técnica. A avaliação acima deve orientar a próxima iteração antes da expansão aos dez barcos.
