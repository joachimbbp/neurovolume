# Neuro Volume
A VDB representation of neurological MRI data.
![First Render](readme_media/brain.png)

# Usage
- Generate a NumPy array suitable for conversion to a VDB, run the cells in `src/neuro_volume/generate_neuro_volume.ipynb`
- Convert the VDB and load it into blender as a volume by running the `vdb_from_numpy.py` script in the Blender file found here: `blender/vdb_from_numpy.blend`
    - Note this script can also be found in the `src` folder, but will only run in the Blender environment
- The material must be selected by hand after loading the VDB
![Blender Instructions](readme_media/blender_instructions.png)

# Why VDB?
VDBs are a highly performant, art-directable, volumetric data structure that supports animations. Unlike typical meshed based pipelines using the marching cubes algorithm, this volume based approach preserves the scan’s normalized density data throughout the VFX pipeline. The animation support will also be particularly useful when animating FMRI data as outlined in the roadmap below.

For more information on VDBs, see the [openVDB website](https://www.openvdb.org/)

# Roadmap
- [ ] Automated slice height spacing based on scan metadata
- [ ] Docker Container to integrate OpenVDB into `src/neuro_volume`
    - [Click here for Docker Container Progress](https://github.com/joachimbbp/openvdb_docker)
- [ ] Animated fMRI usage
    - [Click here for fMRI Progress](https://github.com/joachimbbp/neurovolume/tree/fmri_070825)
- [x] Improve Blender VDB texturing and slicing

# Contact
jbbpfefferkorn@gmail.com

# Dataset information
The MRI data used in this prototype is from openneuro.org

You can download the dataset [here](https://openneuro.org/datasets/ds003900/versions/1.1.1). It is located at `sub-100/anat/sub-1001_T1w.nii.gz`

## Citation
Philippe Poulin and Guillaume Theaud and Pierre-Marc Jodoin and Maxime Descoteaux (2022). TractoInferno: A large-scale, open-source, multi-site database for machine learning dMRI tractography. OpenNeuro. [Dataset] doi: doi:10.18112/openneuro.ds003900.v1.1.1