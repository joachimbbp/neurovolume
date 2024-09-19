# fMRI Testing
**Please see the main branch for a working version of this project.**
This branch is for the development of animated fMRI usage. It is a work in progress. Many commits will contain local paths, messy code, broken functions, etc.

# Status
Anatomy successfully processes with `src/neuro_volume/anat_pipeline.ipynb`

# Docker
The dockerfile was created with myself and [Zach Lipp](https://github.com/zachlipp) (but mostly Zach). Integrating [OpenVDB](https://www.openvdb.org/) into a development environment is a challenge that affects many scientific visualization projects. Accordingly, we have a separate repo for this which can be found [here](https://github.com/joachimbbp/openvdb_docker). However, project specific tweaks, such as adding `Numpy` to the `openVDB` build, may not be reflected there.

Note that when working within a docker container (such as your own fMRI dataset), any external files must be copied over using `docker cp ./some_file CONTAINER:/work`.

# Open Neuro
## Scan Data
Currently, only the scans being used for development are pushed to github. If you wish to view the entire dataset it can be found [here](https://openneuro.org/datasets/ds003548/versions/1.0.1) or downloaded with the following:

 `openneuro download --snapshot 1.0.1 ds003548 ds003548-download/`
## Citation
Isaac David and Victor Olalde-Mathieu and Ana Y. Martínez and Lluviana Rodríguez-Vidal and Fernando A. Barrios (2021). Emotion Category and Face Perception Task Optimized for Multivariate Pattern Analysis. OpenNeuro. [Dataset] doi: 10.18112/openneuro.ds003548.v1.0.1

# Branch Goals:
Once these are addressed we can push to main:
- [x] Rebuild `pyopenvdb` with `NumPy` Support
- [x] Address missing `pyopenvdb.DoubleGrid`
    - `PY_OPENVDB_WRAP_ALL_GRID_TYPES` Needs to be defined at compile time as per the [docs](https://www.openvdb.org/documentation/doxygen/python.html). Needs to be addressed in the [docker file](https://github.com/joachimbbp/openvdb_docker)
- [x] Move all blender scripting implementation into python source code (will fix `Issues` above)
- [ ] Animate fMRI activations as VDB emission in a separate `VDB` `Grid`
    - [Nipy viz](https://nipy.org/nipy/labs/viz.html) might be a better library than `nibabel`
    - [ ] Save stimulus data to correspond to animation
- [ ] Eliminate `create_volume()` tensor creation function 
- [x] Change fMRI dataset to [this](https://openneuro.org/datasets/ds003548/versions/1.0.1) open neuro project
- [x] Include example dataset in a non `.gitignored` media folder. Make sure to cite it as per openneuro's requirements
- [x] Space height based on scan meta-data (z-space currently squashed)
- [ ] Update to latest [openvdb_docker](https://github.com/joachimbbp/openvdb_docker) after next successful Build and Push