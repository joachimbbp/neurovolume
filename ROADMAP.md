- [ ] Contributors code of conduct 
	- [ ] Find a balanced AI policy

- [ ] Automate the Zig-Python interface with a heuristic

- [ ] Add to VDB metadata (if possible):
	- [ ] prune level
	- [ ] Add arbitrary fields that the user can set

- [ ] Improve Testing and CI/CD
	- [ ] download a pre-computed numpy array, write, and render a VDB
	- [ ] some sort of benchmarking

- [ ] Allow sequences to have channels of variable timelines
	- [ ] If one channel is shorter than the other, just stop writing voxels when it ends
	- [ ] Add an channel offset option

- [ ] Move `SaveConfig` argument out of channel/volume `init` and into channel/volume `write` function
	- Probably establish some sane defaults here
	- The whole save config thing is somewhat clunky, we should probably replace it

- [ ] Improve Attribute Writing System
	-  Presently, the name of the grid is also the name of the attribute. This is probably not good. It has tripped me up in Blender and will probably trip up the user. Find what is a good balance of idiomatic and powerful.

- [ ] Asynchronously write sequence frames

- [ ] Improve terminal logs
	- These really need a full overhaul. They’re pretty haphazard right now and don’t follow any sort of convention

- [ ] Standalone zig library
	- If this happens, all the core functionality should live here. However, it is important that all of this functionality is also available in Python. The libraries should really look like each other.

- [ ] Dry all errors in some unified spot