import nibabel as nib
import neurovolume_lib as nv
import numpy as np
static_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"

print("loading file with nibabel")
img = nib.load(static_testfile)
print(type(img))
data = img.get_fdata()
print(type(data))
data = np.array(img.get_fdata(), order='C', dtype=np.float32)
print(f"Data shape: {data.shape}")
print(f"Data dtype: {data.dtype}")
print(f"Data min/max: {data.min()}, {data.max()}")
print(
    f"Data memory layout: C-contiguous={data.flags['C_CONTIGUOUS']}, F-contiguous={data.flags['F_CONTIGUOUS']}")
output = "/Users/joachimpfefferkorn/repos/neurovolume/output/from_nib.vdb"
nv.ndarray_to_VDB(data, output)
