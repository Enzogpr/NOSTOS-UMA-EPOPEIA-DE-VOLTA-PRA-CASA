import os
import time

now = time.time()
found = []
dirs = [
    r"C:\Users\Dionatan\.gemini",
    os.environ.get("TEMP", r"C:\Users\Dionatan\AppData\Local\Temp")
]

for d in dirs:
    for root, _, files in os.walk(d):
        for f in files:
            if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp')):
                full = os.path.join(root, f)
                try:
                    mt = os.path.getmtime(full)
                    if now - mt < 300: # 5 min
                        found.append((mt, full))
                except:
                    pass

found.sort(reverse=True)
for mt, path in found[:5]:
    print(f"{time.ctime(mt)}: {path}")
