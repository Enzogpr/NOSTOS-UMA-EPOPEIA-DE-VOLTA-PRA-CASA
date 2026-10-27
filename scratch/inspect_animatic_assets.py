from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parent.parent / 'Assets' / 'act3_athena_farewell'
result = {}
for name in ['odysseus_animatic', 'athena_animatic', 'odysseus_expressions', 'athena_expressions']:
    image = Image.open(root / (name+'.png')).convert('RGBA')
    width, height = image.size
    cells = []
    for index in range(4):
        x, y = (index % 2) * (width//2), (index//2) * (height//2)
        bottom = y + height//2
        # The lower figures' hair/crests start slightly above the middle gutter.
        # Framing the largest connected figure preserves those pixels without
        # changing the PNG or including the separate feet in the cell above it.
        if name.endswith('_animatic') and index >= 2:
            y -= 48
        cell = image.crop((x, y, x+width//2, bottom))
        # Ignore isolated pixels from a neighbouring cell when framing the feet.
        mask = bytearray(cell.getchannel('A').point(lambda value: 1 if value > 32 else 0).tobytes())
        cw, ch = cell.size
        largest = 0
        bounds = None
        for origin in range(len(mask)):
            if not mask[origin]:
                continue
            stack = [origin]
            mask[origin] = 0
            count = 0
            left, top, right, bottom = cw, ch, 0, 0
            while stack:
                pixel = stack.pop()
                px, py = pixel % cw, pixel // cw
                left, top, right, bottom = min(left, px), min(top, py), max(right, px+1), max(bottom, py+1)
                count += 1
                for adjacent in [pixel-1 if px else -1, pixel+1 if px < cw-1 else -1, pixel-cw if py else -1, pixel+cw if py < ch-1 else -1]:
                    if adjacent >= 0 and mask[adjacent]:
                        mask[adjacent] = 0
                        stack.append(adjacent)
            if count > largest:
                largest = count
                bounds = (left, top, right, bottom)
        assert bounds, (name, index)
        left, top, right, bottom = bounds
        cells.append([x+left, y+top, right-left, bottom-top])
    result[name] = {'texture': 'res://Assets/act3_athena_farewell/'+name+'.png', 'regions': cells}
    print(name, image.size, cells)
(root / 'animatic_regions.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
