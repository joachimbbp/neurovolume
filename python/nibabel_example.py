import nibabel as nib
import neurovolume_lib as nv
import numpy as np

static_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"


def normalize_array(arr):
    return (arr - np.min(arr)) / (np.max(arr) - np.min(arr))


print("loading file with nibabel")
img = nib.load(static_testfile)
data = np.array(img.get_fdata(), order='C', dtype=np.float64)

print("affine: ", img.affine)
print(type(img.affine))
# Normalize
norm = normalize_array(data).astype(np.float64)

# Reorient from NIfTI's axis order to VDB's expected order
norm = np.transpose(norm, (1, 2, 0))
norm = np.ascontiguousarray(norm)

output = "/Users/joachimpfefferkorn/repos/neurovolume/output/from_nib.vdb"
nv.ndarray_to_VDB(norm, output, img.affine)
print(f"Successfully converted to VDB with shape {norm.shape}")
