import bpy
import pyopenvdb as vdb
import numpy as np
import json
import os

def build_grid(scivol_file, grid_name):
    print(f"building {grid_name}")
    vol = np.asarray(scivol_file['grids'][grid_name]['frames'][0]) #TODO 4D non-static grid when implementing fMRI
    print(f"vol shape: {vol.shape}")
    grid = vdb.FloatGrid()
    grid.copyFromArray(vol.astype(float), tolerance = scivol_file['tolerance'])
    grid.gridClass = scivol_file['grids'][grid_name]['grid_class']
    grid.name = grid_name
    return grid

#paths hard coded for now
scivol_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/skullstrip.scivol"
output_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/combined_grid01.vdb"

with open(scivol_path, 'r') as file:
    scivol_file = json.load(file)
print(f"{scivol_file['name']} loaded into blender")

#grids = []
#for grid_name in scivol_file['grids']:
#    grids.append(build_grid(scivol_file, grid_name))

test_grid = build_grid(scivol_file, 'full_anat')

print("writing vdb file")
vdb.write(output_path, [test_grid]) #Testing with just one grid for now
bpy.ops.object.volume_import(filepath=output_path, files=[])

print("applying affine")
affine = scivol_file['affine']
print("done")