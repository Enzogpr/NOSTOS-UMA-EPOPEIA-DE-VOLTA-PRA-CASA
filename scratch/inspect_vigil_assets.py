from pathlib import Path
from PIL import Image
import json
root = Path(__file__).resolve().parent.parent / 'Assets/act4_vigil'
result = {}
for name,cols,rows in [('odysseus_vigil',2,2),('penelope_vision',1,1),('wind_bag_betrayal',2,1)]:
    image = Image.open(root/(name+'.png')).convert('RGBA')
    assert image.getchannel('A').getextrema()[0] == 0, name
    width,height = image.size
    regions = []
    for index in range(cols*rows):
        x,y = index%cols*(width//cols),index//cols*(height//rows)
        cell = image.crop((x,y,x+width//cols,y+height//rows))
        bounds = cell.getchannel('A').point(lambda a: 255 if a>96 else 0).getbbox()
        left,top,right,bottom = bounds
        left,top = max(0,left-2),max(0,top-2)
        right,bottom = min(cell.width,right+2),min(cell.height,bottom+2)
        regions.append([x+left,y+top,right-left,bottom-top])
    if name == 'wind_bag_betrayal':
        # Both contact poses use one common baseline and scale, including the plume.
        top = min(r[1] for r in regions)
        bottom = max(r[1]+r[3] for r in regions)
        for region in regions:
            region[1],region[3] = top,bottom-top
    result[name]={'texture':'res://Assets/act4_vigil/'+name+'.png','regions':regions}
    print(name,image.size,regions)
(root/'regions.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
