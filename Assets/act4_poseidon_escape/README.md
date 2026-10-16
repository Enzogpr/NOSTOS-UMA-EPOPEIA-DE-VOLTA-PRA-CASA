# Fuga de Poseidon

Abra `Ato4_Tempestade/Gameplay/PoseidonEscape.tscn` com F6. A campanha continua diretamente depois do primeiro impacto de `Ruthlessness.tscn`.

Odisseu atravessa o convés, segura E para soltar a bolsa (progresso preservado entre interrupções), leva-a ao leme e libera os ventos numa abertura do ataque final. WASD/setas movem; Espaço esquiva; E interage ou segura uma corda junto dos pontos marcados; Esc usa a pausa existente. A derrota narrativa é perder os outros onze navios. O jogador não tem barra de vida: ataques tiram equilíbrio, derrubam e empurram; não matam e não causam fuga automática. Perder a janela final obriga a retornar ao leme e tentar outra abertura, mantendo a bolsa.

`PoseidonEscapeModel.gd` concentra movimento, colisão do mastro, ataques anunciados, interação, frota e fases. `PoseidonEscapeStage.gd` desenha o mundo e os efeitos; `PoseidonEscape.gd` integra interface, áudio e conclusão. Tempos e dimensões estão em constantes no modelo. Não utiliza o Player com dano da campanha nem modifica seus atributos.

As artes `deck.png` e `odysseus_escape_v2.png` foram geradas com o **ImageGen integrado**, usando convés, Odisseu e bolsa existentes como referências. `generation_prompts.json` e `gait_refinement_prompt.json` contêm os prompts completos e referências. O atlas inicial `odysseus_escape.png` fica como fonte da correção dos passos; a versão 2 alterna passadas largas e poses de passagem. Os PNGs mantêm o alpha original; atlas e recortes são aplicados pelo Godot. Mar, ondas, cavalo de água, navios, Euríloco, bolsa e sons reutilizam recursos do projeto. Nenhum áudio do vídeo é usado.

Checkpoint anterior: `5d65f5f` (cutscene de Poseidon).

Os avisos antecedem os golpes: jatos 1,3 s; varredura 3,5 s; cavalo 3,25 s. Na abertura final (8 a 10,8 s da preparação), é necessário começar a segurar E e manter por 0,85 s. Ficar segurando desde antes da abertura não libera o vento automaticamente. O mastro bloqueia a água na área indicada; as cordas protegem contra a pancada do cavalo. Os ataques comuns destroem até nove navios; o golpe final destrói os restantes antes da fuga. A frota não reaparece se a janela for perdida.

## Validação

- `scratch/test_poseidon_escape.tscn`: **57 verificações, nenhuma falha**, com renderização OpenGL. Cobre avisos inofensivos, jatos com posição fixa, colisão do mastro, esquiva, proteção, arrasto, impactos repetidos sem morte, progresso da bolsa, tentativa final perdida, exigência de nova ação na abertura, conclusão única, teclado, pausa, janela vertical, transferência da cutscene, áudio e preservação de vida/inventário/saves. Dez capturas ficam em `scratch/poseidon_escape_preview/`.
- `scratch/test_poseidon.tscn`: **115 verificações, nenhuma falha**, na regressão sem renderização da cutscene anterior. O seu modo isolado conserva o cartão final.
- Três percursos pelo modelo, sem teletransporte ou invulnerabilidade, completaram o trajeto em 37,6 a 43,1 segundos. O piloto é uma ferramenta de QA e lê os avisos do modelo; esses tempos não medem a dificuldade para jogadores humanos.
- `scratch/poseidon_escape_demo.tscn`: demonstração com teclado simulado, desde “Morra” até o resultado. A gravação final tem 1.284 quadros a 30 fps (**42,8 segundos**), incluindo transições e cartão. A rota gravada concluiu em 32,8 segundos, com os onze navios perdidos e somente o navio principal salvo. O modo de gravação desativa a persistência do resultado.
- `scratch/encode_poseidon_escape_preview.py`: exporta `scratch/poseidon_escape_preview/escape.mp4` e folhas de contato, examinadas para verificar o movimento, a destruição da frota e a fuga. Capturas, AVI e MP4 ficam fora do Git.

O Godot ainda informa o aviso preexistente de UID do retrato em `Scenes/PlayerStatsMenu.tscn`, resolvido pelo caminho do arquivo. Não houve erro novo na validação final ou na gravação.
