import numpy as np
import neurovolume as nv
from urllib.request import urlretrieve
import gzip
import shutil
import os

# INSTRUCTIONS: must be run from project root, NOT ./tests

anat_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/anat/sub-01_T1w.nii.gz?versionId=5ZTXVLawdWoVNWe5XVuV6DfF2BnmxzQz"
bold_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/func/sub-01_task-emotionalfaces_run-1_bold.nii.gz?versionId=tq8Y3ktm31Aa8JB0991n9K0XNmHyRS1Q"
# HACK: this whole thing is a little hacky/messy
anat_gz = "./tests/data/sub-01_T1w.nii.gz"
anat = "./tests/data/sub-01_t1w.nii"
bold_gz = "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii.gz"
bold = "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii"
print("Downloading test data...")
# TODO: check if not present?
urlretrieve(anat_url, anat_gz)
urlretrieve(bold_url, bold_gz)
print("Test data downloaded")
print("Unzipping...")
# TODO: DRY:
with gzip.open(anat_gz, "rb") as f_in:
    with open(anat, "wb") as f_out:
        shutil.copyfileobj(f_in, f_out)
with gzip.open(bold_gz, "rb") as f_in:
    with open(bold, "wb") as f_out:
        shutil.copyfileobj(f_in, f_out)

vdb_out = "./tests/data/vdb_out"


# TODO:
# this is blocky and making it higher resolution makes it gigantic
# once we add transform, make this much MUCH larger and then scale down
# so it matches the default cube!
def build_pyramid(size=64):
    # LLM: generated this for testing
    """
    Build a 3D pyramid in a numpy array.

    Args:
        size: Size of the cubic array (default 64x64x64)

    Returns:
        3D numpy array with pyramid structure (1.0 inside, 0.0 outside)
    """
    arr = np.zeros((size, size, size), dtype=np.float32)

    center = size // 2

    # Build pyramid layer by layer from bottom to top
    for z in range(size):
        # Calculate the radius at this height
        # Pyramid tapers from base (bottom) to point (top)
        height_ratio = 1.0 - (z / size)
        max_radius = center * height_ratio

        # Fill the square cross-section at this height
        for y in range(size):
            for x in range(size):
                # Distance from center in x and y
                dx = abs(x - center)
                dy = abs(y - center)

                # Check if point is inside pyramid at this height
                # Using Chebyshev distance (square pyramid)
                if max(dx, dy) <= max_radius:
                    arr[z, y, x] = 1.0

    print("Pyramid build")
    return arr, True


def test_hello():
    nv.hello()


# TODO: Better testing! This is very incomplete as of now


# TODO: rewrite this with the new functionality
def test_pyramid():
    pyramid, built = build_pyramid()
    assert built, "Pyramid should build successfully"
    nv.ndarray_to_vdb(
        nv.prep_ndarray(pyramid, (2, 1, 0)),
        "pyramid",
        output_dir=vdb_out,
    )

    prepped_pyramid = nv.prep_ndarray(pyramid, (2, 1, 0))

    os.makedirs(vdb_out, exist_ok=True)
    # LLM: was init_four_dim (wrong API — FourDim* passed to save_three_dim caused Zig panic)
    vol = nv.init_three_dim(
        base_name="pyramid",
        save_folder=vdb_out,
        overwrite=True,  # presently the only option
        data=prepped_pyramid,
        transform=np.eye(4),
        dims=prepped_pyramid.shape,
    )
    nv.save_three_dim(vol)
    nv.deinit_three_dim(vol)

    print("pyramid saved")


#

# TODO:
# move nibabel and other testing only
# dependencies to somewhere that doesn't
# effect the rest of the project!# move nibabel and other testing only
# import nibabel as nib

import nibabel as nib


def test_anat_static():
    os.makedirs(vdb_out, exist_ok=True)
    img = nib.load(anat)
    data = np.array(img.get_fdata(), order="C", dtype=np.float32)

    nv.ndarray_to_vdb(
        nv.prep_ndarray(data, (0, 2, 1)),
        "bold_direct",
        output_dir=vdb_out,
    )


def test_bold_seq_direct():
    img = nib.load(bold)
    data = np.array(img.get_fdata(), order="C", dtype=np.float32)
    source_fps = nv.get_fps(img, loud=True)

    nv.ndarray_to_vdb(
        nv.prep_ndarray(data, (3, 0, 2, 1)),
        "bold_direct",
        source_fps=source_fps,
        output_dir=vdb_out,
    )
