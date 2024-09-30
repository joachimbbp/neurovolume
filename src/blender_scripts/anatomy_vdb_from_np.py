#This script is for use in the blender 4.1.1 Python environment and will not work in the current "neuro_volume" environment
#This script can also be found in /blender/vdb_from_numpy.blend. This is where it is intended to be run
#Integrating this functionality into /src will require a Docker container. This is planned on the roadmap

import bpy
import pyopenvdb as openvdb
import numpy as np
import os

anatomy_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/anatomy.npy"
affine_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/affine.npy"
output_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/anatomy.vdb"

print("debug start")

anatomy_volume = np.load(anatomy_path)
affine = np.load(affine_path)

#Just identity for now
#affine = [
#    [1.0, 0.0, 0.0, 0.0],
#    [0.0, 1.0, 0.0, 0.0],
#    [0.0, 0.0, .0, 0.0],
#    [0.0, 0.0, 0.0, 1.0]
#]

print(affine)

anat_grid = openvdb.DoubleGrid()
anat_grid.copyFromArray(anatomy_volume.astype(float))
anat_grid.transform = openvdb.createLinearTransform(affine)
anat_grid.gridClass = openvdb.GridClass.FOG_VOLUME
anat_grid.name='anatomy'

openvdb.write(output_path,anat_grid)
bpy.ops.object.volume_import(filepath=output_path, files=[])