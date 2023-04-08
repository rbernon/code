#!/usr/bin/env python3

import os
import sys
import json

if 'proton' in sys.argv[1]:
  SRC = 'proton/wine'
  OBJ = 'build-proton/obj-wine'
else:
  SRC = sys.argv[1]
  OBJ = f'build-{sys.argv[1]}/build'

for bit in ['32', '64']:
  tgt = 'x86_64' if '64' in bit else 'i686'
  ccc = 'x86_64' if '64' in bit else 'i386'
  obj = os.path.expanduser(f'~/Code/{OBJ}{bit}')
  src = os.path.expanduser(f'~/Code/{SRC}')
  rep = 'src-wine' if 'proton' in obj else 'wine'
  rep = os.path.abspath(os.path.join(obj, '..', rep))
  opts = ' -Wno-pragma-pack -Wno-single-bit-bitfield-constant-conversion -UWINE_FONT_DIR'
  if bit == '32': opts += ' -Wno-format'

  db = {}
  with open(f'{obj}/Makefile', 'r') as make:
    for l in make.read().replace('\\\n', '').split('\n'):
      if '.o: ' in l and len(l.split(' ')) == 2:
        file = l.split(': ')[1]
        if not os.path.isabs(file):
          file = os.path.join(obj, file)
        file = file.replace(rep, src)

      if '\t$' in l and 'CC' in l and file is not None:
        l = l.replace(f'\t$({ccc}_CC)', f'clang -target {tgt}-w64-mingw32')
        l = l.replace(f'\t$(CROSSCC)', f'clang -target {tgt}-w64-mingw32')
        l = l.replace('\t$(CC)', f'clang -target {tgt}-linux-gnu -fshort-wchar')
        l = l.replace('/usr/lib/i386-linux-gnu/gstreamer-1.0/', f'/usr/lib/x86_64-linux-gnu/gstreamer-1.0/')
        db[file] = {'directory': obj, 'command': l.replace(rep, src) + opts}
        file = None

  for file in ['steamclient_main.c',
               'steamclient_manual_141.cpp',
               'steamclient_manual_142.cpp',
               'steamclient_manual_144.cpp',
               'steamclient_manual_146.cpp',
               'steamclient_manual_147.cpp',
               'steamclient_manual_148a.cpp',
               'steamclient_manual_150.cpp',
               'steamclient_manual_151.cpp',
               'steamclient_manual_152.cpp',
               'steamclient_manual_153a.cpp',
               'steamclient_wrappers.c']:
    if not 'proton' in obj: break

    file = f"{src.replace('wine', 'lsteamclient')}/{file}"
    dir = f"{obj.replace('wine', 'lsteamclient')}/lsteamclient.dll"
    cmd = f"clang -target {tgt}-linux-gnu -c {file} " + \
          f"-DSTEAM_API_EXPORTS -Dprivate=public -Dprotected=public " + \
          f"-I{obj.replace('obj', 'dst')}/include/wine " + \
          f"-I{src}/include -I{src}/include/wine -I. "

    db[file] = {"directory": dir, "command": cmd}

  with open(f'{obj}/compile_commands.json', 'w') as out:
    json.dump([dict({"file": k}, **v) for k, v in db.items()], out, indent=2)
