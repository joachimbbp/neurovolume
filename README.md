# fMRI Testing
**Please see the main branch for a working version of this project.**
This branch is for the development of animated fMRI usage. It is a work in progress. Many commits will contain local paths, messy code, broken functions, etc.

# Status
Anatomy successfully processes with `src/neuro_volume/anat_pipeline.ipynb`
Much of the roto skull strip isn't going to work presently in the dev container.

# Docker, Poetry, and Blender Scripts
The [dockerfile](https://github.com/joachimbbp/openvdb_docker) created by myself and [Zach Lipp](https://github.com/zachlipp) is currently under construction. **This commit currently reverts to the Poetry package manager and is not using the docker file.** This is due to some  long build times that arise when `PY_OPENVDB_WRAP_ALL_GRID_TYPES=ON` is activated in OpenVDB. Until this problem is solved, I will perform all the data manipulation in Numpy arrays, and then convert these to separate grids with the Blender scripts found in `src/blender_scripts`.

The last commit before this change can be found [here](https://github.com/joachimbbp/neurovolume/tree/0525ba0786782e71f84ca09189ae85bd7adfeb5b).

# Open Neuro
## Scan Data
Currently, only the scans being used for development are pushed to github. If you wish to view the entire dataset it can be found [here](https://openneuro.org/datasets/ds003548/versions/1.0.1) or downloaded with the following:

 `openneuro download --snapshot 1.0.1 ds003548 ds003548-download/`
## Citation
Isaac David and Victor Olalde-Mathieu and Ana Y. Martínez and Lluviana Rodríguez-Vidal and Fernando A. Barrios (2021). Emotion Category and Face Perception Task Optimized for Multivariate Pattern Analysis. OpenNeuro. [Dataset] doi: 10.18112/openneuro.ds003548.v1.0.1

Template [source](https://github.com/Angeluz-07/MRI-preprocessing-techniques/tree/main/assets/templates)

# Branch Goals:
Up next:
- [ ]  scivol load works, but it loads EVERYTHING onto memory. This won't work for larger fMRI implementations (unless you work off the workstation). There needs to be a solve for this:
	- More efficient JSON parser?
	- Standalone VDB converter? (Don't shave a yak, only do so if necessary)
- [ ] Full Anat is *very* blurry (although we can tune it back in the shader). We need to have **grid specific tolerance levels**

Once these are addressed we can push to main:
- [ ] Rebuild `pyopenvdb` with `NumPy` Support
    - Did work with previous docker file, put on hold due to issue below:
- [ ] Address missing `pyopenvdb.DoubleGrid`
    - `PY_OPENVDB_WRAP_ALL_GRID_TYPES` Needs to be defined at compile time as per the [docs](https://www.openvdb.org/documentation/doxygen/python.html). Needs to be addressed in the [docker file](https://github.com/joachimbbp/openvdb_docker). Image build takes approximately 47 minutes, but opening a dev container causes error messages and other unstableness.
    - [ ] Update to latest [openvdb_docker](https://github.com/joachimbbp/openvdb_docker) after next successful Build and Push
- [x] Move all blender scripting implementation into python source code (will fix `Issues` above)
- [ ] Animate fMRI activations as VDB emission in a separate `VDB` `Grid`
    - [Nipy viz](https://nipy.org/nipy/labs/viz.html) might be a better library than `nibabel`
    - [ ] Save stimulus data to correspond to animation
- [ ] Eliminate `create_volume()` tensor creation function 
- [x] Change fMRI dataset to [this](https://openneuro.org/datasets/ds003548/versions/1.0.1) open neuro project
- [x] Include example dataset in a non `.gitignored` media folder. Make sure to cite it            as per openneuro's requirements
- [x] Space height based on scan meta-data (z-space currently squashed)
