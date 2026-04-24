# this is mostly the zig/c/python translation layer
# all pretty unruley and should be automatically
# generated in the future!
# For now, most of this is LLM generated

import ctypes as c
import numpy as np  # DEPENDENCY:, the only one we should have!
import sys
import ctypes
from pathlib import Path


# LLM:
def _get_library_name():
    if sys.platform == "darwin":
        return "libneurovolume.dylib"
    elif sys.platform == "win32":
        return "libneurovolume.dll"
    else:  # Linux and others
        return "libneurovolume.so"


lib_path = Path(__file__).parent / "_native" / _get_library_name()
lib = ctypes.CDLL(str(lib_path))


nv = c.cdll.LoadLibrary(str(lib_path))  # Neurovolume library


# LLMEND:
def _hello():
    """Prints 'hello neurovolume' from the c_root.zig"""
    nv.hello()


# _: Main code:
def _get_basename(path):
    hierarchy = path.split("/")
    return hierarchy[-1].split(".")[0]


def _get_folder(path):
    """Returns the folder in which the path points to"""
    hiearchy = path.split("/")
    return "/".join(hiearchy[:-1])


def _b(string):
    """
    Returns the utf-u8 encoded bytes literal of the string
    Equivalent to 'b"inputstring"'
    """
    return string.encode("utf-8")

# C_INTEROP:

# LLM: claude wrote this function
def _init_grid(
    name: str,
    transform: np.ndarray,
    dims: tuple,
    prune: np.float32 | None,
    normalize: bool = False,
    source_format: int = 0,  # 0=ndarray (mirrors volume.zig SourceFormat)
    cartesian_order: tuple = (0, 1, 2),
) -> c.c_void_p:
    """
    Initializes a volume.Grid on the Zig heap and returns an opaque pointer.

    Note: this does NOT populate the grid. Call _populate_grid() next.

    Parameters:
    ------------
    name: str
        Identifier for this grid (becomes the VDB grid name).
    transform: np.ndarray
        4x4 affine as float64.
    dims: tuple
        (x, y, z) voxel dimensions.
    prune:
        Tolerance for sparsification. None disables pruning.
    normalize: bool
        Whether to normalize on the Zig side. For ndarray source_format this
        must be False — use prep_ndarray in Python instead.
    source_format: int
        0 = ndarray (mirrors volume.zig SourceFormat enum)
    cartesian_order: tuple
        Axis remap, usually (0, 1, 2).

    Returns:
    ------------
    Opaque ctypes pointer to the Grid on the Zig heap.
    Must be freed by calling _deinit_grid().
    """
    transform_arr = (c.c_double * 16)(
        *np.ascontiguousarray(transform.flatten(), dtype=np.float64)
    )
    dims_arr = (c.c_size_t * 3)(*dims)
    cartesian_arr = (c.c_size_t * 3)(*cartesian_order)
    prune_ptr = (c.c_float * 1)(prune) if prune is not None else None

    nv.initGrid.argtypes = [
        c.c_char_p,             # name
        c.c_int,                # source_format
        c.POINTER(c.c_size_t),  # cartesian_order [3]usize
        c.POINTER(c.c_double),  # transform_flat [16]f64
        c.c_bool,               # normalize
        c.POINTER(c.c_size_t),  # dims [3]usize
        c.POINTER(c.c_float),   # prune ?f32, null = no pruning
    ]
    nv.initGrid.restype = c.c_void_p

    ptr = nv.initGrid(
        _b(name),
        source_format,
        cartesian_arr,
        transform_arr,
        normalize,
        dims_arr,
        prune_ptr,
    )
    if ptr is None:
        raise RuntimeError("initGrid returned null — allocation or init failed")
    return ptr


# LLM: claude wrote this function
def _populate_grid(
    grid_ptr: c.c_void_p,
    data: np.ndarray,
) -> None:
    """
    Populates a Grid's VDB with voxel data.

    Parameters:
    ------------
    grid_ptr: c.c_void_p
        Pointer from _init_grid().
    data: np.ndarray
        Flattened voxel data, length must equal dims[0]*dims[1]*dims[2].
        C-contiguous float32.
    """
    data = np.ascontiguousarray(data, dtype=np.float32)

    nv.populateGrid.argtypes = [
        c.c_void_p,             # grid ptr
        c.POINTER(c.c_float),   # data
    ]
    nv.populateGrid.restype = c.c_size_t

    code = nv.populateGrid(
        grid_ptr,
        data.ctypes.data_as(c.POINTER(c.c_float)),
    )
    if code != 0:
        raise RuntimeError(f"populateGrid failed with error code {code}")


# LLM: claude wrote this function
def _deinit_grid(grid_ptr: c.c_void_p) -> None:
    """
    Frees a Grid previously returned by _init_grid().

    IMPORTANT: any Vol that references this grid must be saved and deinitialized
    first — the Vol holds pointers back into the Grid's heap-allocated VDB.
    """
    nv.deinitGrid.argtypes = [c.c_void_p]
    nv.deinitGrid.restype = None
    nv.deinitGrid(grid_ptr)


# LLM: claude wrote this function
def _init_vol(
    basename: str,
    save_folder: Path,
    overwrite: bool,
    grid_ptrs: list[c.c_void_p],
) -> c.c_void_p:
    """
    Initializes a volume.Vol on the Zig heap from a list of already-populated Grid
    pointers and returns an opaque pointer.

    Parameters:
    ------------
    basename: str
        Output filename (without extension).
    save_folder: Path
        Folder to write the .vdb file into.
    overwrite: bool
        If False, saves with a version suffix instead of clobbering.
    grid_ptrs: list[c.c_void_p]
        Pointers from _init_grid() + _populate_grid(). Must outlive the Vol.

    Returns:
    ------------
    Opaque ctypes pointer to the Vol on the Zig heap.
    Must be freed by calling _deinit_vol().
    """
    grid_count = len(grid_ptrs)
    grids_arr = (c.c_void_p * grid_count)(*grid_ptrs)

    nv.initVol.argtypes = [
        c.c_char_p,             # basename
        c.c_char_p,             # save_folder
        c.c_bool,               # overwrite
        c.POINTER(c.c_void_p),  # grid_ptrs
        c.c_size_t,             # grid_count
    ]
    nv.initVol.restype = c.c_void_p

    ptr = nv.initVol(
        _b(basename),
        _b(str(save_folder)),
        overwrite,
        grids_arr,
        grid_count,
    )
    if ptr is None:
        raise RuntimeError("initVol returned null — allocation or init failed")
    return ptr


# LLM: claude wrote this function
def _save_vol(vol_ptr: c.c_void_p) -> None:
    """
    Writes the Vol's grids to disk as a .vdb file, using the basename/folder
    supplied at _init_vol() time.
    """
    nv.saveVol.argtypes = [c.c_void_p]
    nv.saveVol.restype = c.c_size_t

    code = nv.saveVol(vol_ptr)
    if code != 0:
        raise RuntimeError(f"saveVol failed with error code {code}")


# LLM: claude wrote this function
def _deinit_vol(vol_ptr: c.c_void_p) -> None:
    """
    Frees a Vol previously returned by _init_vol().

    Does NOT free the underlying Grid pointers — those must be freed
    separately with _deinit_grid() after this call returns.
    """
    nv.deinitVol.argtypes = [c.c_void_p]
    nv.deinitVol.restype = None
    nv.deinitVol(vol_ptr)
