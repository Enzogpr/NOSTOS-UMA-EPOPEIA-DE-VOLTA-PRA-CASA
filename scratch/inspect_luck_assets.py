from pathlib import Path
from PIL import Image
import json

root = Path(__file__).resolve().parent.parent / 'Assets/act4_luck'
result = {}
for name, cols, rows in [('odysseus_luck_poses',3,2),('eurylochus_luck_poses',3,2),('brothers_luck',2,1)]:
    image = Image.open(root/(name+'.png')).convert('RGBA')
    width, height = image.size
    regions = []
    for index in range(cols*rows):
        x, y = (index%cols)*(width//cols), (index//cols)*(height//rows)
        cell = image.crop((x,y,x+width//cols,y+height//rows))
        # Region metadata only; PNG pixels and the generated alpha stay intact.
        mask = bytearray(cell.getchannel('A').point(lambda a: 1 if a>96 else 0).tobytes())
        cw, ch = cell.size
        components = []
        for origin in range(len(mask)):
            if not mask[origin]:
                continue
            stack, count = [origin], 0
            mask[origin] = 0
            left, top, right, bottom = cw, ch, 0, 0
            while stack:
                pixel = stack.pop()
                px, py = pixel%cw, pixel//cw
                left,top,right,bottom = min(left,px),min(top,py),max(right,px+1),max(bottom,py+1)
                count += 1
                for adjacent in [pixel-1 if px else -1,pixel+1 if px<cw-1 else -1,pixel-cw if py else -1,pixel+cw if py<ch-1 else -1]:
                    if adjacent>=0 and mask[adjacent]:
                        mask[adjacent]=0
                        stack.append(adjacent)
            components.append((count,(left,top,right,bottom)))
        components.sort(reverse=True)
        selected = components[:2] if name=='brothers_luck' else components[:1]
        bounds = (min(c[1][0] for c in selected),min(c[1][1] for c in selected),max(c[1][2] for c in selected),max(c[1][3] for c in selected))
        assert bounds, (name,index)
        left,top,right,bottom = bounds
        regions.append([x+max(0,left-3),y+max(0,top-3),min(cell.width,right+3)-max(0,left-3),min(cell.height,bottom+3)-max(0,top-3)])
    result[name] = {'texture':'res://Assets/act4_luck/'+name+'.png','regions':regions}
    if name=='odysseus_luck_poses':
        # Reuse the established pointing gesture with its entire hand inside
        # its original frame, avoiding an atlas gutter at the fingertips.
        result[name]['pose_overrides']={'4':{'texture':'res://Assets/act4_storm/odysseus_fullbody.png','region':[111,682,493,516]}}
    print(name, image.size, regions)
(root/'regions.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
