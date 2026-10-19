"""Encode the locally recorded playable route and create a visual review sheet."""
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path('scratch/athena_animatic_preview/python_deps').resolve()))
import imageio_ffmpeg

root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('scratch/poseidon_escape_preview')
stem = sys.argv[2] if len(sys.argv) > 2 else 'escape'
interval = 6 if stem == 'fleet' else 3
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
with (root / 'encode.log').open('w', encoding='utf-8') as log:
    subprocess.run([ffmpeg, '-y', '-i', str(root / f'{stem}.avi'), '-c:v', 'libx264', '-preset', 'fast', '-crf', '22', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart', str(root / f'{stem}.mp4')], stdout=log, stderr=log, check=True)
    subprocess.run([ffmpeg, '-y', '-i', str(root / f'{stem}.mp4'), '-vf', f'fps=1/{interval},scale=576:324', str(root / 'movie_%03d.jpg')], stdout=log, stderr=log, check=True)
frames = sorted(root.glob('movie_[0-9][0-9][0-9].jpg'))
for first in range(0, len(frames), 12):
    board = Image.new('RGB', (1728, 1400), '#101821')
    draw = ImageDraw.Draw(board)
    for i, frame in enumerate(frames[first:first + 12]):
        x, y = i % 3 * 576, i // 3 * 350
        with Image.open(frame) as im:
            board.paste(im, (x, y))
        draw.text((x + 8, y + 330), f'{(first + i) * interval:02}s', fill='white')
    board.save(root / f'movie_board_{first // 12 + 1}.jpg', quality=94)
print('MP4 bytes', (root / f'{stem}.mp4').stat().st_size, 'review samples', len(frames))
