"""Blender 4.5+: build K17's authored modules and selected CC0 derivatives.

blender --background --python build_art_models.py -- --cache <source cache>
All authoring coordinates below use Godot's metres / Y-up convention.
"""
import argparse
import math
from pathlib import Path
import shutil
import sys
import bpy
from mathutils import Vector

args = argparse.ArgumentParser()
args.add_argument('--cache', required=True, type=Path)
options = args.parse_args(sys.argv[sys.argv.index('--') + 1:])
BASE = Path(__file__).resolve().parents[1]
OUT = BASE / 'assets' / 'models'
OUT.mkdir(parents=True, exist_ok=True)
TEX = BASE / 'assets' / 'textures'
TEX.mkdir(parents=True, exist_ok=True)
for asset in ['concrete_wall_001', 'concrete_floor_02', 'asphalt_02', 'corrugated_iron', 'rusty_metal_04']:
    (TEX / asset).mkdir(exist_ok=True)
    for image in (options.cache / asset).glob('*.jpg'):
        shutil.copy2(image, TEX / asset / image.name)


def material(name, color, metal=0, rough=.6, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Metallic'].default_value = metal
    node.inputs['Roughness'].default_value = rough
    if emission:
        node.inputs['Emission Color'].default_value = (*color, 1)
        node.inputs['Emission Strength'].default_value = emission
    return mat


OLIVE = material('K17 | olive enamel', (.17,.215,.105), .25, .48)
DARK = material('K17 | gunmetal', (.045,.06,.065), .65, .43)
STEEL = material('K17 | brushed steel', (.32,.36,.36), .8, .35)
RUBBER = material('K17 | rubber', (.018,.023,.023), 0, .9)
WOOD = material('K17 | supply plywood', (.32,.24,.12), 0, .88)
YELLOW = material('K17 | safety ochre', (.7,.43,.075), .15, .6)
PAPER = material('K17 | aged paper', (.64,.61,.45), 0, .9)
SCREEN = material('K17 | phosphor', (.09,.42,.32), 0, .35, 1.4)
RED = material('K17 | warning red', (.65,.035,.012), .1, .4, .5)
CLOTH = material('K17 | uniform twill', (.115,.155,.078), 0, .95)
WEBBING = material('K17 | canvas webbing', (.22,.24,.13), 0, .95)
SKIN = material('K17 | skin', (.52,.325,.20), 0, .85)


def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def g(v):
    return (v[0], -v[2], v[1])


def finish(obj, mat, name):
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def box(pos, size, mat=OLIVE, bevel=.025, name='part'):
    bpy.ops.mesh.primitive_cube_add(size=1, location=g(pos))
    obj = bpy.context.object
    obj.dimensions = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Manufactured edge radius', 'BEVEL')
        modifier.width = min(bevel, min(size) * .23)
        modifier.segments = 3
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return finish(obj, mat, name)


def sphere(pos, size, mat, name='rounded', segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=10, radius=1, location=g(pos))
    obj = bpy.context.object
    obj.scale = (size[0]/2, size[2]/2, size[1]/2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for p in obj.data.polygons:
        p.use_smooth = True
    return finish(obj, mat, name)


def cylinder(pos, radius, height, mat=STEEL, axis='y', name='cylinder', vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=height, location=g(pos))
    obj = bpy.context.object
    if axis == 'z':
        obj.rotation_euler.x = math.pi/2
    if axis == 'x':
        obj.rotation_euler.y = math.pi/2
    modifier = obj.modifiers.new('Edge highlight', 'BEVEL')
    modifier.width = min(.012, radius*.18)
    modifier.segments = 2
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    for p in obj.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    return finish(obj, mat, name)


def export(name, join=True):
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:
        obj.select_set(True)
    if join and objects:
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        joined = bpy.context.object
        bpy.context.scene.cursor.location = (0,0,0)
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        joined.name = name
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')), export_format='GLB', use_selection=True,
                              export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
    faces = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
    print('K17 MODEL', name, faces)


def imported(asset, part, name, bottom=True):
    clear()
    bpy.ops.import_scene.gltf(filepath=str(options.cache/asset/(asset+'.gltf')))
    chosen = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name == part]
    if len(chosen) != 1:
        raise ValueError('Missing asset part: '+part)
    for obj in list(bpy.context.scene.objects):
        if obj not in chosen:
            bpy.data.objects.remove(obj, do_unlink=True)
    obj = chosen[0]
    obj.location = (0,0,0)
    bpy.context.view_layer.update()
    points = [obj.matrix_world @ Vector(p) for p in obj.bound_box]
    lo = Vector([min(p[i] for p in points) for i in range(3)])
    hi = Vector([max(p[i] for p in points) for i in range(3)])
    offset = -(lo+hi)/2
    if bottom:
        offset.z = -lo.z
    obj.location += offset
    if len(obj.data.polygons) > 5500:
        bpy.context.view_layer.objects.active = obj
        decimate = obj.modifiers.new('Game mesh budget', 'DECIMATE')
        decimate.ratio = 5500/len(obj.data.polygons)
        bpy.ops.object.modifier_apply(modifier=decimate.name)
    print('CC0 BOUNDS', name, tuple(round(v,3) for v in hi-lo))
    export(name)


imported('modular_chainlink_fence', 'modular_chainlink_fence_double', 'fence_panel')
imported('industrial_caged_sconce', 'industrial_caged_sconce_a', 'caged_lamp')
imported('modular_industrial_pipes_01', 'modular_industrial_pipes_01_pipe01', 'pipe_straight', False)
imported('modular_industrial_pipes_01', 'modular_industrial_pipes_01_pipe04', 'pipe_valve', False)

# Crates: handles, reinforcing ribs, straps and feet are part of the silhouette.
clear()
box((0,0,0),(2.68,1.2,1.4),WOOD,.045)
for x in [-1.25,-.75,.75,1.25]:
    box((x,0,0),(.10,1.28,1.47),OLIVE,.01)
for z in [-.735,.735]:
    box((0,.47,z),(2.7,.10,.04),DARK,.006)
    box((0,-.45,z),(2.7,.10,.04),DARK,.006)
    for x in [-.95,.95]:
        box((x,.12,z),(.3,.035,.07),STEEL,.01)
for x in [-1.05,1.05]:
    box((x,-.62,0),(.24,.06,1.4),DARK,.008)
box((0,0,-.738),(.60,.31,.008),PAPER,.001)
for x in [-.18,-.10,.02,.11]:
    box((x,0,-.745),(.025,.18,.004),DARK,0)
export('supply_crate')

# Field office desks, a genuine tabletop over drawers with open knee space.
clear()
box((0,.35,0),(2.8,.10,1.2),OLIVE,.025)
for x in [-1.03,1.03]:
    box((x,-.02,0),(.50,.62,1.05),DARK,.03)
    for y in [-.20,0,.20]:
        box((x,y,-.54),(.46,.17,.025),OLIVE,.014)
        box((x,y+.03,-.565),(.18,.025,.04),STEEL,.008)
box((-.1,.42,.1),(.6,.025,.4),PAPER,.001)
box((.45,.43,.17),(.5,.045,.32),WEBBING,.003)
export('field_desk')

clear()
box((0,-.18,0),(1.9,1.75,1.0),OLIVE,.035)
box((0,.88,0),(2, .10,1.1),DARK,.018)
for x in [-.46,.46]:
    box((x,-.10,-.51),(.88,1.6,.055),OLIVE,.02)
    for y in [.48,.55,.62]:
        box((x,y,-.546),(.58,.016,.008),DARK,0)
    box((x+.25,-.1,-.57),(.035,.19,.06),STEEL,.012)
for x in [-.8,.8]:
    for z in [-.4,.4]:
        box((x,-1.02,z),(.14,.16,.14),DARK,.01)
export('locker')

# A two-sided archive shelving unit, folders and closed metal cabinets.
clear()
for x in [-2.65,2.65]:
    box((x,0,0),(.12,2.4,1.18),OLIVE,.012)
for y in [-1.15,-.40,.35,1.12]:
    box((0,y,0),(5.4,.09,1.18),DARK,.015)
box((0,0,.52),(5.3,2.3,.05),OLIVE,.01)
for row,y in enumerate([-.85,-.10,.65]):
    for i in range(12):
        x=-2.4+i*.42
        m=[WEBBING,PAPER,WOOD,OLIVE][(i+row)%4]
        box((x,y,0),(.34,.56,.75),m,.012)
        box((x,y,-.383),(.18,.08,.008),PAPER,.001)
export('archive_rack')

clear()
box((0,.49,0),(2.4,.12,1.2),STEEL,.025)
for x in [-1.0,1.0]:
    for z in [-.42,.42]:
        box((x,-.05,z),(.12,1,.12),DARK,.012)
box((0,.63,.1),(.95,.16,.63),OLIVE,.04)
for x in [-.37,.37]:
    box((x,.63,-.225),(.075,.10,.04),STEEL,.01)
export('archive_table')

# Analogue communications desk: CRT, radio stack, illuminated buttons and reels.
clear()
box((0,-.10,0),(2.9,.9,1.1),OLIVE,.045)
box((0,.39,0),(3,.1,1.2),DARK,.02)
for x in [-.85,.85]:
    box((x,.55,.18),(.9,.36,.65),DARK,.035)
    for y in [.48,.59,.69]:
        box((x,y,-.165),(.73,.06,.025),OLIVE,.008)
        for dx in [-.22,.15,.25]:
            cylinder((x+dx,y,-.19),.027,.028,STEEL,'z')
box((0,.57,.1),(.63,.48,.59),DARK,.04)
box((0,.60,-.205),(.50,.30,.024),SCREEN,.03)
for y in [.5,.55,.60,.65,.70]:
    box((0,y,-.220),(.44,.004,.002),DARK,0)
for i in range(8):
    box((-.9+i*.25,.46,-.43),(.13,.015,.14),[RUBBER,YELLOW,RED][i%3],.005)
export('comms_console')

clear()
for row in range(3):
    for i in range(3):
        x=-.54+i*.54+(0.15 if row%2 else 0)
        obj=box((x,row*.23-.24,0),(.63,.26,.55),WEBBING,.12)
        obj.rotation_euler.z=.05*(i-1)
export('sandbags')

clear()
cylinder((0,.10,0),.40,1.08,OLIVE,vertices=24)
for y in [-.38,-.15,.34,.61]:
    cylinder((0,y,0),.415,.025,DARK,vertices=24)
cylinder((.15,.65,0),.055,.02,STEEL)
export('fuel_drum')

clear()
box((0,0,0),(3.44,2.38,.16),DARK,.035)
for x in [-1.62,1.62]:
    box((x,0,-.11),(.13,2.28,.08),OLIVE,.01)
for y in [-1.05,-.35,.35,1.05]:
    box((0,y,-.11),(3.18,.12,.08),OLIVE,.012)
box((.9,.15,-.135),(.42,.16,.08),STEEL,.02)
cylinder((1.06,.15,-.23),.13,.045,STEEL,'z',vertices=24)
for x in [-1.5,-.5,.5,1.5]:
    cylinder((x,-.95,-.16),.027,.025,STEEL,'z')
export('blast_door')

# A floodlight head; pole, beam and physical light are placed in Godot.
clear()
box((0,0,0),(.84,.34,.24),DARK,.035)
box((0,0,-.13),(.71,.23,.02),PAPER,.016)
for x in [-.24,0,.24]:
    box((x,0,-.145),(.012,.23,.01),STEEL,.001)
export('floodlight')

clear()
box((0,0,0),(2.15,1.15,.08),OLIVE,.025)
box((0,0,-.045),(1.96,.97,.008),PAPER,.002)
for x,y,w,h in [(-.64,.12,.38,.48),(-.10,.16,.58,.40),(.54,.16,.48,.40),(.10,-.27,1.5,.16)]:
    for dx in [-w/2,w/2]: box((x+dx,y,-.055),(.015,h,.004),DARK,0)
    for dy in [-h/2,h/2]: box((x,y+dy,-.055),(w,.015,.004),DARK,0)
for x,y in [(-.65,.1),(.12,.16),(.62,.12)]:
    cylinder((x,y,-.07),.035,.02,RED,'z')
export('command_board')

# Anatomical military appearance, fitted to the shared articulated animation rig.
clear()
box((0,0,0),(.43,.49,.26),CLOTH,.10)
box((0,-.035,-.115),(.39,.36,.13),WEBBING,.035)
for x in [-.135,0,.135]:
    box((x,-.08,-.192),(.105,.14,.055),OLIVE,.018)
for x in [-.16,.16]:
    box((x,.18,-.15),(.06,.16,.055),WEBBING,.015)
box((-.115,.12,-.19),(.08,.12,.055),DARK,.015)
cylinder((-.14,.24,-.19),.008,.16,DARK)
box((.06,.05,-.23),(.10,.34,.07),DARK,.015)
cylinder((.06,-.22,-.23),.015,.22,DARK)
box((.06,.15,-.23),(.11,.12,.085),OLIVE,.015)
box((0,-.23,0),(.45,.06,.28),RUBBER,.01)
box((0,-.23,-.152),(.065,.045,.025),STEEL,.006)
export('soldier_torso')

clear()
sphere((0,0,0),(.235,.27,.225),SKIN,segments=24)
sphere((0,-.015,-.113),(.045,.07,.06),SKIN)
for x in [-.067,.067]:
    box((x,.03,-.103),(.05,.012,.015),DARK,.004)
    sphere((x*1.8,-.005,0),(.04,.065,.04),SKIN)
sphere((0,.135,.005),(.30,.21,.285),OLIVE,segments=24)
box((0,.075,-.12),(.285,.025,.09),OLIVE,.01)
for x in [-.105,.105]:
    box((x,-.015,-.045),(.012,.19,.018),WEBBING,.003)
box((0,-.102,-.10),(.18,.015,.022),WEBBING,.003)
export('soldier_head')

clear()
box((0,0,0),(.14,.50,.155),CLOTH,.065)
box((0,-.17,-.01),(.145,.11,.16),OLIVE,.025)
box((0,.14,.0),(.155,.14,.17),CLOTH,.045)
export('soldier_arm')
clear()
box((0,0,0),(.10,.14,.11),RUBBER,.045)
export('soldier_hand')
clear()
box((0,0,0),(.17,.77,.19),CLOTH,.07)
box((0,-.05,-.095),(.145,.18,.055),OLIVE,.035)
box((.08,.19,0),(.045,.20,.13),WEBBING,.015)
export('soldier_leg')
clear()
box((0,.025,0),(.18,.19,.29),RUBBER,.06)
box((0,-.055,-.005),(.19,.035,.30),DARK,.014)
for y in [.02,.06,.10]:
    box((0,y,-.12),(.12,.009,.025),WEBBING,.002)
export('soldier_boot')
clear()
box((0,0,0),(.35,.20,.24),CLOTH,.065)
export('soldier_pelvis')
print('K17 ART MODELS COMPLETE')
