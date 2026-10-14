from pathlib import Path
from PIL import Image
import json
root = Path(__file__).resolve().parent.parent / 'Assets/act4_friends'
result = {}
for name, cols, rows in [('aeolus_poses',3,2),('odysseus_bag_poses',3,2),('crew_poses',2,2),('winions_poses',2,2),('wind_bag',1,1)]:
    filename = 'crew_poses_v3' if name == 'crew_poses' else 'odysseus_bag_poses_v2' if name == 'odysseus_bag_poses' else name
    image = Image.open(root/(filename+'.png')).convert('RGBA')
    assert image.getchannel('A').getextrema()[0] == 0, name
    width, height = image.size
    regions = []
    for index in range(cols*rows):
        x,y = (index%cols)*(width//cols),(index//cols)*(height//rows)
        # The two crew rows have an asymmetric gutter at y=612.
        bottom_y = y+height//rows
        if name == 'crew_poses':
            y = 0 if index<2 else 612
            bottom_y = 612 if index<2 else height
        cell = image.crop((x,y,x+width//cols,bottom_y))
        # Metadata only: preserve original PNG pixels and alpha.
        mask = bytearray(cell.getchannel('A').point(lambda a: 1 if a>96 else 0).tobytes())
        cw,ch = cell.size
        components = []
        for origin in range(len(mask)):
            if not mask[origin]:
                continue
            stack,count = [origin],0
            mask[origin] = 0
            left,top,right,bottom = cw,ch,0,0
            while stack:
                pixel = stack.pop()
                px,py = pixel%cw,pixel//cw
                left,top,right,bottom = min(left,px),min(top,py),max(right,px+1),max(bottom,py+1)
                count += 1
                for adjacent in [pixel-1 if px else -1,pixel+1 if px<cw-1 else -1,pixel-cw if py else -1,pixel+cw if py<ch-1 else -1]:
                    if adjacent>=0 and mask[adjacent]:
                        mask[adjacent]=0
                        stack.append(adjacent)
            components.append((count,(left,top,right,bottom)))
        # Exclude tiny pieces from the neighboring row at an atlas gutter.
        components.sort(reverse=True)
        bounds = components[0][1] if components else None
        assert bounds, (name,index)
        left,top,right,bottom = bounds
        left,top = max(0,left-2),max(0,top-2)
        right,bottom = min(cell.width,right+2),min(cell.height,bottom+2)
        regions.append([x+left,y+top,right-left,bottom-top])
    result[name]={'texture':'res://Assets/act4_friends/'+filename+'.png','regions':regions}
    print(name,image.size,regions)
(root/'regions.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
