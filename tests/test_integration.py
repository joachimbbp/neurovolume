# INSTRUCTIONS: must be run from project root, NOT ./tests
import numpy as np
from numpy._typing import _BoolLike_co
import neurovolume as nv
from neurovolume import transform as t

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


t1_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/anat/sub-01_T1w.nii.gz?versionId=5ZTXVLawdWoVNWe5XVuV6DfF2BnmxzQz"
t2_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/anat/sub-01_T2w.nii.gz?versionId=03RdL5vjveFH52_H3viGPwhXCrbRcGau"
bold_url = "https://s3.amazonaws.com/openneuro.org/ds003548/sub-01/func/sub-01_task-emotionalfaces_run-1_bold.nii.gz?versionId=tq8Y3ktm31Aa8JB0991n9K0XNmHyRS1Q"
# # HACK: this whole thing is a little hacky/messy
t1_gz = "./tests/data/sub-01_T1w.nii.gz"
t2_gz = "./tests/data/sub-01_T2w.nii.gz"
t1_nii = "./tests/data/sub-01_T1w.nii"
t2_nii = "./tests/data/sub-01_T2w.nii"
bold_gz = "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii.gz"
bold_nii = "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii"

# print("Downloading test data...")
# # TODO: check if not present?
# urlretrieve(t1_url, t1_gz)
# urlretrieve(t2_url, t2_gz)
# urlretrieve(bold_url, bold_gz)

# print("Test data downloaded")
# # print("Unzipping...")
# # TODO: DRY:
# with gzip.open(t1_gz, "rb") as f_in:
#     with open(t1_nii, "wb") as f_out:
#         shutil.copyfileobj(f_in, f_out)
# with gzip.open(t2_gz, "rb") as f_in:
#     with open(t2_nii, "wb") as f_out:
#         shutil.copyfileobj(f_in, f_out)
# with gzip.open(bold_gz, "rb") as f_in:
#     with open(bold_nii, "wb") as f_out:
#         shutil.copyfileobj(f_in, f_out)

vdb_out = Path("tests/data/vdb_out")


# def _get_fps(img, loud=False):
#     # this should probably live in whatever
#     # fMRI processing pipeline you are working on
#     header = img.header
#     tr = header["pixdim"][4]
#     time_unit = header.get_xyzt_units()[1]

#     if time_unit == "msec":
#         tr /= 1000
#     elif time_unit == "usec":
#         tr /= 1_000_000

#     fps = 1.0 / tr if tr > 0 else None
#     if loud:
#         print(f"time unit {time_unit}, FPS: {fps}")
#     return fps


# # TODO:
# # this is blocky and making it higher resolution makes it gigantic
# # once we add transform, make this much MUCH larger and then scale down
# # so it matches the default cube!
# def _build_pyramid(size=64):
#     # LLM: generated this for testing
#     """
#     Build a 3D pyramid in a numpy array.

#     Args:
#         size: Size of the cubic array (default 64x64x64)

#     Returns:
#         3D numpy array with pyramid structure (1.0 inside, 0.0 outside)
#     """
#     arr = np.zeros((size, size, size), dtype=np.float32)

#     center = size // 2

#     # Build pyramid layer by layer from bottom to top
#     for z in range(size):
#         # Calculate the radius at this height
#         # Pyramid tapers from base (bottom) to point (top)
#         height_ratio = 1.0 - (z / size)
#         max_radius = center * height_ratio

#         # Fill the square cross-section at this height
#         for y in range(size):
#             for x in range(size):
#                 # Distance from center in x and y
#                 dx = abs(x - center)
#                 dy = abs(y - center)

#                 # Check if point is inside pyramid at this height
#                 # Using Chebyshev distance (square pyramid)
#                 if max(dx, dy) <= max_radius:
#                     arr[z, y, x] = 1.0

#     print(f"Pyramid build. Arr shape: {arr.shape}")
#     return arr, True


# # LLM:
# def _build_sphere(size=64):
#     """
#     Build a 3D sphere in a numpy array.
#     Args:
#         size: Size of the cubic array (default 64x64x64)
#     Returns:
#         3D numpy array with sphere structure (1.0 inside, 0.0 outside)
#     """
#     arr = np.zeros((size, size, size), dtype=np.float32)
#     center = size // 2
#     radius = center

#     # Use numpy broadcasting for efficiency instead of triple nested loop
#     z, y, x = np.ogrid[:size, :size, :size]
#     dist_sq = (x - center) ** 2 + (y - center) ** 2 + (z - center) ** 2
#     arr[dist_sq <= radius**2] = 1.0

#     print(f"Sphere built. Arr shape: {arr.shape}")
#     return arr, True


# def test_hello():
#     nv.hello()


def _get_nii_data(nii_path: str):
    """
    returns nii data prepared for neurovolume
    returns: array, img, affine
    """
    # LSP complains heavily!
    # TODO: have your test data as saved out npy arrays
    # or wait unitl zig-native .nii parsing
    os.makedirs(vdb_out, exist_ok=True)
    img = nib.load(nii_path)
    # some lsp issues with nibabel it seems
    data = np.array(img.get_fdata(), order="C", dtype=np.float32)
    # more lsp gore

    # if data.ndim == 3:
    #     arr = nv.prep_ndarray(data, (0, 2, 1))
    # if data.ndim == 4:
    #     # WARN: I am not entirely sure about this!
    #     # might be (3, 0, 1, 2) iirc
    #     arr = nv.prep_ndarray(data, (0, 1, 2, 3))

    print(f"{nii_path}\n  {data.shape=}  {img.affine=}")
    return data, img, img.affine


# # Using np.index_exp for dynamic slicing
# # CLAUDE WROTE:
# def get_3d_slice(arr, axis, index):
#     idx = [slice(None)] * arr.ndim
#     idx[axis] = index
#     return arr[tuple(idx)]


# def test_mri():
#     print("mri tests...")
#     t1_arr, t1_img, _ = _get_nii_data(t1_nii)
#     t2_arr, t2_img, _ = _get_nii_data(t2_nii)

#     # ORDER MATTERS! probably bake that into a function
#     # CLAUDE FIX:
#     t2_transformed = t.from_blender(
#         translate_x=-141.62,
#         translate_y=-96.52,
#         translate_z=-88.623,
#         rotate_x=0,
#         rotate_y=2.1012,
#         rotate_z=0,
#         scale_x=0.514,
#         scale_y=4.087,
#         scale_z=0.535,
#     )
#     # translated = t.translate(id, x=-141.62, y=-96.52, z=-88.623)
#     # rotated = t.rotate(translated, x=0, y=2.1012, z=0)
#     # t2_transformed = t.scale(rotated, x=0.514, y=4.087, z=0.535)

#     # bold_arr, bold_img = _get_nii_data(bold_nii)
#     # bold_slice = get_3d_slice(bold_arr, transform=bold_img.affine)
#     # TODO: BOLD! but that requires a big sequence refactor!

#     # this works BUT the t2 affine is faulty (source data issue!)
#     print("setting grids...")
#     grids = [
#         nv.Grid("t1", t1_arr, transform=t1_img.affine),
#         # nv.Grid("bold_slice", bold_slice, transform=bold_img.affine),
#         nv.Grid("t2", t2_arr, transform=t2_transformed),  # source issues with affine!
#     ]

#     save_config = nv.SaveConfig("mri_t1_t2_v3", folder=vdb_out)
#     print("setting volume...")
#     vol = nv.Volume(
#         grids,
#         save_config=save_config,
#     )
#     vol.write()
#     # TODO you REALLY need to have the save config go in write, it's so weird otherwise!


# def test_multi_grid():
#     print("multigrid testing with sphere and pyramid...")
#     sphere_arr = _build_sphere(30)[0]
#     pyramid_arr = _build_pyramid()[0]

#     grids = [nv.Grid("sphere", sphere_arr), nv.Grid("pyramid", pyramid_arr)]

#     # CLEAN: maybe save_config can be rolled better into volume tbh
#     save_config = nv.SaveConfig("shapes_mismatch", folder=vdb_out)

#     vol = nv.Volume(grids, save_config)

#     vol.write()


# def test_static():
#     bold_arr, bold_img, bold_affine = _get_nii_data(bold_nii)
#     t1_arr, _, t1_affine = _get_nii_data(t1_nii)

#     # print("setting a bold channel..")
#     # TODO: try with fade (but that is very heavy!!!!)
#     bold = nv.Grid(
#         "bold",
#         nv.prep_ndarray(bold_arr)[1],
#         # obvs will mis-align but Im just trying to dial in the prune
#         # transform=bold_affine,
#         prune=np.float32(0.1),
#     )
#     print("setting t1 channel")
#     t1 = nv.Grid(
#         "t1",
#         nv.prep_ndarray(t1_arr),
#         transform=t1_affine,
#         prune=np.float32(0.1),
#     )
#     # 0.1 is more or less good
#     save_config = nv.SaveConfig("combined_0p1", folder=vdb_out)

#     vol = nv.Volume([t1, bold], save_config)

#     vol.write()


def frame_diff(arr):
    out = np.zeros_like(arr)
    out[1:] = np.diff(arr, axis=0)
    return out  # MULTI-CHANNEL VOLUME SEQUENCES


def sub(arr):
    # scientifically nonsense
    # obviously you want to preserve the sub zero
    # values and color them as blue or something
    # idk what exactly but THEY ARE IMPORTANT
    out = np.zeros_like(arr)
    out[1:] = arr[1:] - arr[:-1]
    return out  # MULTI-CHANNEL VOLUME SEQUENCES


def test_sequence():
    bold_arr, bold_img, bold_affine = _get_nii_data(bold_nii)
    t1_arr, _, t1_affine = _get_nii_data(t1_nii)

    print("setting a bold channel..")
    # TODO: try with fade (but that is very heavy!!!!)
    bold_diff = nv.Channel(
        "bold",
        sub(nv.prep_ndarray(bold_arr)),
        transform=bold_affine,
        # prune=np.float32(0.1),
        # interpolation=nv.modes.Interpolation.fade,
    )
    print("setting t1 channel")
    t1 = nv.Channel(
        "t1",
        nv.prep_ndarray(t1_arr),
        transform=t1_affine,
        num_frames=bold_diff.num_frames,
        interpolation=nv.modes.Interpolation.frozen,
        prune=np.float32(0.1),
    )

    print("setting save config...")
    save_config = nv.SaveConfig("fmri_bold_sub", folder=vdb_out / "fmri_seq")
    print("Setting fmri sequence...")
    fmri = nv.Sequence([bold_diff, t1], save_config)
    print("writing fmri VDB...")
    fmri.write()


#     print("done!")
