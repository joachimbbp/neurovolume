# INSTRUCTIONS: must be run from project root, NOT ./tests
import numpy as np
import neurovolume as nv
from urllib.request import urlretrieve
import gzip
import shutil
from pathlib import Path
import os

# TODO:
# move nibabel and other testing only
# dependencies to somewhere that doesn't
# effect the rest of the project!# move nibabel and other testing only
# import nibabel as nib
import nibabel as nib  # DEPENDENCY: it's only for testing, see above todo


anat_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/anat/sub-01_T1w.nii.gz?versionId=5ZTXVLawdWoVNWe5XVuV6DfF2BnmxzQz"
bold_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/func/sub-01_task-emotionalfaces_run-1_bold.nii.gz?versionId=tq8Y3ktm31Aa8JB0991n9K0XNmHyRS1Q"
# # HACK: this whole thing is a little hacky/messy
anat_gz = "./tests/data/sub-01_T1w.nii.gz"
anat = "./tests/data/sub-01_t1w.nii"
bold_gz = "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii.gz"
bold = "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii"
# print("Downloading test data...")
# TODO: check if not present?
# urlretrieve(anat_url, anat_gz)
# urlretrieve(bold_url, bold_gz)
# print("Test data downloaded")
# print("Unzipping...")
# TODO: DRY:
# with gzip.open(anat_gz, "rb") as f_in:
#     with open(anat, "wb") as f_out:
#         shutil.copyfileobj(f_in, f_out)
# with gzip.open(bold_gz, "rb") as f_in:
#     with open(bold, "wb") as f_out:
#         shutil.copyfileobj(f_in, f_out)

vdb_out = Path("tests/data/vdb_out")


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

    print(f"Pyramid build. Arr shape: {arr.shape}")
    return arr, True


# LLM:
def _build_sphere(size=64):
    """
    Build a 3D sphere in a numpy array.
    Args:
        size: Size of the cubic array (default 64x64x64)
    Returns:
        3D numpy array with sphere structure (1.0 inside, 0.0 outside)
    """
    arr = np.zeros((size, size, size), dtype=np.float32)
    center = size // 2
    radius = center

    # Use numpy broadcasting for efficiency instead of triple nested loop
    z, y, x = np.ogrid[:size, :size, :size]
    dist_sq = (x - center) ** 2 + (y - center) ** 2 + (z - center) ** 2
    arr[dist_sq <= radius**2] = 1.0

    print(f"Sphere built. Arr shape: {arr.shape}")
    return arr, True


def test_hello():
    nv.hello()


def test_multi_grid():
    print("multigrid testing with sphere and pyramid!")
    sphere_arr = _build_sphere()[0]
    pyramid_arr = _build_pyramid()[0]

    grids = [nv.Grid("sphere", sphere_arr), nv.Grid("pyramid", pyramid_arr)]

    # CLEAN: maybe save_config can be rolled better into volume tbh
    save_config = nv.SaveConfig("shapes", folder=vdb_out)

    vol = nv.Volume(grids, save_config)

    vol.write()


# TODO: Better testing! This is very incomplete as of now


# DEPRECATED: we're using grids now!
# TODO: rewrite this with the new functionality
# def test_pyramid(size=64000):
#     pyramid, built = _build_pyramid()
#     assert built, "Pyramid should build successfully"

#     identity = np.eye(4)
#     # perhaps this pattern isn't the best?
#     print(f"identity matrix: \n{identity}")
#     scaled = nv.transform.scale(identity, 0.030)
#     print(f"scaled affine: \n{scaled}")
#     translated = nv.transform.translate(scaled, 1.6, 0.7, 0.2)
#     print(f"translated affine:\n{translated}")
#     rotated = nv.transform.rotate(translated, 0, 0, np.deg2rad(44))
#     print(f"rotated matrix: \n{rotated}")

#     prepped_pyramid = nv.prep_ndarray(pyramid, (2, 1, 0))

#     os.makedirs(vdb_out, exist_ok=True)
#     print(
#         "saved to: ",
#         nv.ndarray_to_vdb(
#             prepped_pyramid,
#             "pyramid_offset_default_prune",
#             output_dir=vdb_out,
#             transform=rotated,
#         ),
#     )
#     print(
#         "saved to: ",
#         nv.ndarray_to_vdb(
#             prepped_pyramid,
#             "pyramid_offset_no_prune",
#             output_dir=vdb_out,
#             transform=rotated,
#             prune=None,
#         ),
#     )
#     print("pyramids saved")


# def _test_pattern_pos(affine: np.ndarray) -> np.ndarray:
#     brain_scale = 0.01
#     brain_y_move = -2.38251
#     scaled = nv.scale(affine, brain_scale)
#     moved = nv.translate(scaled, 0, brain_y_move, 0)
#     return moved


# def test_anat_static_no_prune():
#     os.makedirs(vdb_out, exist_ok=True)
#     img = nib.load(anat)
#     data = np.array(img.get_fdata(), order="C", dtype=np.float32)

#     print(
#         "saved to: ",
#         nv.ndarray_to_vdb(
#             nv.prep_ndarray(data, (0, 2, 1)),
#             "anat_offset_no_prune",
#             output_dir=vdb_out,
#             transform=_test_pattern_pos(img.affine),
#             prune=None,
#         ),
#     )

#     print(
#         "saved to: ",
#         nv.ndarray_to_vdb(
#             nv.prep_ndarray(data, (0, 2, 1)),
#             "anat_offset_0p05_prune",
#             output_dir=vdb_out,
#             transform=_test_pattern_pos(img.affine),
#             prune=np.float32(0.05),
#         ),
#     )


# def test_bold_seq_direct():
#     img = nib.load(bold)
#     data = np.array(img.get_fdata(), order="C", dtype=np.float32)

#     print(
#         "saved to: ",
#         nv.ndarray_to_vdb(
#             nv.prep_ndarray(data, (3, 0, 2, 1)),
#             "bold_direct_offset",
#             source_fps=_get_fps(img),
#             output_dir=vdb_out,
#             transform=_test_pattern_pos(img.affine),
#         ),
#     )
#     print(
#         "saved to: ",
#         nv.ndarray_to_vdb(
#             nv.prep_ndarray(data, (3, 0, 2, 1)),
#             "bold_direct_offset_0p05_prune",
#             source_fps=_get_fps(img),
#             output_dir=vdb_out,
#             transform=_test_pattern_pos(img.affine),
#             prune=np.float32(0.05),
#         ),
#     )


# #
# #
# # # def test_bold_seq_fade():
# # #     img = nib.load(bold)
# # #     data = np.array(img.get_fdata(), order="C", dtype=np.float32)
# # #
# # #     nv.ndarray_to_vdb(
# # #         nv.prep_ndarray(data, (3, 0, 2, 1)),
# # #         "bold_fade",
# # #         source_fps=_get_fps(img),
# # #         output_dir=vdb_out,
# # #         interpolation_flag=1,  # TODO: enum on python side with named interpolations
# # #     )
