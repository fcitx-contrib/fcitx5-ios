import json
import sys

src = sys.argv[1]
dst = sys.argv[2]

with open(src) as f:
    data = json.load(f)

with open(dst, 'w') as f:
    for word, value in data.items():
        f.write(f"{word}\t{value['frequency']}\n")
