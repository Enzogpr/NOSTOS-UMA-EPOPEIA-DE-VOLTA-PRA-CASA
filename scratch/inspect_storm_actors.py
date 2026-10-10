"""Read-only alpha inspection; records foot anchors without editing the images."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
definitions = {}
for key, filename, height, flip in [
    ("odysseus_storm", "odysseus_fullbody.png", 520, False),
    ("eurylochus_storm", "eurylochus_fullbody.png", 450, True),
]:
    path = ROOT / "Assets" / "act4_storm" / filename
    with Image.open(path) as image:
        assert image.mode == "RGBA", f"{filename}: true alpha required"
        width, rowsize = image.width // 2, image.height // 2
        alpha = image.getchannel("A")
        bounds, anchors = [], []
        for index in range(4):
            left, top = (index % 2) * width, (index // 2) * rowsize
            # Inspect one quadrant, preserving every source pixel unchanged.
            frame = alpha.crop((left, top, left + width, top + rowsize))
            box = frame.point(lambda value: 255 if value > 32 else 0).getbbox()
            assert box is not None
            x0, y0, x1, y1 = box
            assert x0 >= 4 and y0 >= 4 and x1 <= width - 4 and y1 <= rowsize - 4, f"{filename} frame {index}: silhouette touches an atlas edge"
            feet_top = y1 - max(10, int((y1 - y0) * 0.10))
            feet = frame.crop((0, feet_top, width, y1)).point(lambda value: 255 if value > 32 else 0).getbbox()
            anchors.append([(feet[0] + feet[2]) / 2, y1])
            bounds.append(list(box))
        definitions[key] = {
            "texture": "res://Assets/act4_storm/" + filename,
            "columns": 2, "rows": 2, "height": height, "flip": flip,
            "anchors": anchors, "bounds": bounds,
        }
        print(filename, image.size, "alpha bounds:", bounds, "foot anchors:", anchors)
(ROOT / "Assets" / "act4_storm" / "fullbody_actors.json").write_text(json.dumps(definitions, indent=2) + "\n", encoding="utf-8")
