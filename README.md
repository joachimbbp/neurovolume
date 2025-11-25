![Render of a non-skull stripped MNI Template](readme_media/mni_template_render.png)

Neurovolume is a Python library for manipulating and visualizing volumetric data. It includes a custom-built, scientific data-focused, VDB writer. The VDB writer is written in Zig with no external dependencies. Currently some `NIfTI1` files can be parsed natively.

While this project focuses on neuroscience, it includes `ndarray` to `VDB` to support virtually any volumetric data pipeline.

This project is very much a **work in progress**. (see "Missing Features" below). As of now, I do not recommend regarding the images created by this software as scientifically accurate.


# 🐍 ndArray Example

The following following is an example of how you might use this project in a neuroscience pipeline. (While it requires external dependencies, this implementation actually runs faster than the native `NIfTI1` parsing implementation)

````python
import nibabel as nib
import neurovolume_lib as nv
import numpy as np
from datetime import datetime

static_testfile = "./media/sub-01_T1w.nii"

def normalize_array(arr):
    return (arr - np.min(arr)) / (np.max(arr) - np.min(arr))

img = nib.load(static_testfile)
data = np.array(img.get_fdata(), order='C', dtype=np.float64)
norm = normalize_array(data).astype(np.float64)

norm = np.transpose(norm, (1, 2, 0))
norm = np.ascontiguousarray(norm)

output = "./output/from_nib.vdb"
nv.ndarray_to_VDB(norm, output, img.affine)
````
Note that all data must be normalized from 0.0-1.0 before being written to a VDB.

# ☁️ Why VDB?
VDBs are a highly performant, art-directable, volumetric data structure that supports animations. Our volume-based approach aims to provide easy access to the original density data throughout the visualization and analysis pipeline. Unlike the [openVDB repo](https://www.openvdb.org/), our smaller version is much more readable and does not need to be run in a docker container.


# 🛠️ Missing Features
While a comprehensive road-map will be published soon, there are a few important considerations to take into account now.
- Presently the VDB writer isn't sparse nor does it support multiple grids. Tiles and multiple grids are in development.
- Neurovolume currently only natively supports `NIfTI1` files (and only some variants). Full coverage and `NIfTI2` will be supported soon. Until then, you can use an `ndarray` as an intermediary (see Python Usage).
- Frame interpolation (present in the original Go prototype) is currently under development on this branch. If you wish to access the old Go code, check out [the archive](https://github.com/joachimbbp/neurovolume_archive)
- Documentation has not been written yet.


# 🧠 Dataset Citation
This software was tested using the following datasets.

Isaac David and Victor Olalde-Mathieu and Ana Y. Martínez and Lluviana Rodríguez-Vidal and Fernando A. Barrios (2021). Emotion Category and Face Perception Task Optimized for Multivariate Pattern Analysis. OpenNeuro. [Dataset] doi: 10.18112/openneuro.ds003548.v1.0.1

[OpenNeuro Study Link](https://openneuro.org/datasets/ds003548/versions/1.0.1)

[Direct Download Link for T1 Anat test file](https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/anat/sub-01_T1w.nii.gz?versionId=5ZTXVLawdWoVNWe5XVuV6DfF2BnmxzQz)

[Direct Download Link for BOLD test file](https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/func/sub-01_task-emotionalfaces_run-1_bold.nii.gz?versionId=tq8Y3ktm31Aa8JB0991n9K0XNmHyRS1Q)
 
The MNI Template can be found [Here](https://github.com/Angeluz-07/MRI-preprocessing-techniques/tree/main/assets/templates)
