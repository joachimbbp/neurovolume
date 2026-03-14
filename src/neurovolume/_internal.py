# this is mostly the zig/c/python translation layer
# all pretty unruley and should be automatically
# generated in the future!

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


nv = c.cdll.LoadLibrary(lib_path)  # Neurovolume library


# LLMEND:
def _hello():
    """Prints 'hello neurovolume' from the c_root.zig"""
    nv.hello()


# _: Main code:
def _b(string):
    """
    Returns the utf-u8 encoded bytes literal of the string
    Equivalent to 'b"inputstring"'
    """
    return string.encode("utf-8")


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


# LLM: claude wrote this function
def _init_four_dim(
    base_name: str,
    save_folder: str,
    overwrite: bool,
    data: np.ndarray,
    transform: np.ndarray,
    source_fps: float,
    playback_fps: float,
    speed: float,
    dims: tuple,
    source_format: int = 0,  # 0=ndarray, 1=nifti1 (mirrors volume.zig SourceFormat)
    cartesian_order: tuple = (0, 1, 2),  # almost always 0 1 2
) -> c.c_void_p:
    """
    Initializes a FourDim volume on the Zig heap and returns an opaque pointer.

    Parameters:
    ------------
    source_format: int
        0 = ndarray, 1 = nifti1 (mirrors volume.zig SourceFormat enum)
    data: np.ndarray
        All frames flattened, C-contiguous float32.
    transform: np.ndarray
        4x4 affine as float64, shape (4,4) or (16,).
    dims: tuple
        (x, y, z, t) voxel dimensions.

    Returns:
    ------------
    Opaque ctypes pointer to the FourDim on the Zig heap.
    Must be freed by calling deinit_four_dim() or save_four_dim().
    """
    data = np.ascontiguousarray(data, dtype=np.float32)
    transform_arr = (c.c_double * 16)(
        *np.ascontiguousarray(transform.flatten(), dtype=np.float64)
    )
    dims_arr = (c.c_size_t * 4)(*dims)
    cartesian_arr = (c.c_size_t * 3)(*cartesian_order)  # LLM: fix on this line

    nv.initFourDim.argtypes = [
        c.c_char_p,  # base_name
        c.c_char_p,  # save_folder
        c.c_bool,  # overwrite
        c.c_int,  # source_format
        c.POINTER(c.c_float),  # data
        c.POINTER(c.c_size_t),  # cartesian_order [3]usize
        c.POINTER(c.c_double),  # transform_flat [16]f64
        c.c_float,  # source_fps
        c.c_float,  # playback_fps
        c.c_float,  # speed
        c.POINTER(c.c_size_t),  # dims [4]usize
    ]
    nv.initFourDim.restype = c.c_void_p

    ptr = nv.initFourDim(
        _b(base_name),
        _b(save_folder),
        overwrite,
        source_format,
        data.ctypes.data_as(c.POINTER(c.c_float)),
        cartesian_arr,
        transform_arr,
        c.c_float(source_fps),
        c.c_float(playback_fps),
        c.c_float(speed),
        dims_arr,
    )
    if ptr is None:
        raise RuntimeError("initFourDim returned null — allocation or init failed")
    return ptr


# LLM: claude wrote this function
def _deinit_four_dim(ptr: c.c_void_p) -> None:
    """
    Frees a FourDim volume allocated by init_four_dim() without saving.
    """
    nv.deinitFourDim.argtypes = [c.c_void_p]
    nv.deinitFourDim.restype = None
    nv.deinitFourDim(ptr)


# LLM: claude wrote this function
def _save_four_dim(ptr: c.c_void_p, interpolation_mode: int) -> None:
    """
    Saves the FourDim volume to VDB files and frees it.
    The pointer is invalid after this call.

    Parameters:
    ------------
    ptr: opaque pointer returned by init_four_dim().
    interpolation_mode: int
        0 = direct (mirrors volume.zig InterpolationMode enum)
    """
    nv.saveFourDim.argtypes = [c.c_void_p, c.c_int]
    nv.saveFourDim.restype = None
    nv.saveFourDim(ptr, interpolation_mode)


# LLM: claude wrote this function
def _init_three_dim(
    base_name: str,
    save_folder: str,
    overwrite: bool,
    data: np.ndarray,
    transform: np.ndarray,
    dims: tuple,
    source_format: int = 0,  # 0=ndarray (mirrors volume.zig SourceFormat)
    cartesian_order: tuple = (0, 1, 2),
) -> c.c_void_p:
    """
    Initializes a ThreeDim volume on the Zig heap and returns an opaque pointer.

    Parameters:
    ------------
    source_format: int
        0 = ndarray (mirrors volume.zig SourceFormat enum)
    data: np.ndarray
        3D volume, C-contiguous float32, normalized to [0, 1].
    transform: np.ndarray
        4x4 affine as float64.
    dims: tuple
        (x, y, z) voxel dimensions.

    Returns:
    ------------
    Opaque ctypes pointer to the ThreeDim on the Zig heap.
    Must be freed by calling deinit_three_dim().
    """
    data = np.ascontiguousarray(data, dtype=np.float32)
    transform_arr = (c.c_double * 16)(
        *np.ascontiguousarray(transform.flatten(), dtype=np.float64)
    )
    dims_arr = (c.c_size_t * 3)(*dims)
    cartesian_arr = (c.c_size_t * 3)(*cartesian_order)

    nv.initThreeDim.argtypes = [
        c.c_char_p,  # base_name
        c.c_char_p,  # save_folder
        c.c_bool,  # overwrite
        c.c_int,  # source_format
        c.POINTER(c.c_float),  # data
        c.POINTER(c.c_size_t),  # cartesian_order [3]usize
        c.POINTER(c.c_double),  # transform_flat [16]f64
        c.POINTER(c.c_size_t),  # dims [3]usize
    ]
    nv.initThreeDim.restype = c.c_void_p

    ptr = nv.initThreeDim(
        _b(base_name),
        _b(save_folder),
        overwrite,
        source_format,
        data.ctypes.data_as(c.POINTER(c.c_float)),
        cartesian_arr,
        transform_arr,
        dims_arr,
    )
    if ptr is None:
        raise RuntimeError("initThreeDim returned null — allocation or init failed")
    return ptr


# LLM: claude wrote this function
def _deinit_three_dim(ptr: c.c_void_p) -> None:
    """
    Frees a ThreeDim volume allocated by init_three_dim() without saving.
    """
    nv.deinitThreeDim.argtypes = [c.c_void_p]
    nv.deinitThreeDim.restype = None
    nv.deinitThreeDim(ptr)


# LLM: claude wrote this function
def _save_three_dim(ptr: c.c_void_p) -> None:
    """
    Saves the ThreeDim volume to a single VDB file.
    The pointer remains valid after this call; free with deinit_three_dim().

    Parameters:
    ------------
    ptr: opaque pointer returned by init_three_dim().
    """
    nv.saveThreeDim.argtypes = [c.c_void_p]
    nv.saveThreeDim.restype = c.c_size_t
    result = nv.saveThreeDim(ptr)
    if result != 0:
        raise RuntimeError(f"saveThreeDim returned error code {result}")
