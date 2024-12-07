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
- [x]  Use `gz` compression for Scivol
- [ ] Try Napari for visualizations
- [ ] Try [SciPy Sparse](https://docs.scipy.org/doc/scipy/reference/sparse.html) for arrays 
- [ ] Custom fMRI object that includes the stimulus and action data encoded along the temporal dimension. Possibly integrate into scivol.
- [ ] Change `.scivol` to `.nerv`

Once these are addressed we can push to main:
- [ ] Animate fMRI activations as VDB emission in a separate `VDB` `Grid`
    - [x] Access stimulus data to correspond to animation
- [x] Rewrite helper functions as bespoke for this project
    - [x] Implement a 4D viewer for temporal dimension
- [ ] Cleanup and remove redundant functions
- [ ] Integrate notebook functions into functions file
- [ ] Standardize naming convetions: `timeslice` and `frame`, are the same thing, for instance
- [ ] Remove/squash/untrack old binaries (AE and Blender). *will this be solved by a squash and merge?* Verify.
- [ ] Remove unused libraries from Poetry

Bonuses:
- [ ] Eliminate `create_volume()` tensor creation function 
- [ ] Grid Specific Tolerance Levels
- [ ] Include experimental stimulus and baseline media

Long Term:
- [ ] Brain anatomy segmentation
- [ ] Convert blender script to blender plugin
- [ ] Standalone scivol reader/writer
    - [ ] for VDBs
    - [ ] for Pointclouds
- [ ] Rewrite as much of the external file parsing libraries with bespoke functions
    - [ ] Priority: replace ANTs
- [ ] Python Library
- [ ] GUI for node-based analysis