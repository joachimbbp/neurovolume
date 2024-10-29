import bpy
import pyopenvdb as vdb
import numpy as np
import json
import os

def build_grid(scivol_file, grid_name):
    print(f"building {grid_name}")
    #No affine applied in grid creation
    vol = np.asarray(scivol_file['grids'][grid_name]['frames'][0]) #TODO 4D non-static grid when implementing fMRI
    print(f"vol shape: {vol.shape}")
    grid = vdb.FloatGrid() #Hard coded for now. Doubt many edge cases need anything else here
    grid.copyFromArray(vol.astype(float), tolerance = scivol_file['tolerance'])
    grid.gridClass = scivol_file['grids'][grid_name]['grid_class']
    grid.name = grid_name
    return grid

#paths hard coded for now
scivol_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/skullstrip.scivol"
output_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/combined_grid.vdb"

with open(scivol_path, 'r') as file:
    scivol_file = json.load(file)
print(f"{scivol_file['name']} loaded into blender")

grids = {}
for grid_name in scivol_file['grids']:
    grids[grid_name] = build_grid(scivol_file, grid_name)

# THIS dictionary to list of variables thing isn't working!
pre_globals = set(globals().keys())
globals().update(grids)
grid_vars = list(set(globals().keys()) - pre_globals)
grid_values = [globals()[var_name] for var_name in grid_vars]
print(f"grid vars: {grid_vars, type(grid_vars)}") # could/should probably do this with locals tbh
print(f"grid values {grid_values}")

print(f"grids: {grids.keys()}")

print("writing vdb file")
vdb.write(output_path, grid_values)
bpy.ops.object.volume_import(filepath=output_path, files=[])

print("applying affine")
affine = scivol_file['affine']
#Terrible affine hack
bpy.ops.transform.resize(value=(affine[0][0], affine[1][1], affine[2][2]), orient_type='GLOBAL', orient_matrix=((1, 0, 0), (0, 1, 0), (0, 0, 1)), orient_matrix_type='GLOBAL', constraint_axis=(False, False, True), mirror=False, use_proportional_edit=False, proportional_edit_falloff='SMOOTH', proportional_size=1, use_proportional_connected=False, use_proportional_projected=False, snap=False, snap_elements={'INCREMENT'}, use_snap_project=False, snap_target='CLOSEST', use_snap_self=True, use_snap_edit=True, use_snap_nonedit=True, use_snap_selectable=False, release_confirm=True)
bpy.ops.transform.translate(value=(affine[3][0], affine[3][1], affine[3][2]), orient_type='GLOBAL', orient_matrix=((1, 0, 0), (0, 1, 0), (0, 0, 1)), orient_matrix_type='GLOBAL', constraint_axis=(False, True, False), mirror=False, use_proportional_edit=False, proportional_edit_falloff='SMOOTH', proportional_size=1, use_proportional_connected=False, use_proportional_projected=False, snap=False, snap_elements={'INCREMENT'}, use_snap_project=False, snap_target='CLOSEST', use_snap_self=True, use_snap_edit=True, use_snap_nonedit=True, use_snap_selectable=False, release_confirm=True)
print("done")