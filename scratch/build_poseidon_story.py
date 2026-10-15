import json
from pathlib import Path
# Timing ranges are approximate reference anchors, not claims of phoneme alignment.
rows=[
('Odisseu','Poseidon',13.5,24.4,6.2,'recognition'),
('Poseidon','Em todos os meus anos de vida\nNão é sempre que fico irritado',24.4,31.22,6.82,'calm_eye'),
('Poseidon','Eu tento relaxar com as ondas',31.22,33.5,2.8,'calm'),
('Poseidon','Mas caramba, você passou do limite',33.5,38.78,5.28,'stern'),
('Poseidon','Eu tenho sido tão gentil\nE ainda assim, você machucou o meu filho',38.78,46.4,7.62,'wrist'),
('Poseidon','Isso mesmo, o ciclope que você cegou é meu',46.4,51.46,5.06,'suspended'),
('Odisseu','Não',51.46,52.8,1.8,'denial'),
('Poseidon','Fiquei sem escolha\nE sem dúvida',52.8,56.68,3.88,'release'),
('Poseidon','Parece que a alcateia está nadando com o tubarão agora',56.68,60.24,3.56,'coil'),
('Poseidon','Eu tenho que fazer você sangrar\nEu preciso ver você se afogar',60.24,63.82,3.58,'encircle'),
('Poseidon','Mas antes de você ir, preciso fazer você aprender como',63.82,67.98,4.16,'railing'),
('Poseidon','Crueldade é piedade para com nós mesmos',67.98,79.46,11.48,'gallop'),
('Poseidon','Você é o pior tipo de bom\nPorque você nem é ótimo',79.46,87.02,7.56,'leap'),
('Poseidon','Um grego que fede a falsa moralidade\nIsso é o que eu odeio',87.02,94.92,7.9,'fall'),
('Poseidon','Porque você luta para salvar vidas\nMas você não mata e não termina o serviço',94.92,99.86,4.94,'ground'),
('Poseidon','Digo, você com certeza poderia ter evitado tudo isso',99.86,103.6,3.74,'reform'),
('Poseidon','Se simplesmente tivesse matado meu filho',103.6,106.98,3.38,'water_cup'),
('Poseidon','Mas não',106.98,108.3,1.6,'crush'),
('Poseidon','Você é bonzinho demais',108.3,111.3,3.0,'wounded'),
('Poseidon','A piedade tem um preço',111.3,113.68,2.38,'loom'),
('Poseidon','É a última gota, agora estamos prestes a quebrar o gelo',113.68,117.14,3.46,'head_grip'),
('Poseidon','Você revela seu nome',117.14,118.8,1.9,'resist'),
('Poseidon','Depois deixa ele viver',118.8,120.94,2.14,'twist'),
('Poseidon','Ao contrário de você, não tenho mais piedade para dar',120.94,124.32,3.38,'throw'),
('','',124.32,136.26,11.94,'support'),
('Poseidon','E agora finalmente chegou a hora\nDe dizer adeus',136.26,143.94,7.68,'kneel'),
('Poseidon','Hoje você morre',143.94,145.7,1.8,'verdict'),
('Poseidon','A menos, é claro, que você peça desculpas',145.7,148.1,2.6,'offer'),
('Poseidon','Pela dor do meu filho\nE todos os seus choros',148.1,153.16,5.06,'above'),
('Odisseu','Poseidon, não queríamos fazer mal',153.16,156.4,3.24,'plea_hand'),
('Odisseu','Nós só o machucamos para desarmá-lo',156.4,159.62,3.22,'plea_explain'),
('Odisseu','Não tivemos prazer em sua dor',159.62,162.8,3.18,'plea_chest'),
('Odisseu','Nós só queríamos escapar',162.8,167.8,5.0,'plea_eyes'),
('Poseidon','A linha entre a ingenuidade e',167.8,171.2,3.4,'judge'),
('Poseidon','A esperança é quase invisível',171.2,175.28,4.08,'small'),
('Poseidon','Então feche seu coração',175.8,178.0,2.2,'darken'),
('Poseidon','O mundo é sombrio e',178.0,179.5,1.8,'dissolve'),
('Poseidon','Crueldade é piedade',179.5,181.78,2.28,'jaw'),
('Poseidon','Morra',181.78,185.0,3.7,'impact')]
beats=[]
for i,(speaker,text,rs,re,duration,shot) in enumerate(rows):
 duration=max(duration,len(text)/30.0+0.7)
 beats.append(dict(id=i,speaker=speaker,text=text,ref_start=rs,ref_end=re,duration=round(duration,2),shot=shot,hold=0.0))
Path('Ato4_Tempestade/Cutscenes/Ruthlessness.dialogue.json').write_text(json.dumps(beats,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=Path('Docs/POSEIDON_STORYBOARD.md')
s=p.read_text(encoding='utf-8-sig').split('\n## Mapa final das falas para montagem')[0]
s+='\n## Mapa final das falas para montagem\n\nTranscrição local `base.en` concluída. Ela reconheceu incorretamente vários trechos cantados e repetiu texto no ataque; essas palavras não foram usadas. As faixas abaixo são aproximações de montagem verificadas contra a sequência visual e o texto fornecido, não alinhamento fonético certificado. A primeira identificação também não foi reconhecida de modo confiável pelo ASR. Pausas/refrões sem texto fornecido viram ação silenciosa; nenhuma nova fala é criada.\n\n| ID | Referência (s) | Duração no jogo (s) | Personagem | Texto português | Plano |\n|---|---|---|---|---|---|\n'
for b in beats:s+=f"| {b['id']} | {b['ref_start']:.2f}–{b['ref_end']:.2f} | {b['duration']:.2f} | {b['speaker'] or 'Ação silenciosa'} | {b['text'].replace(chr(10),' / ')} | {b['shot']} |\n"
s+=f"\nDuração de montagem: cerca de {sum(b['duration'] for b in beats):.1f} s, mais entrada/saída. As legendas em português impõem alongamentos pequenos de leitura. A abertura 00:00–00:24 da referência é condensada para continuar a cena existente; a montagem central preserva a ordem e as durações de ação, inclusive os intervalos de galope e apoio que antes tinham refrão.\n"
p.write_text(s,encoding='utf-8')
# Bounds avoid neighboring poses; none of the source PNG pixels are edited.
regions={
 'poseidon':{'texture':'res://Assets/act4_poseidon/poseidon_poses.png','regions':[[78,3,425,516],[552,3,472,516],[1070,3,415,516],[24,520,480,490],[522,520,508,490],[1044,520,450,490]]},
 'contact':{'texture':'res://Assets/act4_poseidon/contact_poses_v2.png','regions':[[18,22,616,580],[640,64,600,542],[2,631,768,543],[771,665,470,520]]},
 'kneeling':{'texture':'res://Assets/act4_poseidon/odysseus_kneeling.png','regions':[[20,145,620,396],[659,235,581,309],[10,627,635,521],[649,627,593,521]]},
 'horse':{'texture':'res://Assets/act4_poseidon/water_horse.png','regions':[[20,36,494,443],[515,95,523,365],[1035,95,486,375],[10,530,590,444],[635,480,296,510],[1000,515,520,470]]}}
regions['god_faces']={'texture':'res://Assets/act4_poseidon/poseidon_faces.png','regions':[[0,0,512,489],[512,0,512,489],[1024,0,512,489],[0,520,512,488],[512,520,512,488],[1024,520,512,488]]}
Path('Assets/act4_poseidon/regions.json').write_text(json.dumps(regions,indent=2)+'\n',encoding='utf-8')
print(len(beats),'beats;',round(sum(b['duration'] for b in beats),1),'s')
