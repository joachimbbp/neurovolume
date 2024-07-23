#This script is for use in the blender 4.1.1 Python environment and will not work in the current "neuro_volume" environment
#This script can also be found in /blender/vdb_from_numpy.blend

import bpy
import pyopenvdb as openvdb
import numpy as np
import os


filename = "/Users/joachimpfefferkorn/repos/neuro_volume/src/neuro_volume/brain_volume.npy"
output_path = "/Users/joachimpfefferkorn/Desktop/neuro_volume.vdb"

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


#TODO Do you need to normalize the density (luma) between 0 and 1?

#Sets grid class to FOG_VOLUME
grid.gridClass = openvdb.GridClass.FOG_VOLUME
#name grid 'density' as per blender conventions
grid.name='density'
#writes vdb file
openvdb.write(output_path,grid)
#adds file to scene
bpy.ops.object.volume_import(filepath=output_path, files=[])