# INSTRUCTIONS: must be run from project root, NOT ./tests
import numpy as np
import neurovolume as nv
from urllib.request import urlretrieve
import gzip
import shutil
import os

# TODO:
# move nibabel and other testing only
# dependencies to somewhere that doesn't
# effect the rest of the project!# move nibabel and other testing only
# import nibabel as nib
import nibabel as nib  # DEPENDENCY: it's only for testing, see above todo

#
# anat_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/anat/sub-01_T1w.nii.gz?versionId=5ZTXVLawdWoVNWe5XVuV6DfF2BnmxzQz"
# bold_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/func/sub-01_task-emotionalfaces_run-1_bold.nii.gz?versionId=tq8Y3ktm31Aa8JB0991n9K0XNmHyRS1Q"
# # HACK: this whole thing is a little hacky/messy
# anat_gz = "./tests/data/sub-01_T1w.nii.gz"
anat = "./tests/data/sub-01_t1w.nii"
# bold_gz = "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii.gz"
bold = "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii"
# print("Downloading test data...")
# # TODO: check if not present?
# urlretrieve(anat_url, anat_gz)
# urlretrieve(bold_url, bold_gz)
# print("Test data downloaded")
# print("Unzipping...")
# # TODO: DRY:
# with gzip.open(anat_gz, "rb") as f_in:
#     with open(anat, "wb") as f_out:
#         shutil.copyfileobj(f_in, f_out)
# with gzip.open(bold_gz, "rb") as f_in:
#     with open(bold, "wb") as f_out:
#         shutil.copyfileobj(f_in, f_out)
#
vdb_out = "./tests/data/vdb_out"


def _get_fps(img, loud=False):
    # this should probably live in whatever
    # fMRI processing pipeline you are working on
    header = img.header
    tr = header["pixdim"][4]
    time_unit = header.get_xyzt_units()[1]

    if time_unit == "msec":
        tr /= 1000
    elif time_unit == "usec":
        tr /= 1_000_000

    fps = 1.0 / tr if tr > 0 else None
    if loud:
        print(f"time unit {time_unit}, FPS: {fps}")
    return fps
    fps = img.header["pixdim"][4]


# TODO:
# this is blocky and making it higher resolution makes it gigantic
# once we add transform, make this much MUCH larger and then scale down
# so it matches the default cube!
def _build_pyramid(size=64):
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
def test_pyramid(size=64000):
    pyramid, built = _build_pyramid()
    assert built, "Pyramid should build successfully"

    scaled = nv.scale(np.eye(4), 0.030)
    print(f"scaled affine: \n{scaled}")
    translated = nv.translate(scaled, 5, 5, 5)
    print(f"translated affine:\n{translated}")
    rotated = nv.rotate(translated, 1, 1, 1)
    print(f"rotated matrix: \n{rotated}")
    nv.ndarray_to_vdb(
        nv.prep_ndarray(pyramid, (2, 1, 0)),
        "pyramid",
        output_dir=vdb_out,
    )

    prepped_pyramid = nv.prep_ndarray(pyramid, (2, 1, 0))

    os.makedirs(vdb_out, exist_ok=True)
    nv.ndarray_to_vdb(
        prepped_pyramid,
        "new_trs_pyramid",
        output_dir=vdb_out,
        transform=rotated,
    )
    print("pyramid saved")


brain_scaler = 0.01


# def test_anat_static():
#     os.makedirs(vdb_out, exist_ok=True)
#     img = nib.load(anat)
#     data = np.array(img.get_fdata(), order="C", dtype=np.float32)
#
#     nv.ndarray_to_vdb(
#         nv.prep_ndarray(data, (0, 2, 1)),
#         "anat_test",
#         output_dir=vdb_out,
#         transform=nv.scale(img.affine, brain_scaler),
#     )
#
#
# def test_bold_seq_direct():
#     img = nib.load(bold)
#     data = np.array(img.get_fdata(), order="C", dtype=np.float32)
#
#     nv.ndarray_to_vdb(
#         nv.prep_ndarray(data, (3, 0, 2, 1)),
#         "bold_direct",
#         source_fps=_get_fps(img),
#         output_dir=vdb_out,
#         transform=nv.scale(img.affine, brain_scaler),
#     )


# def test_bold_seq_fade():
#     img = nib.load(bold)
#     data = np.array(img.get_fdata(), order="C", dtype=np.float32)
#
#     nv.ndarray_to_vdb(
#         nv.prep_ndarray(data, (3, 0, 2, 1)),
#         "bold_fade",
#         source_fps=_get_fps(img),
#         output_dir=vdb_out,
#         interpolation_flag=1,  # TODO: enum on python side with named interpolations
#     )
