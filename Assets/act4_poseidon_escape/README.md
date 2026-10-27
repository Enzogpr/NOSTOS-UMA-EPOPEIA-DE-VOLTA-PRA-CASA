# Poseidon — travessia de plataforma

**Entrada atual:** `PoseidonEscape.tscn` inicia o trecho representativo **Mar em ruptura**. A versão de dez barcos descrita abaixo permanece disponível no botão **Fase anterior**; após o trecho, **Continuar travessia** retoma seu percurso no quarto barco. Detalhes e validação desta entrega em `Docs/POSEIDON_TRECHO_DE_PROVA.md`. A conclusão do trecho não registra a fuga completa nem altera vida/inventário da campanha.

Abra `Ato4_Tempestade/Gameplay/PoseidonEscape.tscn` e pressione F6. A entrada da campanha continua após “Morra” e o primeiro impacto de `Ruthlessness.tscn`.

Esta versão substitui a arena e os três atos cronometrados por uma fase lateral: **dez barcos intermediários, trinta destroços e, depois, o navio de Odisseu**. Há gravidade e colisão contínuas; saltar não depende de marca, autorização ou arco automático. A passagem fica disponível desde o início. A duração depende de atravessar o cenário e cumprir o objetivo.

## Controle e percurso

- A/D ou ←/→: correr, frear, voltar e corrigir o salto no ar. S/↓: abaixar e andar abaixado. Espaço: saltar; soltar cedo produz um salto menor. Há tolerância de 110 ms após sair de uma borda e buffer de 130 ms para um salto apertado pouco antes da aterrissagem.
- Caixas são obstáculos sólidos, vigas deixam espaço para passar abaixado, destroços oscilam com sua superfície de colisão e afundam após o uso prolongado. As superfícies de madeira mais claras indicam onde os pés podem apoiar.
- Ondas baixas exigem salto, rajadas altas passam por cima de Odisseu abaixado e colunas de água descem sobre uma posição fixa do convés. Não há marcas de perigo, setas nem instruções de esquiva. Os golpes empurram e consomem fôlego; não existe dash ou invulnerabilidade ao abaixar.
- Poseidon esmaga o barco abandonado enquanto Odisseu ainda atravessa os destroços. Permanecer num barco também acaba provocando sua destruição. A câmera abre brevemente durante o naufrágio, mantendo o controle ativo.
- Checkpoints nos barcos 3, 5, 7 e 9, na chegada ao navio final e ao recuperar a bolsa. Queda ou falta de fôlego interrompe a tentativa; é preciso escolher retomar ou pressionar Enter. A vida da campanha não é reduzida e não há recuperação automática no meio do salto.

## Navio final

O mesmo controle de plataforma continua. Três amarras ficam distribuídas entre o convés e uma plataforma elevada; segure E junto delas para soltá-las. O segundo nó liberado coincide com a quebra do mastro e os ataques ficam mais frequentes. Suba aos apoios para pegar a bolsa e volte à popa para liberar os ventos. Não existe contagem obrigatória de ataques ou um cronômetro de sobrevivência. Os outros onze barcos precisam terminar de afundar antes da fuga.

## Código e ajustes

`PoseidonPlatformLevel.json` descreve cada barco, intervalos, alturas, obstáculos, destroços, física e parâmetros do desafio final. `PoseidonEscapeModel.gd` trata colisão, gravidade, ataques, interação, destruição e checkpoints, subdividindo a física em passos de até 1/120 s. `PoseidonEscapeStage.gd` usa os mesmos dados de superfície para posicionar artes, pés e avisos. `PoseidonEscape.gd` mantém HUD, teclado, áudio, pausa, resultado, registro e integração com a campanha.

O antigo renderer separado da frota, efeitos da arena e configuração dos atos foram removidos. A versão anterior está preservada no commit **8e1a81f** e na branch `codex/poseidon-fleet-survival`.

## Artes e prompts

Geradas com **ImageGen integrado**, usando referências locais de identidade e estilo, com alpha original preservado:

- `odysseus_crouch.png`: quatro poses para agachar e avançar abaixado; roupa vermelha, armadura, rosto e sandálias existentes.
- `platform_wrecks.png`: quatro tipos de madeira/trecho de casco quebrado utilizados nas plataformas.
- `platform_prompts.json`: os prompts completos, caminhos dos resultados e papéis de cada referência.

Reutilizados: `traversal_ship.png`, `odysseus_escape_v2.png`, `odysseus_jump_v2.png`, mar, cavalo de água, bolsa, barco da fuga e sons. Outros recursos e prompts da versão anterior permanecem como fonte de referência. As poses e os passos são atlas finitos; não são animação redesenhada quadro a quadro. Nenhum áudio de vídeo de referência foi usado.

## Validação

`scratch/test_poseidon_escape.tscn`: **32 verificações de física/progressão**, incluindo altura variável, tolerância de borda, buffer, diferença entre andar e abaixar, colisão com vigas, ondas, alvo fixo, destroços que afundam, queda sem resgate, checkpoints, bloqueio da bolsa e conclusão única. A execução com `-- --capture` faz **40 verificações no total**, acrescentando renderização, HUD, Enter, pausa, janela vertical e preservação de vida, inventário, save e registro. Capturas em `scratch/poseidon_platform_preview/`.

O percurso completo do piloto levou **75,9 s**, chegando ao navio final em **58,3 s**, com dez barcos atravessados, 52 saltos, três rajadas evitadas abaixado, uma colisão e nenhuma retomada. O piloto conhece a geometria e os avisos; esse tempo não é uma estimativa de dificuldade ou duração para jogadores humanos.

`scratch/test_poseidon.tscn`: **115 verificações da cutscene anterior**, sem falhas. `scratch/poseidon_escape_demo.tscn` grava o caminho desde “Morra” usando eventos de teclado; não teletransporta, não concede invulnerabilidade e desativa a persistência de resultado. `scratch/encode_poseidon_escape_preview.py scratch/poseidon_platform_preview platform` exporta MP4 e folhas de contato. Gravações e capturas ficam fora do Git.

A gravação com eventos de teclado concluiu a fase em **74,2 s**, com 53 saltos, duas colisões e nenhuma retomada. O vídeo completo tem **2.525 quadros a 30 fps (1min24,2s)**, incluindo a entrada da cutscene e o resultado, em `scratch/poseidon_platform_preview/platform.mp4`.

O aviso preexistente de UID do retrato em `Scenes/PlayerStatsMenu.tscn` continua sendo resolvido pelo caminho da imagem.
