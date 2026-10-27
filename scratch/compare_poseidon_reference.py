"""Create local visual comparisons; reference frames never become game assets."""
from pathlib import Path
import json,subprocess,sys
from PIL import Image,ImageDraw
sys.path.insert(0,str(Path('scratch/athena_animatic_preview/python_deps').resolve()))
import imageio_ffmpeg
out=Path('scratch/poseidon_preview')
beats=json.loads(Path('Ato4_Tempestade/Cutscenes/Ruthlessness.dialogue.json').read_text(encoding='utf-8'))
choices=[(1,1.0),(4,3.0),(5,0.8),(11,3.5),(12,3.0),(20,2.3),(23,2.0),(24,6.0),(25,6.0),(29,2.0),(33,2.0),(38,2.1)]
offset=4.6 # measured/approximate predecessor question + cinematic presenter entry
rows=[]
for idx,age in choices:
    reference=beats[idx]['ref_start']+min(age,beats[idx]['ref_end']-beats[idx]['ref_start'])
    movie=offset+sum(b['duration'] for b in beats[:idx])+age
    dst=out/f'comparison_movie_{idx:02}.jpg'
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-hide_banner','-loglevel','error','-y','-ss',str(movie),'-i',str(out/'poseidon.mp4'),'-frames:v','1','-vf','scale=576:324',str(dst)],check=True)
    source=Path('scratch/ruthlessness_reference')/f'frame_{int(reference*2)+1:04}.jpg'
    rows.append((idx,reference,movie,source,dst))
for start in range(0,len(rows),6):
    board=Image.new('RGB',(1152,2154),'#101821');draw=ImageDraw.Draw(board)
    for j,(idx,ref_t,movie_t,source,dst) in enumerate(rows[start:start+6]):
        y=j*359
        with Image.open(source) as im:board.paste(im.resize((576,324)),(0,y))
        with Image.open(dst) as im:board.paste(im,(576,y))
        draw.text((8,y+331),f'Reference ~{ref_t:.2f}s',fill='white')
        draw.text((584,y+331),f'Game ~{movie_t:.2f}s | {beats[idx]["shot"]}',fill='white')
    board.save(out/f'comparison_{start//6+1}.jpg',quality=94)
print('Created',len(rows),'comparison pairs; timestamps approximate, audio not reused.')
