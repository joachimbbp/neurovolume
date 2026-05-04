# Alpha
- [x] Multiple Grids
	- Implemented [here](https://github.com/joachimbbp/neurovolume/commit/0b132c6dbb74faa014e0f09d46b479720388e90c)
- [x] Sparsity (VDB Tiles) and interpolated frames
	- Implemented [here](https://github.com/joachimbbp/neurovolume/commit/cf7001b342d0439f8eda0ace781f4b3c05b80422)

# Beta Release
- [ ] Upgrade to Zig 0.16.0

- [ ] Fix `SaveConfig`
	- The whole save config thing is somewhat clunky, we should probably replace it. Most importantly: Move the logic currently in `SaveConfig` (name, output folder, overwrite) out of channel/volume `init` and into channel/volume `write` function
	- Establish some sane defaults here

- [ ] Improve Attribute Writing System
	-  Presently, the name of the grid is also the name of the attribute. This is probably not good. It has tripped me up in Blender and will probably trip up the user. Find what is a good balance of idiomatic and powerful.

- [ ] Asynchronously write sequence frames

- [ ] Automate the Zig-Python interface with a heuristic
	- This is presently AI generated (which is not good). Third party tools, such as Ziggy Pydust, lack documentation and are lagging behind language releases.
	- Doing so will speed up the iteration and allow you to test directly on the Python layer.

- [ ] Expand supported Operating Systems
	- All Mac, linux, windows, etc

- [ ] Benchmarks And Testing:
	- [ ] Improve Testing and CI/CD
	- [ ] Write benchmarks
	- Both will probably require downloading a hosted numpy array to ingest, convert to a VDB, and render.
		- [ ] Once done, delete stopgap code such as `numpy.zig` and `write_ndarray.py`.

- [ ] Add to VDB metadata (if possible):
	- [ ] prune level
	- [ ] Add arbitrary fields that the user can set

- [ ] Allow sequences to have channels of variable timelines
	- [ ] If one channel is shorter than the other, just stop writing voxels when it ends
	- [ ] Add an channel offset option

- [ ] Improve terminal logs
	- These really need a full overhaul. They’re pretty haphazard right now and don’t follow any sort of convention

- [ ] Dry all errors in some unified spot


- [ ] Write documentation

# Release Candidate
- [ ] Add `__repr__` to Sequence, Channel, Grid, Volume, and SaveConfig
- [ ] Contributors code of conduct 
	- [ ] Find a balanced AI policy

# Future
- [ ] Standalone zig library
	- Both zig and Python libraries should look like each other
	- Zig library is probably going to be focused on simulations, so not sure if we will need native file parsing (numpy, NIfTI, etc) or not. Trying to cover every possible file is probably unwise.
- [ ] Add source RGB values to the output VDB
- [ ] Directly delete points (and otherwise edit) an existing VDB file
	- Useful for data cleanup in blender, etc
