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
brain_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/brain_grid.npy"
exterior_anat_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/exterior_anat_grid.npy"

affine_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/affine.npy"
output_path = "/Users/joachimpfefferkorn/repos/neurovolume/output/combined_volumes.vdb"

affine = np.load(affine_path)
brain_vol = np.load(brain_path)
ext_anat_vol = np.load(exterior_anat_path)

brain_grid = openvdb.FloatGrid()
extanat_grid = openvdb.FloatGrid()

brain_grid.copyFromArray(brain_vol.astype(float), tolerance=0.2)
extanat_grid.copyFromArray(brain_vol.astype(float), tolerance=0.2)

brain_grid.gridClass = openvdb.GridClass.FOG_VOLUME
brain_grid.name = 'brain'
extanat_grid.gridClass = openvdb.GridClass.FOG_VOLUME
extanat_grid.name = 'external_anatomy'


openvdb.write(output_path,[brain_grid, extanat_grid])
bpy.ops.object.volume_import(filepath=output_path)#, files=[])


#SO, our afine is nicely formatted as per openvdb's specifications, however the linear transform does not work. Ugh.
#As a solve, we COULD dial this in as volume transformations in blender. NOT GREAT but it should work
#TODO eliminate unessesary vars here
bpy.ops.transform.resize(value=(affine[0][0], affine[1][1], affine[2][2]), orient_type='GLOBAL', orient_matrix=((1, 0, 0), (0, 1, 0), (0, 0, 1)), orient_matrix_type='GLOBAL', constraint_axis=(False, False, True), mirror=False, use_proportional_edit=False, proportional_edit_falloff='SMOOTH', proportional_size=1, use_proportional_connected=False, use_proportional_projected=False, snap=False, snap_elements={'INCREMENT'}, use_snap_project=False, snap_target='CLOSEST', use_snap_self=True, use_snap_edit=True, use_snap_nonedit=True, use_snap_selectable=False, release_confirm=True)

bpy.ops.transform.translate(value=(affine[3][0], affine[3][1], affine[3][2]), orient_type='GLOBAL', orient_matrix=((1, 0, 0), (0, 1, 0), (0, 0, 1)), orient_matrix_type='GLOBAL', constraint_axis=(False, True, False), mirror=False, use_proportional_edit=False, proportional_edit_falloff='SMOOTH', proportional_size=1, use_proportional_connected=False, use_proportional_projected=False, snap=False, snap_elements={'INCREMENT'}, use_snap_project=False, snap_target='CLOSEST', use_snap_self=True, use_snap_edit=True, use_snap_nonedit=True, use_snap_selectable=False, release_confirm=True)