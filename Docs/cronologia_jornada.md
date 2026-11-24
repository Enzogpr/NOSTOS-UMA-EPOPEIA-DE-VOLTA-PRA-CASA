# Passagem automática de tempo

A campanha conta dias narrativos desde a saída de Troia, com anos de 365 dias.
O retorno termina em 3.650 dias (dez anos). Os dez anos anteriores de guerra
pertencem ao contexto: não são cobrados outra vez ao concluir Troia. A idade
inicial do protótipo continua sendo 20 anos.

`Code/JourneyChronology.gd` centraliza os marcos para ajuste independente.
Os números abaixo são uma cronologia da adaptação do jogo, não um calendário
exato de Homero nem uma cronologia oficial de EPIC. Os períodos não definidos
foram distribuídos nas navegações para fechar os dez anos. O tempo combinado
de cada etapa inclui suas viagens; não significa permanecer meses lutando ou
ouvindo sereias. O ano de Circe representa a estadia e a recuperação após o
resgate, contabilizadas na conclusão do episódio.

| Marco concluído | Dia acumulado desde Troia | Tempo desde o marco anterior |
| --- | ---: | ---: |
| Saída de Troia | 0 | — |
| Saída dos lotófagos | 12 | 12 dias: abrigo, nove dias à deriva e visita |
| Saída da região do ciclope | 47 | 35 dias, incluindo navegação e acampamentos |
| Chegada a Éolo | 170 | 123 dias de viagem e tempestade |
| Partida de Éolo | 200 | 30 dias de hospitalidade |
| Abertura da bolsa | 209 | 9 dias da vigília, seguindo a adaptação de EPIC |
| Fuga do primeiro Poseidon | 220 | 11 dias de deslocamento e confronto |
| Busca da holimoli concluída | 300 | 80 dias, incluindo o trajeto até Circe |
| Episódio de Circe concluído | 665 | 365 dias de estadia e recuperação |
| Travessia do Submundo | 666 | 1 dia |
| Profecia concluída | 667 | 1 dia |
| Sereias | 1.000 | 333 dias, principalmente navegação não mostrada |
| Cila | 1.001 | 1 dia |
| Motim e ilha de Hélio | 1.068 | 67 dias de viagem, escassez e conflito |
| Chegada a Calipso | 1.077 | 9 dias à deriva |
| Libertação e partida de Calipso | 3.632 | Exatamente 7 anos (2.555 dias) |
| Caríbdis | 3.649 | 17 dias de viagem após a ilha |
| Poseidon final / chegada a Ítaca | 3.650 | 1 dia |
| Pretendentes | 3.650 | Mesmo marco final, sem ano adicional |

## Idade, mundo e atributos

- `story_days`: tempo vivido na história; avança por marcos, sem relógio real.
- `sacrificed_years`: anos consumidos pela habilidade, sem avançar o mundo.
- `player_age`: idade inicial + anos completos da história + anos sacrificados.
- Cada aniversário natural aplica a mesma curva de atributos do sacrifício.
  A vida atual nunca aumenta por envelhecer; só é limitada à nova vida máxima.
- O mapa mostra tempo de retorno e idade. Os atributos mostram também os anos
  sacrificados separadamente. Sacrifícios não envelhecem Penélope ou Telêmaco.

Em Calipso, os cortes animados da bancada registram cada ano completo, dos
zero aos três e depois dos três aos sete. A conclusão garante o total de sete
caso o diálogo seja avançado, mas não soma mais sete na partida da jangada.
Uma tentativa frustrada de navegação não avança o calendário.

## Save, repetição e compatibilidade

Os marcos usam dias acumulados: concluir novamente uma etapa anterior nunca
avança nem regride o relógio. Morte, checkpoint, pausa, mapa e espera não
adicionam tempo. Previews independentes F6 usam a idade correspondente à entrada da fase,
com a mesma curva de atributos, apenas em memória. Em Caríbdis, a base sem
sacrifícios é 29 anos (nove anos completos de retorno, incluindo sete com
Calipso). Os cortes de três e sete anos de Calipso também atualizam o teste.
As transições entre cenas preservam esse estado temporário; a campanha real
não é gravada nem tem etapas concluídas por essa simulação.

O save guarda versão do calendário, dias narrativos e anos sacrificados.
Saves antigos preservam os atributos e sacrifícios existentes e recebem apenas
o envelhecimento natural correspondente ao progresso validado. A migração é
feita em memória; não reescreve o arquivo ao carregar. Saves da versão nova
cujo calendário ficou abaixo do progresso concluído também recebem apenas
o tempo que faltava, preservando os sacrifícios registrados. O próximo salvamento já
guarda a nova versão. Recarregar o mesmo save não multiplica o avanço.

Uma nova campanha zera calendário e sacrifícios. Os testes usam saves próprios
temporários e conferem que o save real não foi alterado.

O painel de atributos usa uma composição de proporções fixas escalada à janela.
O diagrama é quadrado e os textos acompanham os centros dos círculos da arte.
`scratch/test_preview_age_and_stats_layout.gd` verifica as idades de entrada,
a recuperação de calendário inconsistente, os controles do menu, o alinhamento
em três resoluções e a preservação do save real.
