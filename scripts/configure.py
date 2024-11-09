import sys

PROFILE_HEADER = '''
[Groups/0]
Name=Default
Default Layout=us
DefaultIM={0}
'''

PROFILE_ITEM = '''
[Groups/0/Items/{0}]
Name={1}
Layout=
'''

PROFILE_TAIL = '''
[GroupOrder]
0=Default
'''

with open('build/profile', 'w') as f:
    f.write(PROFILE_HEADER.format(sys.argv[1]))
    for i in range(len(sys.argv) - 1):
        f.write(PROFILE_ITEM.format(i, sys.argv[i + 1]))
    f.write(PROFILE_TAIL)
