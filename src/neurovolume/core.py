from . import _internal

import os
import numpy as np  # DEPENDENCY: really the only one we should have!
from pathlib import Path


def hello():
    """Prints 'hello neurovolume' from the c_root.zig"""
    _internal._hello()


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

    # completes 0-1 f32 normalization
    if max_val > 0:
        arr = arr / max_val
    return arr


def grid(
    name: str,
    data: np.ndarray,
    transform: np.ndarray = np.eye(4),
    prune: np.float32 | None = 4 * np.finfo(np.float32).eps,
    normalize: bool = False,
    source_format: str = "ndarray",
    cartesian_order: tuple = (0, 1, 2),
):
    """
    Parameters:
    ------------
    name:
        The name of the grid
    data: np.ndarray
        The data to put in the grid!
        Don't forget to prepare it using prep_ndarray!
        right now this should probably be f32!
    transform: np.ndarray
        The affine transform matrix to apply to this grid to move it around. .nii files often include these
        for alignment. Otherwise, check out the `transform` module for some sane abstractions (rotation,
        translation, etc)
    prune: np.float32
        The higher this is, the more sparse the volume becomes. At some point it begins to degrade the volume
        Balance between disk space usage and fidelity as per your use case.
        Robbie has set this to a very specific, small default for some math reasons that, frankly, elude
        me at this time (perhaps he will write a blog post!)
    normalize: bool
        WARNING:
        Not used at the moment! Keeping it around as it might be needed in VDB sequences, normally you should
        normalize before yeeting your arrays into the grids (prep_ndarray does normalize for you)
    source_format: str (although it should be an enum or something later)
        ndarray is the only option here! Similar story as normalize.
    cartesian_order:
        The order in which the dimensions are laid out. prep_ndarray makes it so (0,1,2) works just fine,
        but if you want to do something weird, this is here for you.
        Note to self and those curious, iirc 4D time series sequences are (3,0,1,2)

    """
    dims = data.shape
    if data.ndim != 3:
        # for vdbs with arbitrarily high (or low) dimensions... submit a PR you maniac!
        # (it is possible according to the paper fyi)
        # just think of the posibilities: n-dimensional physarum simulations!
        # higher dimensional slime!
        raise ValueError(f"Grids must be 3D! {data.ndim}D grids not supported")
    if source_format == "ndarray":
        source_format_int = 0
    else:
        raise ValueError(
            f"{source_format} not supported yet. Presently only numpy arrays are supported!"
        )

    g = _internal._init_grid(
        name,
        transform,
        dims,
        prune,
        normalize,
        source_format_int,
        cartesian_order,
    )
    _internal._populate_grid(g, data)

    # BUG:
    # so this is problematic because the user has to call
    # deinit grid which... I mean this is a Python library
    # we can't have manual memory management here!
    # IDEA:
    # perhaps this just creates an object with all the data needed to make a grid
    # and then you feed that into the "volume creator" which:
    # generates the grids,
    # adds them to a volume
    # saves them out
    #  and then deinits everything
    # I think that's a good idea!

    # BOOKMARK:


# def ndarray_to_vdb(
#     arr: np.ndarray,  # dont for get to prep this!
#     basename: str,
#     source_fps=1,  # static default
#     output_dir:Path=Path("../../output/"),
#     overwrite=True,  # presently the only option
#     transform=np.eye(4),
#     playback_fps=24.0,
#     speed=1.0,
#     interpolation_flag=0,  # default to direct, chose 1 for cross
#     # Robbie's reccomended default prune amount
#     # very specfici but it works quite well
#     # translated from zig to Python with Claude
#     prune: np.float32 | None = 4 * np.finfo(np.float32).eps,
# ) -> Path:
#     """
#     returns path to VDB
#     if VDB sequence, returns path to folder
#     """
#     dims = arr.shape
#     if arr.ndim == 3:
#         vol = _init_three_dim(
#             basename=basename,
#             save_folder=output_dir,
#             overwrite=True,
#             data=arr,
#             transform=transform,  # 4x4 affine float64
#             dims=dims,  # (x, y, z)
#             prune = prune,
#         )
#         _save_three_dim(vol)
#         _deinit_three_dim(vol)
#         # kinda hacky tbh
#         # this happens way down on the zig level and it would be
#         # cooler to have the path percolate back up
#         return output_dir / f"{basename}.vdb"

#     elif arr.ndim == 4:
#         seq_out = output_dir / basename
#         os.makedirs(seq_out, exist_ok=True)
#         vol = _init_four_dim(
#             basename=basename,
#             save_folder=seq_out,
#             overwrite=True,
#             data=arr,
#             transform=transform,
#             source_fps=source_fps,
#             playback_fps=playback_fps,
#             speed=speed,
#             dims=dims,
#             prune=prune,

#         )
#         _save_four_dim(vol, interpolation_flag)
#         _deinit_four_dim(vol)
#         # should return the folder containing the seq
#         # see above comment at end of .ndim == 3
#         return Path(f"{output_dir}/{basename}")
#     else:
#         raise ValueError(f"{arr.ndim}D not supported")
