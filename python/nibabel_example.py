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
f = data.flatten()
n = (f - f.min()) / (f.max() - f.min())
res = n.reshape(data.shape)

output = "/Users/joachimpfefferkorn/repos/neurovolume/output/from_nib.vdb"
nv.ndarray_to_VDB(res, output)

# WARN: output path needs to be clear!
