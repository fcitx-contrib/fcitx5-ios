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

file = sys.argv[1]
input_methods = sys.argv[2:]

with open(f'{file}', 'w') as f:
    f.write(PROFILE_HEADER.format(input_methods[0]))
    for i, input_method in enumerate(input_methods):
        f.write(PROFILE_ITEM.format(i, input_method))
    f.write(PROFILE_TAIL)
