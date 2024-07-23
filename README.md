# Neuro Volume
A VDB representation of neurological MRI data.
![First Render](readme_media/brain_alpha_crop.png)

# Usage
- Generate a NumPy array suitable for conversion to a VDB, run the cells in `src/neuro_volume/generate_neuro_volume.ipynb`
- Convert the VDB and load it into blender as a volume by running the `vdb_from_numpy.py` script in the Blender file found here: `blender/vdb_from_numpy.blend`
    - Note this script can also be found in the `src` folder, but will only run in the Blender environment
- The material must be selected by hand after loading the VDB
![Blender Instructions](readme_media/blender_setup.png)

# Roadmap
- [ ] Docker Container to integrate OpenVDB into `src/neuro_volume`
- [ ] Automated Blender opening and texturing
- [ ] Animated FMRI usage
- [ ] Slice-level rotoscope-based anatomy masking
- [ ] Improve Blender VDB Texturing
 
# Contact
jbbpfefferkorn@gmail.com

# Citations
The MRI data used in this prototype is from openneuro.org

Philippe Poulin and Guillaume Theaud and Pierre-Marc Jodoin and Maxime Descoteaux (2022). TractoInferno: A large-scale, open-source, multi-site database for machine learning dMRI tractography. OpenNeuro. [Dataset] doi: doi:10.18112/openneuro.ds003900.v1.1.1