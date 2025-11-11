import nibabel as nib
import neurovolume_lib as nv
import numpy as np
from datetime import datetime

static_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"


def normalize_array(arr):
    return (arr - np.min(arr)) / (np.max(arr) - np.min(arr))


print("loading file with nibabel")
start = datetime.now()
img = nib.load(static_testfile)
data = np.array(img.get_fdata(), order='C', dtype=np.float64)

# Normalize
norm = normalize_array(data).astype(np.float64)

# Reorient from NIfTI's axis order to VDB's expected order
norm = np.transpose(norm, (1, 2, 0))
norm = np.ascontiguousarray(norm)

output = "/Users/joachimpfefferkorn/repos/neurovolume/output/from_nib.vdb"
nv.ndarray_to_VDB(norm, output, img.affine)
end = datetime.now()
elapsed = end - start
print(f"Elapsed: {elapsed.seconds}s {elapsed.microseconds}µs")
