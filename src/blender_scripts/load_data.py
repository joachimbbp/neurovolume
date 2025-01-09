import bpy
import pyopenvdb as openvdb
import numpy as np
import os
import pathlib

data_folder = "/Users/joachimpfefferkorn/repos/neurovolume/output/blender_alignment"
output_dir = data_folder

load_vdb = (lambda npy: np.load(f"{data_folder}/{npy}"))

def generate_vdb_frame(basename, volume, save_dir=output_dir):
    grid = openvdb.DoubleGrid()
    grid.copyFromArray(volume.astype(float))
    grid.gridClass = openvdb.GridClass.FOG_VOLUME
    grid.name='density'
    openvdb.write(f"{save_dir}/{basename}.vdb",grid)

def static_vdb_from_npy(npy):
    basename = os.path.basename(npy).split('.')[0]
    generate_vdb_frame(basename, load_vdb(npy))

def vdb_seq_from_npy(npy):
    seq_folder = f"{data_folder}/bold_seq"
    os.mkdir(seq_folder)
    vdb_seq = load_vdb(npy)
    for frame_idx in range(vdb_seq.shape[3]):
        #frame_filename = f"{seq_folder}/{"bold_{:02d}".format(frame_idx)}"
        frame_filename = f"bold_{frame_idx}"
        generate_vdb_frame(frame_filename, vdb_seq[:,:,:,frame_idx], save_dir=seq_folder)

print(f"searching in {data_folder}")
for npy in os.listdir(data_folder):
    print(f"reading in {npy}")
    match pathlib.Path(f"{data_folder}/{npy}").name:
        case "mask.npy":
            print("mask")
            static_vdb_from_npy(npy)
            #TODO
            #   load mask
            #   mesh from mask volume
            #   delete mask
        case "anat.npy":
            print("anat")
            static_vdb_from_npy(npy)
            #TODO
            #   load anat
        case "bold.npy":
            print("bold")
            vdb_seq_from_npy(npy)