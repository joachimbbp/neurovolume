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


# ============================================================================
# C INTEROP VOLUMES:
# ============================================================================


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
        c.c_char_p,  # name
        c.c_int,  # source_format
        c.POINTER(c.c_size_t),  # cartesian_order [3]usize
        c.POINTER(c.c_double),  # transform_flat [16]f64
        c.c_bool,  # normalize
        c.POINTER(c.c_size_t),  # dims [3]usize
        c.POINTER(c.c_float),  # prune ?f32, null = no pruning
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
        c.c_void_p,  # grid ptr
        c.POINTER(c.c_float),  # data
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
        c.c_char_p,  # basename
        c.c_char_p,  # save_folder
        c.c_bool,  # overwrite
        c.POINTER(c.c_void_p),  # grid_ptrs
        c.c_size_t,  # grid_count
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


# ============================================================================
# C INTEROP SEQUENCES:
# ============================================================================


# LLM: claude wrote this function
def _init_channel(
    name: str,
    data: np.ndarray,
    transform: np.ndarray,
    dims: tuple,
    num_frames: int,
    prune: np.float32 | None,
    source_format: int = 0,  # 0=ndarray (mirrors volume.zig SourceFormat)
    frame_cartesian_order: tuple = (0, 1, 2),
) -> tuple[c.c_void_p, bytes, np.ndarray]:
    """
    Initializes a sequence.Channel on the Zig heap and returns an opaque pointer.

    BORROWING SEMANTICS: the Zig Channel does NOT copy `name` or `data` — it
    holds pointers into Python-owned memory. The caller MUST keep the returned
    `name_bytes` and `data_contig` alive for as long as the Channel pointer is
    in use. The Python Channel class wraps these as instance attributes to
    enforce this via reference counting.

    Parameters:
    ------------
    name: str
        Identifier for this channel (becomes the VDB grid name on each frame).
    data: np.ndarray
        4D voxel data, will be made C-contiguous float32. Shape (T, X, Y, Z),
        flattened length must equal dims[0]*dims[1]*dims[2]*dims[3].
    transform: np.ndarray
        4x4 affine as float64.
    dims: tuple
        (T, X, Y, Z) dimensions.
    num_frames: int
        Number of frames in the sequence (typically dims[0]).
    prune:
        Tolerance for sparsification. None disables pruning.
    source_format: int
        0 = ndarray (mirrors volume.zig SourceFormat enum)
    frame_cartesian_order: tuple
        Per-frame axis remap, usually (0, 1, 2).

    Returns:
    ------------
    (channel_ptr, name_bytes, data_contig)
        - channel_ptr: opaque ctypes pointer to the Channel on the Zig heap.
          Must be freed by calling _deinit_channel().
        - name_bytes: utf-8 encoded name. MUST be held alive by the caller.
        - data_contig: C-contiguous float32 view of `data`. MUST be held alive
          by the caller (may be the same object as `data` or a fresh copy).
    """
    # Make data C-contiguous float32; keep a reference to return to caller
    data_contig = np.ascontiguousarray(data, dtype=np.float32)
    # Encode the name once, hand the same bytes object back to the caller
    name_bytes = _b(name)

    transform_arr = (c.c_double * 16)(
        *np.ascontiguousarray(transform.flatten(), dtype=np.float64)
    )
    dims_arr = (c.c_size_t * 4)(*dims)
    cartesian_arr = (c.c_size_t * 3)(*frame_cartesian_order)
    prune_ptr = (c.c_float * 1)(prune) if prune is not None else None

    nv.initChannel.argtypes = [
        c.c_char_p,  # name
        c.POINTER(c.c_float),  # data
        c.POINTER(c.c_size_t),  # frame_cartesian_order [3]usize
        c.c_int,  # source_format
        c.POINTER(c.c_double),  # transform_flat [16]f64
        c.POINTER(c.c_size_t),  # dims [4]usize
        c.POINTER(c.c_float),  # prune ?f32, null = no pruning
        c.c_size_t,  # num_frames
    ]
    nv.initChannel.restype = c.c_void_p

    ptr = nv.initChannel(
        name_bytes,
        data_contig.ctypes.data_as(c.POINTER(c.c_float)),
        cartesian_arr,
        source_format,
        transform_arr,
        dims_arr,
        prune_ptr,
        num_frames,
    )
    if ptr is None:
        raise RuntimeError("initChannel returned null — allocation or init failed")
    return ptr, name_bytes, data_contig


# LLM: claude wrote this function
def _deinit_channel(channel_ptr: c.c_void_p) -> None:
    """
    Frees a Channel previously returned by _init_channel().

    Does NOT free the underlying name/data — those are Python-owned and will
    be cleaned up by Python's GC once the Python Channel wrapper drops its
    references.

    IMPORTANT: any Sequence that references this channel must be saved and
    deinitialized first.
    """
    nv.deinitChannel.argtypes = [c.c_void_p]
    nv.deinitChannel.restype = None
    nv.deinitChannel(channel_ptr)


# LLM: claude wrote this function
def _init_sequence(
    basename: str,
    save_folder: Path,
    overwrite: bool,
    channel_ptrs: list[c.c_void_p],
) -> tuple[c.c_void_p, bytes, bytes]:
    """
    Initializes a sequence.Sequence on the Zig heap from a list of Channel
    pointers and returns an opaque pointer.

    BORROWING SEMANTICS: the Zig Sequence does NOT copy `basename` or
    `save_folder` — it holds pointers into Python-owned memory. The caller
    MUST keep the returned bytes objects alive for as long as the Sequence
    pointer is in use. The referenced Channel objects must also outlive the
    Sequence; the Python Sequence wrapper enforces this by holding refs to
    the Python Channel objects.

    Parameters:
    ------------
    basename: str
        Output filename prefix (without extension).
    save_folder: Path
        Folder to write the per-frame .vdb files into.
    overwrite: bool
        If False, saves with a version suffix instead of clobbering.
    channel_ptrs: list[c.c_void_p]
        Pointers from _init_channel(). Must outlive the Sequence.

    Returns:
    ------------
    (sequence_ptr, basename_bytes, folder_bytes)
        - sequence_ptr: opaque ctypes pointer. Must be freed by _deinit_sequence().
        - basename_bytes, folder_bytes: utf-8 encoded strings. MUST be held alive
          by the caller.
    """
    basename_bytes = _b(basename)
    folder_bytes = _b(str(save_folder))

    channel_count = len(channel_ptrs)
    channels_arr = (c.c_void_p * channel_count)(*channel_ptrs)

    nv.initSequence.argtypes = [
        c.c_char_p,  # basename
        c.c_char_p,  # save_folder
        c.c_bool,  # overwrite
        c.POINTER(c.c_void_p),  # channel_ptrs
        c.c_size_t,  # channel_count
    ]
    nv.initSequence.restype = c.c_void_p

    ptr = nv.initSequence(
        basename_bytes,
        folder_bytes,
        overwrite,
        channels_arr,
        channel_count,
    )
    if ptr is None:
        raise RuntimeError("initSequence returned null — allocation or init failed")
    return ptr, basename_bytes, folder_bytes


# LLM: claude wrote this function
def _save_sequence(sequence_ptr: c.c_void_p) -> None:
    """
    Writes each frame of the Sequence to disk as a separate .vdb file,
    using the basename/folder supplied at _init_sequence() time.
    """
    nv.saveSequence.argtypes = [c.c_void_p]
    nv.saveSequence.restype = c.c_size_t

    code = nv.saveSequence(sequence_ptr)
    if code != 0:
        raise RuntimeError(f"saveSequence failed with error code {code}")


# LLM: claude wrote this function
def _deinit_sequence(sequence_ptr: c.c_void_p) -> None:
    """
    Frees a Sequence previously returned by _init_sequence().

    Does NOT free the underlying Channel pointers — those must be freed
    separately with _deinit_channel() after this call returns. Does NOT free
    the basename/folder bytes — those are Python-owned.
    """
    nv.deinitSequence.argtypes = [c.c_void_p]
    nv.deinitSequence.restype = None
    nv.deinitSequence(sequence_ptr)
