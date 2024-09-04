# FMRI Testing
**Please see the main branch for a working version of this project.**
This branch is for the development of animated fMRI usage. It is a work in progress. Many commits will contain local paths, messy code, broken functions, etc.

# Issues
- It appears that the blender binaries sometimes cause problems with git. This will be a non issue once we move the VDB implementation into a docker container. However, please remember to save a copy of any blender scripting in `src/blender_scripts`

# Docker
The dockerfile was created with myself and [Zach Lipp](https://github.com/zachlipp) (but mostly Zach). Integrating [OpenVDB](https://www.openvdb.org/) into a development environment is a challenge that effects many scientific visualization projects. Accordingly, we have a seperate repo for this which can be found [here](https://github.com/joachimbbp/openvdb_docker).

Note that when working within a docker container (such as your own fMRI dataset), any external files must be copied over using `docker cp ./some_file CONTAINER:/work`.

# Neurovolume
## Info
- Can be downloaded with `openneuro download --snapshot 1.0.1 ds003548 ds003548-download/`
- URL: `https://openneuro.org/datasets/ds003548/versions/1.0.1`
## Citation
Isaac David and Victor Olalde-Mathieu and Ana Y. Martínez and Lluviana Rodríguez-Vidal and Fernando A. Barrios (2021). Emotion Category and Face Perception Task Optimized for Multivariate Pattern Analysis. OpenNeuro. [Dataset] doi: 10.18112/openneuro.ds003548.v1.0.1

# Joachim's Quick Goals:
- [x] Rebuild `pyopenvdb` with `NumPy` Support
- [ ] Reintegrate `pyopenvdb.DoubleGrid`
    - Despite existing in blender, we get this error in our dev container: `AttributeError: module 'pyopenvdb' has no attribute 'DoubleGrid'`
    - I suspect we are missing build support for something (like we were fur `Numpy`)
- [x] Move all blender scripting implementation into python source code (will fix `Issues` above)
- [ ] Animate VDB emission and color to show activations (as apposed to layering the anatomy and activation VDBs in blender)
    - [Nipy viz](https://nipy.org/nipy/labs/viz.html) might be a better library than `nibabel`
    - Changing the `GridClass` to something other than`FOG_VOLUME` is probably necessary.
- [ ] Fix your redundant, weird, sophomoric, `create_volume()` tensor creation function 
- [x] Change fMRI dataset to [this](https://openneuro.org/datasets/ds003548/versions/1.0.1) open neuro project
- [x] Include example dataset in a non `.gitignored` media folder. Make sure to cite it as per openneuro's requirements
- [ ] Space height based on scan meta-data (z-space currently squashed)