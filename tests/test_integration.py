import numpy as np
import neurovolume as nv
# from datetime import datetime
# TODO: These will need to download the test files during CI

# USERSET:
# static_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
# fmri_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii"
#
# print("Python tests starting")
# start = datetime.now()
# t1_save_location = nv.nifti1_to_VDB(static_testfile, True)
# end = datetime.now()
# elapsed = end - start
# print(f" nifti1_to_VDB time Elapsed: {elapsed.seconds}s {elapsed.microseconds}µs")
#
# t1_nf = nv.num_frames(static_testfile, "NIfTI1")
# print("🐍 static VDB saved to: ", t1_save_location, " with ", t1_nf, " frames\n")
#
# fmri_save_location = nv.nifti1_to_VDB(fmri_testfile, True)
# bold_nf = nv.num_frames(fmri_testfile, "NIfTI1")
# print("🐍 bold VDB saved to: ", fmri_save_location, " with ", bold_nf, " frames\n")
#
# time_unit_type = nv.unit(fmri_testfile, "NIfTI1", "time")
# space_unit_type = nv.unit(fmri_testfile, "NIfTI1", "space")
# print("time unit: ", time_unit_type, " space unit: ", space_unit_type)
#
#
# dimension_x = nv.pixdim(fmri_testfile, "NIfTI1", 1)
# dimension_time = nv.pixdim(fmri_testfile, "NIfTI1", 4)
# print("time dim: ", dimension_time, " x dim: ", dimension_x)
#
# bold_fps = nv.source_fps(fmri_testfile, "NIfTI1")
# print("bold fps: ", bold_fps)
# static_fps = nv.source_fps(static_testfile, "NIfTI1")
# print("static fps (should be 0): ", static_fps)
#
#


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


def test_pyramid():
    pyramid, built = build_pyramid()
    assert built
    output_arr = "./output/pyramid.vdb"
    nv.ndarray_to_VDB(pyramid, output_arr)
    print("pyramid built")
