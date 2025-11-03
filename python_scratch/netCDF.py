# WARN: this is very and will be deleted when I push to main
# the purpose of this is just to parse the netCDF data for verification
# these are just global pip installs, don't take the python environment here
# to be anything but a spawning groud for true eldritch horrors.


from netCDF4 import Dataset
rootgrp = Dataset(
    "/Users/joachimpfefferkorn/repos/neurovolume/media/netCDF/merg_2025010123_4km-pixel.nc4.nc4", "w", format="NETCDF4")
# rootgrp = Dataset("doesnt/exista", "w", format="NETCDF4")

print(rootgrp)
rootgrp.close()
