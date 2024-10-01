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
anat_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/anatomy.npy"
affine_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/affine.npy"
output_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/anatomy_vdb.vdb"
#Deeply weird glitch. The basename for the vdb MUST be different from the basename of the numpy file!
anatomy_volume = np.load(anat_path)

affine = np.load(affine_path)


print(affine)

grid = openvdb.FloatGrid() #FloatGrid supported without crazy build times
grid.copyFromArray(anatomy_volume.astype(float))
grid.gridClass = openvdb.GridClass.UNKNOWN
grid.name='anatomy'
grid.transform = openvdb.createLinearTransform(affine)

openvdb.write(output_path,grid)
bpy.ops.object.volume_import(filepath=output_path, files=[])



#SO, our afine is nicely formatted as per openvdb's specifications, however the linear transform does not work. Ugh.
#As a solve, we COULD dial this in as volume transformations in blender. NOT GREAT but it should work
