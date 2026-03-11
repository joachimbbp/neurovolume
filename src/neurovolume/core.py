from neurovolume._internal import (
    _hello,
    _init_three_dim,
    _save_three_dim,
    _deinit_three_dim,
    _init_four_dim,
    _save_four_dim,
    _deinit_four_dim,
)
import os
import numpy as np  # DEPENDENCY: really the only one we should have!


def hello():
    """Prints 'hello neurovolume' from the c_root.zig"""
    _hello()


def prep_ndarray(
    arr: np.ndarray,
    transpose: tuple,
) -> np.ndarray:
    """
    Returns an ndarray that is useable by neurovolume
    """
    # order matters here:
    arr = np.transpose(arr, transpose)
    arr = np.array(arr, order="C", dtype=np.float32)

    max_val = arr.max()

    # LLM: had this in the test suite
    # completes 0-1 f32 normalization
    if max_val > 0:
        arr = arr / max_val
    return arr


def ndarray_to_vdb(
    arr: np.ndarray,  # dont for get to prep this!
    basename: str,
    source_fps=1,  # static default
    output_dir="../../output/",
    overwrite=True,  # presently the only option
    transform=np.eye(4),
    playback_fps=24.0,
    speed=1.0,
    interpolation_flag=0,  # default to direct, chose 1 for cross
):

    # LLM: claude fixed some bugs in this func
    if arr.ndim == 3:
        print("3D array")

        dims = arr.shape

        vol = _init_three_dim(
            base_name=basename,
            save_folder=output_dir,
            overwrite=True,
            data=arr,
            transform=transform,  # 4x4 affine float64
            dims=dims,  # (x, y, z)
        )
        _save_three_dim(vol)
        _deinit_three_dim(vol)

    elif arr.ndim == 4:
        print("4D array")

        dims = arr.shape  # (x, z, y, t) after transpose

        seq_out = os.path.join(output_dir, basename)
        os.makedirs(seq_out, exist_ok=True)
        vol = _init_four_dim(
            base_name=basename,
            save_folder=seq_out,
            overwrite=True,
            data=arr,
            transform=transform,
            source_fps=source_fps,
            playback_fps=playback_fps,
            speed=speed,
            dims=dims,
        )
        _save_four_dim(vol, interpolation_flag)
        _deinit_four_dim(vol)
    else:
        print(f"{arr.ndim}D not supported")
        return
