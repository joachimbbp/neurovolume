# standalone executable (eventually) for converting compressed `npy.gz`  files into .npy files
# Eventually replace ANTs with your own functions and let this all live within Blender

import os
import ants
import numpy as np
import re

# FUNCTIONS
def parent_dir():
    return os.path.dirname(os.path.dirname(os.getcwd()))

def create_volume(tensor):
    """
    For some reason, this loop is needed to create
    a volume that isn't just pure noise once converted
    to a VDB.
    """
    mri_volume = np.zeros(tensor.shape)
    for z_index in range(tensor.shape[2]):
        sagittal_slice = tensor[:, :, z_index]
        for row_index, row in enumerate(sagittal_slice):
            for col_index, _ in enumerate(row):
                density = sagittal_slice[row_index][col_index]
                mri_volume[row_index][col_index][z_index] = density
    return mri_volume

def vol_from_path(path):
    """
    Returns a VDB tensor from the NiFTY
    """
    print(f"    Creating Volume for {os.path.basename(path)}")
    return create_volume(ants.image_read(path).numpy())
    #TODO replace ants.image_read().numpy() with custom function

def get_name(var):
    """
    Returns the name of a variable
    """
    for name, value in globals().items():
        if value is var:
            return name
        
def save_npy(vol: np.ndarray, name: str, output_dir: str):
    print(f"    Saving {name}")
    with open(f'{output_dir}/{name}.npy', 'wb') as f:
        np.save(f, np.array(vol))

def get_name(var):
    """
    Returns the name of a variable
    """
    for filename, value in globals().items():
        if value is var:
            if "_path" in filename:
                return filename.replace("_path", "")

# CONTROL FLOW
options = input("Manually Enter Paths: m\nOverride with hard coded test paths: o\n")
match options:
    case 'm':
        anat_path = input('Enter path for Anatomy Scan:\n')
        bold_path = input('Enter path for BOLD Scan:\n')
        mni_template_path = input('Enter path for MNI Template:\n')
        mni_mask = input('Enter path for MNI Mask:\n')
        output_dir = input('Enter save path for .npy files:\n')
    case 'o':
        anat_path = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01/anat/sub-01_T1w.nii.gz"
        bold_stim_path = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01/func/sub-01_task-emotionalfaces_run-1_bold.nii.gz"
        bold_rest_path = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01/func/sub-01_task-rest_bold.nii.gz"
        mni_template_path =  "/Users/joachimpfefferkorn/repos/neurovolume/media/templates/mni_icbm152_t1_tal_nlin_sym_09a.nii"
        mni_mask_path = "/Users/joachimpfefferkorn/repos/neurovolume/media/templates/mni_icbm152_t1_tal_nlin_sym_09a_mask.nii"
        output_dir = "/Users/joachimpfefferkorn/repos/neurovolume/output"
    case '_':
        print("Invalid option, exiting program")
        exit()

print("Gathering Paths...")
paths = [anat_path, bold_stim_path, bold_rest_path, mni_template_path, mni_mask_path]
print("Establishing Names...")
names = [get_name(path) for path in paths]
print("Building Volumes...")
vols = [vol_from_path(path) for path in paths]

#maybe this could be a dictionary but I sort of like this?
print(f"Saving .npy files to {output_dir}...")
for idx, vol in enumerate(vols):
    save_npy(vol, names[idx], output_dir)
print("Done")
exit()