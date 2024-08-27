#This script is for use in the blender 4.1.1 Python environment and will not work in the current "neuro_volume" environment
#This script can also be found in /blender/vdb_from_numpy.blend. This is where it is intended to be run
#Integrating this functionality into /src will require a Docker container. This is planned on the roadmap

#Running this script in blender will generate the VDB and import it into blender
#The vdb_vol material will need to be added manually

import bpy
import pyopenvdb as openvdb
import numpy as np
import os

#TODO Once integrated into docker, generate these with functions/parent_directory()
filename = "/Users/joachimpfefferkorn/repos/neurovolume/output/brain_volume.npy"
output_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/brain_volume_vdb.vdb"

Volume = np.load(filename)

transform_matrix = [
    [1.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 0.0],
    [0.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 1.0]
]

#creates a grid
grid = openvdb.DoubleGrid()
#copies image volume from numpy to the grid (which is a vdb)
grid.copyFromArray(Volume.astype(float))
#scales grid slice thickness and pixel size using modified identity transform ... hmm...
grid.transform = openvdb.createLinearTransform(transform_matrix)

#Sets grid class to FOG_VOLUME
grid.gridClass = openvdb.GridClass.FOG_VOLUME
#name grid 'density' as per blender conventions
grid.name='density'
#writes vdb file
openvdb.write(output_path,grid)
#adds file to scene
bpy.ops.object.volume_import(filepath=output_path, files=[])/Users/joachimpfefferkorn/repos/neurovolume/output/brain_volume.npy