from pathlib import Path
import sys,subprocess
from PIL import Image,ImageDraw
sys.path.insert(0,str(Path('scratch/athena_animatic_preview/python_deps').resolve()))
import imageio_ffmpeg
root=Path('scratch/poseidon_preview')
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
with (root/'encode.log').open('w') as log:
    subprocess.run([ffmpeg,'-y','-i',str(root/'poseidon.avi'),'-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart',str(root/'poseidon.mp4')],stdout=log,stderr=log,check=True)
    subprocess.run([ffmpeg,'-y','-i',str(root/'poseidon.mp4'),'-vf','fps=1/4,scale=480:270',str(root/'movie_%03d.jpg')],stdout=log,stderr=log,check=True)
frames=sorted(root.glob('movie_[0-9][0-9][0-9].jpg'))
for first in range(0,len(frames),16):
    board=Image.new('RGB',(1920,1200),'#101821');draw=ImageDraw.Draw(board)
    for j,p in enumerate(frames[first:first+16]):
        x,y=j%4*480,j//4*300
        with Image.open(p) as im:board.paste(im,(x,y))
        draw.text((x+10,y+277),f'{(first+j)*4:03}s',fill='white')
    board.save(root/f'movie_board_{first//16+1}.jpg',quality=94)
print('movie bytes',(root/'poseidon.mp4').stat().st_size,'samples',len(frames))
