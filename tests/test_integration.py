import numpy as np
import neurovolume as nv


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


def test_pyramid():
    pyramid, built = build_pyramid()
    assert built
    output_arr = "./tests/data/vdb_out/pyramid.vdb"
    nv.ndarray_to_VDB(pyramid, output_arr)
    print("pyramid built")


# TODO: download


def test_nifti():
    print("writing bold seq...")
    bold_path = nv.nifti1_to_VDB(
        "./tests/data/sub-01_task-emotionalfaces_run-1_bold.nii",
        "./tests/data/vdb_out",
        True,
    )
    print("vdb bold seq written to ", bold_path)

    print("writing anat file...")
    anat_path = nv.nifti1_to_VDB(
        "./tests/data/sub-01_T1w.nii",
        "./tests/data/vdb_out",
        True,
    )

    print("vdb anat saved to ", anat_path)
