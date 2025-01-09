import bpy
import pyopenvdb as openvdb
import numpy as np
import os
import pathlib

data_folder = "/Users/joachimpfefferkorn/repos/neurovolume/output/blender_alignment"
vdb_seq_folder = data_folder

def vdb_from_npy(npy):
    basename = os.path.basename(npy).split('.')[0]
    volume = np.load(f"{data_folder}/{npy}")
    grid = openvdb.DoubleGrid()
    grid.copyFromArray(volume.astype(float))
    grid.gridClass = openvdb.GridClass.FOG_VOLUME
    grid.name='density'
    openvdb.write(f"{vdb_seq_folder}/{basename}.vdb",grid)

def load_bold_seq(npy):
    print("bold sequence not implemented yet")

print("starting loop")
for npy in os.listdir(data_folder):
    print(f"reading in {npy}")
    match pathlib.Path(f"{data_folder}/{npy}").name:
        case "mask.npy":
            print("mask")
            vdb_from_npy(npy)
            #TODO
            #   load mask
            #   mesh from mask volume
            #   delete mask
        case "anat.npy":
            print("anat")
            vdb_from_npy(npy)
            #TODO
            #   load anat
        case "bold.npy":
            print("bold")
            load_bold_seq(npy)