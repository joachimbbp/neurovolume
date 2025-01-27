# Neurovolume (WIP)
Neurovolume is a VDB-based fMRI visualization and analysis pipeline. This project is currently a work in progress.


# Usage
The usage for Neurovolume is presently spread across a few different scripts. Once we remove dependencies and write our own, custom functions, we will be able to package this entire project within a single Blender plugin. We will also provide a library which can be adapted into other plugins and standalone tools.

It is possible to the `functions.py` library to pull some VDBs out of fMRI data. This, however, has not yet been implemented in the blender plugin.

This project uses poetry for dependency management.

## Basic Pipeline for Static MRIs
- Run the `niigz2npy` script. This converts all compressed `nii.gz` `NIFTI` files to `.npy` files containing normalized numpy arrays. (Make sure your output folder is empty).

```shell
cd src/neurovolume
Python niigz2npy.py <path/to/output/folder/> <input/folder/one/> <input/folder/two> </etc.../>
```
- Open blender and import the plugin found at `blender_plugin/__init__.py`
You can do this by copy and pasting the code into the blenders text editor and running it there.
- Once this is running, a GUI should appear on the right side of the 3D view. Paste the path to the folder containing your `.npy` files and click `Load .npy Files into Blender`
- This should load the VDB files into blender for shading, animation, rendering, etc.
![Blender Instructions](readme_media/blender_instructions.png)

# Why VDB?
VDBs are a highly performant, art-directable, volumetric data structure that supports animations.  Unlike typical meshed based pipelines using the marching cubes algorithm, this volume based approach preserves the scan’s normalized density data throughout the VFX pipeline. The animation support will also be particularly useful when animating FMRI data as outlined in the roadmap below.

For more information on VDBs, see the [openVDB website](https://www.openvdb.org/)


# Dataset Citation
This software was tested using the following datasets.

Isaac David and Victor Olalde-Mathieu and Ana Y. Martínez and Lluviana Rodríguez-Vidal and Fernando A. Barrios (2021). Emotion Category and Face Perception Task Optimized for Multivariate Pattern Analysis. OpenNeuro. [Dataset] doi: 10.18112/openneuro.ds003548.v1.0.1

The MNI Template can be found [Here](https://github.com/Angeluz-07/MRI-preprocessing-techniques/tree/main/assets/templates)