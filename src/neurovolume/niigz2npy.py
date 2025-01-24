# standalone executable (eventually) for converting compressed `npy.gz`  files into .npy files
# Eventually replace ANTs with your own functions and let this all live within Blender

import os
import ants
import numpy as np

import json

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

def extract_metadata(ants_img_path, output_folder):
    print(f"    Extracting Metadata from {os.path.basename(ants_img_path)}")
    ants_img = ants.image_read(ants_img_path)
    filename = os.path.basename(ants_img_path.split('.')[0])
    info = str(ants_img).split('\n')

    metadata = {}
    for idx, entry in enumerate(info):
        strips = entry.strip().split(":")
        if len(strips) == 1 and idx==0:
            metadata["Header"] = strips[0].strip()
        elif len(strips) == 2:
            key, value = strips
            metadata[key.strip()] = value
        else:
            continue
    metadata_json = json.dumps(metadata, indent=4)
    with open(f'{output_folder}/{filename}.json', 'w') as outfile:
        outfile.write(metadata_json)

# CONTROL FLOW
#TODO Manually enter an arbitrary amount of paths as you want, including a folder. Implement in argparse
options = input("Enter template paths: t\nOverride with hard coded test paths: o\n")
match options:
    case 't':
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

paths = [anat_path, bold_stim_path, bold_rest_path, mni_template_path, mni_mask_path]
for path in paths:
    extract_metadata(path, output_dir)
    with open(f'{output_dir}/{os.path.basename(path).split(".")[0]}.npy', 'wb') as f:
        np.save(f, np.array(vol_from_path(path)))