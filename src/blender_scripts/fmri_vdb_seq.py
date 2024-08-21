import bpy
import pyopenvdb as openvdb
import numpy as np
import os
import pathlib

npy_seq_folder = "/Users/joachimpfefferkorn/repos/neurovolume/output/npy_seq"
vdb_seq_folder = "/Users/joachimpfefferkorn/repos/neurovolume/output/vdb_seq"


transform_matrix = [
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 1.0]
]

for tensor in os.listdir(npy_seq_folder):
    print(f"reading in {tensor}")
    file_basename = os.path.basename(tensor)
    
    if pathlib.Path(f"{npy_seq_folder}/{tensor}").suffix == ".npy":
        Volume = np.load(f"{npy_seq_folder}/{tensor}")
        grid = openvdb.DoubleGrid()
        grid.copyFromArray(Volume.astype(float))
        grid.transform = openvdb.createLinearTransform(transform_matrix)
        grid.gridClass = openvdb.GridClass.FOG_VOLUME
        grid.name='density'
        openvdb.write(f"{vdb_seq_folder}/{file_basename}.vdb",grid)
        print(f"added {file_basename}")