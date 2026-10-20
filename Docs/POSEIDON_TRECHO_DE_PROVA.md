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

1. Ao alcançar a proa, a estrutura e Poseidon antecipam a ruptura. O apoio dianteiro é removido da colisão depois do aviso, não apenas apagado da imagem.
2. Odisseu precisa frear e voltar. Uma vela pendente bloqueia a passagem em pé, deixando folga para o corpo abaixado. A descida não permite atravessá-la sem abaixar mesmo se o corpo já estiver dentro de sua área no instante da ativação.
3. Depois do recuo até a base, o mastro cai e assenta. Seus mesmos endpoints definem a superfície inclinada de colisão e a arte. É possível subir, descer, parar e saltar da rampa.
4. O novo caminho passa por um primeiro destroço e pelo próximo casco. Depois há uma frente de água com posição e velocidade reais no mundo. Parar no trecho de perseguição permite que ela alcance Odisseu.
5. Os fragmentos seguintes têm alturas, espaçamentos e movimentos diferentes. O apoio transporta o personagem em X e Y; ao saltar, esse transporte deixa de ser aplicado. Fragmentos usados por muito tempo afundam.
6. A chegada a um casco protegido encerra esta prova. Não emite `escaped`, não escreve o registro de fuga e não afirma que Poseidon foi derrotado.

O percurso informado conhece a geometria e completa a simulação em aproximadamente 23 s; o caminho com eventos de teclado em tempo normal levou 22,6 s. Esses números são de um piloto e não validam duração, legibilidade ou dificuldade humanas. O alvo de 30–45 s de descoberta permanece uma hipótese para o teste do jogador, sem esperas obrigatórias acrescentadas para alcançar um número.

## Apresentação e áudio

As artes de Odisseu, Poseidon, cavalo de água, navio, mar e destroços foram reaproveitadas. Não foram geradas novas imagens nesta entrega. O personagem e a próxima aterrissagem mantêm prioridade sobre os efeitos. A câmera abre durante a ruptura/recuo e volta a acompanhar as aterrissagens; a posição da câmera não altera a física nem cria apoios.

A presença de Poseidon acompanha a preparação e o impacto dos acontecimentos. A frente perseguidora usa a arte aquática existente, alinhada à sua coordenada física. O pano baixo, as caixas e o mastro possuem representação visível no mesmo lugar de suas colisões.

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

- `scratch/test_poseidon_rupture.tscn`: 39 verificações de colisão e progressão, incluindo rampa nas duas direções, junções, apoio móvel X/Y, salto, remoção de suporte, bordas, buffer, alturas, diferenças de FPS, vela, recuo, tentativa apenas para a direita, falha congelada, restauração de checkpoint e conclusão única.
- `scratch/test_poseidon_rupture_integration.tscn -- --capture`: 21 verificações com renderização, incluindo eventos reais de teclado, percurso completo, nove capturas, pausa, janela vertical, ausência de falso registro de fuga, preservação da campanha, continuação/repetição na fase anterior e restauração única do modo de combate.
- `scratch/test_poseidon_escape.tscn`: 32 verificações de regressão da física da travessia anterior; o modo legado é selecionado explicitamente pela fixture.
- `scratch/test_poseidon.tscn`: 115 verificações da cutscene anterior.
- `scratch/poseidon_rupture_demo.tscn`: demonstração que parte do último bloco de “Morra”, usa o handoff real e dirige por eventos de teclado. Não usa teleporte ou invulnerabilidade e desativa persistência de resultado.

Em execução normal com áudio e renderização Compatibility, foram registrados 1.358 frames da prova: mediana/p95 do delta de frame de 16,67 ms e máximo de 20,29 ms, no equipamento disponível com Intel Iris Xe. Essa é uma medição curta da versão atual, não uma garantia de desempenho da fase completa. A gravação MovieMaker não é usada como benchmark.

Capturas, logs e vídeos ficam em `scratch/poseidon_rupture_preview/`, fora do Git. O aviso preexistente de UID de `PlayerStatsMenu.tscn` continua resolvido pelo caminho da imagem.

A prévia `rupture.mp4` contém a passagem de “Morra”, a execução por teclado e o resultado do trecho. O percurso gravado levou 22,8 s, com 14 saltos e nenhum impacto. A gravação gerou 947 frames a 30 FPS; a exportação remove 0,15 s da limpeza da cena ao final, sem cortar a travessia. Para converter novamente: `python scratch/encode_poseidon_escape_preview.py scratch/poseidon_rupture_preview rupture 0.15`.

## O que avaliar jogando

- Você percebeu a proa cedendo com tempo para mudar de plano?
- O freio e o salto responderam ao que tentou fazer?
- A vela comunicou que era preciso abaixar?
- Ficou claro quando o mastro passou a ser um apoio?
- A câmera mostrou onde pousar e a frente de água pareceu uma pressão compreensível?
- Ao falhar, você entendeu o erro e quis repetir?

Os testes automáticos respondem pela consistência técnica. A avaliação acima deve orientar a próxima iteração antes da expansão aos dez barcos.
