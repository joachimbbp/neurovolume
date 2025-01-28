# standalone executable (eventually) for converting compressed `npy.gz`  files into .npy files
# Eventually replace ANTs with your own functions and let this all live within the Blender Plugin

import os
import ants
import numpy as np
import json
import sys

# FUNCTIONS
def parent_dir():
    return os.path.dirname(os.path.dirname(os.getcwd()))

def create_normalized_volume(tensor):
    """
    Creates a normalized tensor
    """
    mri_volume = np.zeros(tensor.shape)
    normed_tensor = np.array((tensor - np.min(tensor)) / (np.max(tensor) - np.min(tensor)))
    for z_index in range(normed_tensor.shape[2]):
        sagittal_slice = normed_tensor[:, :, z_index]
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
    return create_normalized_volume(ants.image_read(path).numpy())

def extract_metadata(ants_img_path, output_folder):
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

def read_args(scan_dirs, output_dir):
    for item in scan_dirs:
        if os.path.isdir(item):
            print(f'Directory Found {item}')
            sub_items = [f'{item}/{sub_item}' for sub_item in os.listdir(item)]
            read_args(sub_items, output_dir)
        else:
            file_split = item.split(".")
            if len(file_split) >= 2:
                if file_split[1] == "nii":
                    try:
                        extract_metadata(item, output_dir)
                        print(f"    Saved Metadata .json file from {item}")
                    except Exception as e:
                        print(f'    Error extracting Metadata .json file from {item}\n     Exception\n     {e}')
                        continue

                    try:
                        save_name = f'{output_dir}/{os.path.basename(item).split(".")[0]}.npy'
                        with open(save_name, 'wb') as f:
                            np.save(f, np.array(vol_from_path(item)))
                            print(f'        Saved .npy volume to {save_name}')
                    except Exception as e:
                        print(f'    Error saving volume {item}\n     Exception\n     {e}')
                        continue

                else:
                    print(f'    {item} first extension is not ".nii" Moving on to next item')
                    continue
            else:
                print(f'    {item} does not contain the proper amount of extensions or names (more than two total). Moving to next item')

print("Output:", sys.argv[1])
print("Media:", sys.argv[2:])
read_args(sys.argv[2:], sys.argv[1])
#read_args(["/Users/joachimpfefferkorn/repos/neurovolume/media"], "/Users/joachimpfefferkorn/repos/neurovolume/output")
print("done")