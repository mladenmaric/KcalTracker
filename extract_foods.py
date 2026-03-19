import re, sys, os

sys.stdout.reconfigure(encoding='utf-8')

BASE = 'C:/Users/Mladen/AppData/Local/Temp/claude/d--OneDrive-ClaudeCodeProjects-KcalTracker/e5dd3fb7-3379-469f-9295-20dd74402a4e/tasks'
FILES = ['aeed959ef795d24f8', 'a841da3b7e174a3bf', 'af0e517128b68b9c9', 'aa17a3ebedee7c240', 'a78d2d322dbb9b32d']

seen = set()
food_rows = []

for fid in FILES:
    path = f'{BASE}/{fid}.output'
    content = open(path, encoding='utf-8', errors='replace').read()
    # Greedy regex: name can contain apostrophes/quotes
    # Match: ('any text', num, num, num, num)
    # Use greedy .+ then backtrack to last ', num pattern
    matches = re.findall(r"\('(.+)', ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)", content)
    for name, kcal, p, c, f in matches:
        key = name.lower()
        if key in seen:
            continue
        seen.add(key)
        # Escape single quotes for Dart
        nd = name.replace("'", "\\'")
        food_rows.append(f"      ('{nd}', {kcal}, {p}, {c}, {f}),")

print(f'// {len(food_rows)} unique foods', file=sys.stderr)

out = '\n'.join(food_rows)
open('C:/Users/Mladen/AppData/Local/Temp/foods_dart2.txt', 'w', encoding='utf-8').write(out)
print(f'Written {len(food_rows)} foods to foods_dart2.txt', file=sys.stderr)
