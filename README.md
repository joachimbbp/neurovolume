# FMRI Testing
**Please see the main branch for a working version of this project.**
This branch is for the development of animated FMRI usage. It is a work in progress. Many commits will contain local paths, messy code, broken functions, etc.

# Issues
It appears that the blender binaries sometimes cause problems with git. This will be a non issue once we move the VDB implementation into a docker container. However, please remember to save a copy of any blender scripting in `src/blender_scripts`

# Docker
The dockerfile was created with myself and [Zach Lipp](https://github.com/zachlipp) (but mostly Zach). Integrating [OpenVDB](https://www.openvdb.org/) into a development environment is a challenge that effects many scientific visualization projects. Accordingly, we have a seperate repo for this which can be found [here](https://github.com/joachimbbp/openvdb_docker).

# Joachim's quick goals:
- [ ] Move all blender scripting implementation into python source code (will fix `Issues` above)
- [ ] Animate VDB emission and color to show activations (as apposed to layering the anatomy and activation VDBs in blender)
    - [Nipy viz](https://nipy.org/nipy/labs/viz.html) might be a better library than nibabel
- [ ] Fix your redundant, weird, sophomoric tensor creation function 
- [ ] Change fMRI dataset to [this](https://openneuro.org/datasets/ds003548/versions/1.0.1) open neuro project