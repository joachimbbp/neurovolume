![Render of a non-skull stripped MNI Template](readme_media/mni_template_render.png)

Neurovolume is a Python library for manipulating and visualizing volumetric data. It includes a custom-built, scientific data-focused, VDB writer. The VDB writer is written in Zig with no external dependencies. Currently some `NIfTI1` files can be parsed natively.

While this project focuses on neuroscience, it includes `ndarray` to `VDB` to support virtually any volumetric data pipeline.

This project is under active development and might not have everything you need (particularly if you are working with very large datasets). Please reference the "Missing Features" section.

This project is available as a pre-release alpha on [pypi](https://pypi.org/project/neurovolume/). Presently it is only available for arm64. More operating systems coming soon!

# 🏗️ Usage

Native NIfTI1 Parsing
````python
#                  path to .nii, output folder, normalization
vdb_path = nv.nifti1_to_VDB(anat, output, True)
# note output folder should look like "./output/" (slash on the end)
````
A full script, as well as a nibabel and ndarray examples, can be found in the [Neurovolume Examples](https://github.com/joachimbbp/neurovolume_examples).

# 📀 Projects
- [BoldViz](https://github.com/joachimbbp/boldviz): a Blender plugin for fMRI and MRI visualizations. It was used to create the renders in this README. A great place to start if you don't want to deal with writing any Python.
- [Neurovolume Examples](https://github.com/joachimbbp/neurovolume_examples) and [Physarum](https://github.com/joachimbbp/physarum) include some good starting points for how one might use this library with numpy. The [nibabel example](https://github.com/joachimbbp/neurovolume_examples/blob/master/nibabel_example.py) shows how to use an external NIfTI parser, which could be of use for not-yet-supported filetypes.

# ☁️ Why VDB?
VDBs are a highly performant, art-directable, volumetric data structure that supports animations. Our volume-based approach aims to provide easy access to the original density data throughout the visualization and analysis pipeline. Unlike the [openVDB repo](https://www.openvdb.org/), our smaller version is much more readable and does not need to be run in a docker container.

# 🛠️ Missing Features
While a comprehensive road-map will be published soon, there are a few important considerations to take into account now.
- Presently the VDB writer isn't sparse nor does it support multiple grids. Tiles and multiple grids are in development.
- Neurovolume currently only natively supports `NIfTI1` files (and only some variants). Full coverage and `NIfTI2` will be supported soon. Until then, you can use an `ndarray` as an intermediary (see Python Usage).
- Frame interpolation (present in the original Go prototype) is currently under development on this branch. If you wish to access the old Go code, check out [the archive](https://github.com/joachimbbp/neurovolume_archive)
- Documentation has not been written yet.
- pypi package presently only supports arm64. Coverage for linux and windows is in the works.


# 🧠 Dataset Citation
This software was tested using the following datasets.

Isaac David and Victor Olalde-Mathieu and Ana Y. Martínez and Lluviana Rodríguez-Vidal and Fernando A. Barrios (2021). Emotion Category and Face Perception Task Optimized for Multivariate Pattern Analysis. OpenNeuro. [Dataset] doi: 10.18112/openneuro.ds003548.v1.0.1

[OpenNeuro Study Link](https://openneuro.org/datasets/ds003548/versions/1.0.1)

[Direct Download Link for T1 Anat test file](https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/anat/sub-01_T1w.nii.gz?versionId=5ZTXVLawdWoVNWe5XVuV6DfF2BnmxzQz)

[Direct Download Link for BOLD test file](https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/func/sub-01_task-emotionalfaces_run-1_bold.nii.gz?versionId=tq8Y3ktm31Aa8JB0991n9K0XNmHyRS1Q)
 
The MNI Template can be found [Here](https://github.com/Angeluz-07/MRI-preprocessing-techniques/tree/main/assets/templates)
