import bpy
import pyopenvdb as vdb
import numpy as np
import json
import os
import gzip

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
scivol_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/compression_test.gz"
output_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/combined_neuro_1.vdb"

with gzip.open(scivol_path, 'r') as svin:
    print('opening scivol path')
    scivol_bytes = svin.read()
print('decoding scivol to utf-8 string')
scivol_str = scivol_bytes.decode('utf-8')
print('converting string to JSON format')
scivol_file = json.loads(scivol_str)

grids = []
for grid_name in scivol_file['grids']:
   grids.append(build_grid(scivol_file, grid_name))

print("writing vdb file")
vdb.write(output_path, grids)
bpy.ops.object.volume_import(filepath=output_path, files=[])

print("done")