"""Extract three reusable, normalized props from an official Godot TPS demo ZIP.

Usage: python tools/extract_tps_props.py path/to/tps.zip
Keeps only mesh geometry and assigns new materials; no demo scripts, textures or audio.
Source models: Juan Linietsky and Fernando Miguel Calabró, CC BY 3.0.
"""
import copy
import json
from pathlib import Path
import struct
import sys
import zipfile

OUT = Path(__file__).resolve().parents[1] / 'assets/models/tps'


def extract(archive):
    OUT.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as z:
        source = next(n for n in z.namelist() if n.endswith('/level/geometry/models/props.glb'))
        raw = z.read(source)
        length = struct.unpack_from('<I', raw, 12)[0]
        doc = json.loads(raw[20:20 + length])
        binary = raw[28 + length:]
        license_name = next(n for n in z.namelist() if n.endswith('/LICENSE.md'))
        (OUT / 'LICENSE.txt').write_bytes(z.read(license_name))
    for name, prefix in [('cargo', 'prop_cargobox3.'), ('gas_tank', 'prop_gastank3.'), ('machine', 'Reactor_greeblemachine.')]:
        node = next(n for n in doc['nodes'] if n.get('name', '').startswith(prefix) and 'mesh' in n)
        mesh = copy.deepcopy(doc['meshes'][node['mesh']])
        mesh['name'] = name
        result = {'asset': {'version': '2.0', 'copyright': 'Juan Linietsky, Fernando Miguel Calabró / Godot TPS Demo / CC BY 3.0'},
                  'scene': 0, 'scenes': [{'nodes': [0]}], 'nodes': [{'name': name, 'mesh': 0}],
                  'meshes': [mesh], 'accessors': [], 'bufferViews': [], 'materials': []}
        buf = bytearray()
        ids = {}

        def accessor(old):
            if old in ids:
                return ids[old]
            a = copy.deepcopy(doc['accessors'][old])
            v = copy.deepcopy(doc['bufferViews'][a['bufferView']])
            start = v.get('byteOffset', 0)
            block = binary[start:start + v['byteLength']]
            v.update(buffer=0, byteOffset=len(buf))
            buf.extend(block)
            buf.extend(b'\0' * (-len(buf) % 4))
            a['bufferView'] = len(result['bufferViews'])
            result['bufferViews'].append(v)
            ids[old] = len(result['accessors'])
            result['accessors'].append(a)
            return ids[old]

        lo, hi = [float('inf')] * 3, [float('-inf')] * 3
        for p in mesh['primitives']:
            a = doc['accessors'][p['attributes']['POSITION']]
            lo = [min(lo[i], a['min'][i]) for i in range(3)]
            hi = [max(hi[i], a['max'][i]) for i in range(3)]
        dims = [hi[i] - lo[i] for i in range(3)]
        center = [(hi[0] + lo[0]) / 2, lo[1], (hi[2] + lo[2]) / 2]
        for p in mesh['primitives']:
            old_mat = doc['materials'][p.get('material', 0)].get('name', '')
            glow = 'emitter' in old_mat.lower() or 'light' in old_mat.lower()
            mat = {'name': old_mat, 'pbrMetallicRoughness': {
                'baseColorFactor': [0.12, 0.65, 0.8, 1] if glow else [0.3, 0.4, 0.46, 1],
                'metallicFactor': 0.7, 'roughnessFactor': 0.38}}
            if glow:
                mat['emissiveFactor'] = [0.0, 0.8, 1.0]
            p['material'] = len(result['materials'])
            result['materials'].append(mat)
            p['indices'] = accessor(p['indices'])
            p['attributes'] = {key: accessor(value) for key, value in p['attributes'].items() if key in ('POSITION', 'NORMAL')}
        normalized = set()
        for p in mesh['primitives']:
            for kind, aid in p['attributes'].items():
                if aid in normalized:
                    continue
                normalized.add(aid)
                a = result['accessors'][aid]
                v = result['bufferViews'][a['bufferView']]
                offset = v['byteOffset'] + a.get('byteOffset', 0)
                for i in range(a['count']):
                    pos = offset + i * v.get('byteStride', 12)
                    xyz = struct.unpack_from('<3f', buf, pos)
                    if kind == 'POSITION':
                        xyz = [(xyz[j] - center[j]) / dims[j] for j in range(3)]
                    else:
                        xyz = [xyz[j] * dims[j] for j in range(3)]
                        norm = sum(n * n for n in xyz) ** 0.5 or 1
                        xyz = [n / norm for n in xyz]
                    struct.pack_into('<3f', buf, pos, *xyz)
                if kind == 'POSITION':
                    a['min'], a['max'] = [-0.5, 0, -0.5], [0.5, 1, 0.5]
        result['buffers'] = [{'byteLength': len(buf)}]
        js = json.dumps(result, separators=(',', ':')).encode()
        js += b' ' * (-len(js) % 4)
        glb = struct.pack('<III', 0x46546C67, 2, 28 + len(js) + len(buf))
        glb += struct.pack('<II', len(js), 0x4E4F534A) + js
        glb += struct.pack('<II', len(buf), 0x004E4942) + buf
        (OUT / f'{name}.glb').write_bytes(glb)
        print(name, len(glb), 'bytes')


if __name__ == '__main__':
    extract(sys.argv[1])
