import ctypes as c
import numpy as np  # DEPENDENCY:
import sys
import ctypes
from pathlib import Path
import os


# LLM:
def get_library_name():
    if sys.platform == "darwin":
        return "libneurovolume.dylib"
    elif sys.platform == "win32":
        return "libneurovolume.dll"
    else:  # Linux and others
        return "libneurovolume.so"


lib_path = Path(__file__).parent / "_native" / get_library_name()
lib = ctypes.CDLL(str(lib_path))
# LLMEND:

# _: Main code:

nv = c.cdll.LoadLibrary(lib_path)  # Neurovolume library


def b(string):
    """
    Returns the utf-u8 encoded bytes literal of the string
    Equivalent to 'b"inputstring"'
    """
    return string.encode("utf-8")


def get_basename(path):
    hierarchy = path.split("/")
    return hierarchy[-1].split(".")[0]


def get_folder(path):
    """Returns the folder in which the path points to"""
    hiearchy = path.split("/")
    return "/".join(hiearchy[:-1])


def hello():
    """Prints 'hello neurovolume' from the c_root.zig"""
    nv.hello()


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


# LLM: claude wrote this function
def init_four_dim(
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
        b(base_name),
        b(save_folder),
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
def deinit_four_dim(ptr: c.c_void_p) -> None:
    """
    Frees a FourDim volume allocated by init_four_dim() without saving.
    """
    nv.deinitFourDim.argtypes = [c.c_void_p]
    nv.deinitFourDim.restype = None
    nv.deinitFourDim(ptr)


# LLM: claude wrote this function
def save_four_dim(ptr: c.c_void_p, interpolation_mode: int) -> None:
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
def init_three_dim(
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
        b(base_name),
        b(save_folder),
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
def deinit_three_dim(ptr: c.c_void_p) -> None:
    """
    Frees a ThreeDim volume allocated by init_three_dim() without saving.
    """
    nv.deinitThreeDim.argtypes = [c.c_void_p]
    nv.deinitThreeDim.restype = None
    nv.deinitThreeDim(ptr)


# LLM: claude wrote this function
def save_three_dim(ptr: c.c_void_p) -> None:
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


# LLM: claude fixed bugs (nv.* calls → direct calls, four_dim→three_dim for 3D branch, arr.dim→arr.ndim)
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
    if arr.ndim == 3:
        print("3D array")

        dims = arr.shape

        vol = init_three_dim(
            base_name=basename,
            save_folder=output_dir,
            overwrite=True,
            data=arr,
            transform=transform,  # 4x4 affine float64
            dims=dims,  # (x, y, z)
        )
        save_three_dim(vol)
        deinit_three_dim(vol)

    elif arr.ndim == 4:
        print("4D array")

        dims = arr.shape  # (x, z, y, t) after transpose

        seq_out = os.path.join(output_dir, basename)
        os.makedirs(seq_out, exist_ok=True)
        vol = init_four_dim(
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
        save_four_dim(vol, interpolation_flag)
        deinit_four_dim(vol)
    else:
        print(f"{arr.ndim}D not supported")
        return


# LLM: mostly
def get_fps(img, loud=False):
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
