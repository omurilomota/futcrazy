"""Gera props 3D low-poly do FutCrazy no Blender e exporta GLB.

Uso:
    blender -b -P tools/blender/make_props.py

Saída:
    assets/models/trophy.glb   (taça dourada, base em y=0)
    assets/models/mascot.glb   (mascote galo sobre pedestal, base em y=0)

Os arquivos .py são a fonte; o jogo NÃO precisa do Blender para rodar.
"""

import math
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "models"))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.6, metallic=0.0):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    return m


def cube(name, dims, loc, material, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = dims
    o.data.materials.append(material)
    return o


def cyl(name, radius, depth, loc, material, rot=(0.0, 0.0, 0.0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def cone(name, r1, r2, depth, loc, material, rot=(0.0, 0.0, 0.0), verts=12):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def sphere(name, radius, loc, material, scale=(1.0, 1.0, 1.0), segs=16, rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.data.materials.append(material)
    return o


def torus(name, major, minor, loc, material, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=20, minor_segments=8)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(material)
    return o


def join_and_export(name, path):
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    bpy.ops.object.shade_flat()
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    print("exportado:", path)


# --------------------------------------------------------------------- taça

def build_trophy():
    reset()
    gold = mat("Gold", (0.95, 0.72, 0.18), rough=0.28, metallic=1.0)
    dark = mat("TrophyBase", (0.14, 0.16, 0.22), rough=0.55)
    white = mat("TrophyBall", (0.95, 0.95, 0.92), rough=0.5)

    cyl("Base1", 0.30, 0.10, (0, 0, 0.05), dark)
    cyl("Base2", 0.22, 0.08, (0, 0, 0.14), gold)
    cyl("Stem", 0.055, 0.34, (0, 0, 0.35), gold)
    cone("Cup", 0.16, 0.32, 0.34, (0, 0, 0.69), gold, verts=20)
    torus("Rim", 0.33, 0.035, (0, 0, 0.86), gold)
    sphere("Ball", 0.105, (0, 0, 0.90), white, segs=12, rings=8)
    torus("HandleL", 0.11, 0.028, (-0.36, 0, 0.70), gold, rot=(0, math.pi / 2, 0))
    torus("HandleR", 0.11, 0.028, (0.36, 0, 0.70), gold, rot=(0, math.pi / 2, 0))

    join_and_export("Trophy", os.path.join(OUT, "trophy.glb"))


# ------------------------------------------------------------------- mascote

def build_mascot():
    reset()
    orange = mat("MascotBody", (0.95, 0.45, 0.12), rough=0.55)
    cream = mat("MascotChest", (0.98, 0.80, 0.45), rough=0.6)
    red = mat("MascotComb", (0.86, 0.13, 0.16), rough=0.5)
    yellow = mat("MascotBeak", (0.98, 0.80, 0.18), rough=0.45)
    dark = mat("MascotEye", (0.06, 0.06, 0.08), rough=0.35)
    stone = mat("Pedestal", (0.42, 0.45, 0.50), rough=0.8)
    navy = mat("MascotShirt", (0.12, 0.25, 0.55), rough=0.6)

    # pedestal
    cyl("PedestalBase", 0.55, 0.16, (0, 0, 0.08), stone, verts=20)
    cyl("PedestalTop", 0.46, 0.14, (0, 0, 0.23), stone, verts=20)

    # corpo
    sphere("Body", 0.44, (0, 0, 0.86), orange, scale=(1.0, 0.78, 1.05))
    sphere("Chest", 0.30, (0, -0.20, 0.80), cream, scale=(1.0, 0.55, 0.95))
    # camisa listrada (faixa)
    cyl("ShirtBand", 0.42, 0.22, (0, 0, 0.92), navy, rot=(0, 0, 0), verts=20)

    # cabeça
    sphere("Head", 0.28, (0, -0.02, 1.42), orange)
    cone("Beak", 0.10, 0.0, 0.22, (0, -0.30, 1.40), yellow, rot=(math.pi / 2, 0, 0))
    sphere("Comb1", 0.075, (0, 0.02, 1.70), red, segs=10, rings=6)
    sphere("Comb2", 0.06, (0, -0.10, 1.68), red, segs=10, rings=6)
    sphere("Comb3", 0.055, (0, 0.13, 1.67), red, segs=10, rings=6)
    cone("Wattle", 0.05, 0.02, 0.10, (0, -0.20, 1.28), red, rot=(math.pi, 0, 0), verts=8)
    sphere("EyeL", 0.035, (-0.12, -0.24, 1.50), dark, segs=8, rings=6)
    sphere("EyeR", 0.035, (0.12, -0.24, 1.50), dark, segs=8, rings=6)

    # asas
    sphere("WingL", 0.20, (-0.40, 0.02, 0.95), orange, scale=(0.5, 0.9, 1.0))
    sphere("WingR", 0.20, (0.40, 0.02, 0.95), orange, scale=(0.5, 0.9, 1.0))

    # cauda
    for i, (dx, tilt) in enumerate([(-0.14, -0.4), (0.0, 0.0), (0.14, 0.4)]):
        cone(f"Tail{i}", 0.10, 0.0, 0.50, (dx, 0.36, 1.05), red,
             rot=(math.radians(55), tilt, 0), verts=8)

    # pernas e pés
    cyl("LegL", 0.055, 0.28, (-0.15, 0, 0.42), yellow, verts=10)
    cyl("LegR", 0.055, 0.28, (0.15, 0, 0.42), yellow, verts=10)
    cube("FootL", (0.16, 0.26, 0.08), (-0.15, -0.06, 0.28), yellow)
    cube("FootR", (0.16, 0.26, 0.08), (0.15, -0.06, 0.28), yellow)

    join_and_export("Mascot", os.path.join(OUT, "mascot.glb"))


def main():
    os.makedirs(OUT, exist_ok=True)
    build_trophy()
    build_mascot()
    print("ok:", OUT)


if __name__ == "__main__":
    main()
