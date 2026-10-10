"""Read-only story inventory: save original dialogue for preservation checks."""
import ast
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
output = root / "scratch" / "campaign_review"
output.mkdir(exist_ok=True)
sources = sorted(root.glob("Ato*/Cutscenes/*.gd"))
sources.append(root / "Ato2_Lotofagos/Fase1_IlhaDosLotofagos.gd")
arrays = {}
art = set()
names = r"texts|images|slides|resolution_slides|slides_part1|slides_part2|slides_part3_win|slides_part3_lose|cutscene_slides"
for source in sources:
    code = source.read_text(encoding="utf-8-sig")
    for match in re.finditer(r"var\s+(" + names + r")\s*(?::=|=)\s*(\[)", code):
        start = match.start(2)
        depth, quote, escaped = 0, False, False
        for end in range(start, len(code)):
            char = code[end]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    quote = False
            elif char == '"':
                quote = True
            elif char in "[{":
                depth += 1
            elif char in "]}":
                depth -= 1
                if depth == 0:
                    break
        values = ast.literal_eval(code[start:end + 1])
        arrays[source.relative_to(root).as_posix() + ":" + match.group(1)] = values
        for value in values:
            path = value.get("image", "") if isinstance(value, dict) else value
            if isinstance(path, str) and path.startswith("res://Assets/"):
                file = root / path.removeprefix("res://")
                candidates = [file, *[file.with_suffix(suffix) for suffix in [".png", ".jpg", ".jpeg", ".webp"]]]
                actual = next((p for p in candidates if p.is_file()), None)
                art.add(actual.relative_to(root).as_posix() if actual else "MISSING:" + path)
snapshot = {"arrays": arrays, "art": sorted(art)}
target = output / "original_story.json"
if not target.exists():
    target.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2), encoding="utf-8")
else:
    original = json.loads(target.read_text(encoding="utf-8"))
    expected = json.loads(json.dumps(original['arrays']))
    expected['Ato1_Troia/Cutscenes/Act1_IntroCutscene.gd:texts'][3] = expected['Ato1_Troia/Cutscenes/Act1_IntroCutscene.gd:texts'][3].replace('Odisseu e seus espartanos', 'Odisseu e seus guerreiros de Ítaca')
    expected['Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.gd:slides_part3_win'][0]['text'] = expected['Ato3_Ciclope/Cutscenes/Act3_BlindingCutscene.gd:slides_part3_win'][0]['text'].replace('Se não foi Ninguém, então pare de chorar!', 'Se foi Ninguém, então pare de chorar!')
    assert arrays == expected, 'Dialogue changed beyond the two explicitly approved corrections.'
    print('STORY PRESERVATION: PASS (only two approved substitutions)')
print(json.dumps({"sequences": len(arrays), "unique_art": len(art), "missing": [p for p in art if p.startswith("MISSING:")]}, ensure_ascii=False))
