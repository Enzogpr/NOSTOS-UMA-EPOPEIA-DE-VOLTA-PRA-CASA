from pathlib import Path
import sys, subprocess
from PIL import Image, ImageDraw
sys.path.insert(0,str(Path('scratch/athena_animatic_preview/python_deps').resolve()))
import imageio_ffmpeg
out=Path('scratch/ruthlessness_reference'); out.mkdir(exist_ok=True)
(out/'.gdignore').write_text('')
v=Path(r'C:\Users\leiac\Downloads\vidssave.com Ruthlessness _ EPIC The Musical _ Animatic 720P.mp4')
f=imageio_ffmpeg.get_ffmpeg_exe()
r=subprocess.run([f,'-hide_banner','-i',str(v),'-vf','fps=2,scale=480:270','-y',str(out/'frame_%04d.jpg')],capture_output=True,text=True)
(out/'decode.log').write_text(r.stderr,encoding='utf-8'); r.check_returncode()
frames=sorted(out.glob('frame_*.jpg'))
for first in range(0,len(frames),36):
 b=Image.new('RGB',(1920,1152),'#101821'); d=ImageDraw.Draw(b)
 for j,p in enumerate(frames[first:first+36]):
  x,y=(j%6)*320,(j//6)*192
  with Image.open(p) as im: b.paste(im.resize((320,180)),(x,y))
  t=(first+j)*0.5+0.25
  d.text((x+5,y+180),f'{int(t//60):02}:{t%60:05.2f}',fill='white')
 b.save(out/f'board_{first//36+1:02}.jpg',quality=94)
print(len(frames),'frames at 2fps;',len(range(0,len(frames),36)),'boards')
