from pathlib import Path
import sys, subprocess
from PIL import Image, ImageDraw
sys.path.insert(0,str(Path('scratch/athena_animatic_preview/python_deps').resolve()))
import imageio_ffmpeg
root = Path('scratch/vigil_preview')
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
with (root/'encode.log').open('w') as log:
    subprocess.run([ffmpeg,'-y','-i',str(root/'nine_days.avi'),'-c:v','libx264','-preset','fast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart',str(root/'nine_days.mp4')],stdout=log,stderr=log,check=True)
    for path in root.glob('movie_[0-9][0-9][0-9].jpg'):
        path.unlink()
    subprocess.run([ffmpeg,'-y','-i',str(root/'nine_days.mp4'),'-vf','fps=1/5,scale=480:270',str(root/'movie_%03d.jpg')],stdout=log,stderr=log,check=True)
frames = sorted(root.glob('movie_[0-9][0-9][0-9].jpg'))
for batch in range((len(frames)+15)//16):
    board = Image.new('RGB',(1920,1200),'#121a22')
    draw = ImageDraw.Draw(board)
    for i,path in enumerate(frames[batch*16:(batch+1)*16]):
        x,y = (i%4)*480,(i//4)*300
        board.paste(Image.open(path),(x,y))
        draw.text((x+10,y+278),str((batch*16+i)*5)+'s',fill='white')
    board.save(root/('movie_board_'+str(batch+1)+'.jpg'),quality=92)
print('MP4 bytes:',(root/'nine_days.mp4').stat().st_size,'samples:',len(frames))
