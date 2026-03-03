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


def prep_4D_ndarray(
    arr: np.ndarray,
    transpose: tuple,
) -> np.ndarray:
    """
    Preparation steps needed for ndarrays derrived from nibabel or ANTs

    Parameters:
    ------------
    arr: np.ndarray
        Input numpy array.
    normalize: bool
        VDBs must be float32 normalized between 0 and 1
        By default this is true, but skip if you have already done so
        earlier in your pipeline
    transpose: tuple
        requires some domain knowledge about how your ndarray is laid out.
        CRITICAL for 4D data: the time axis MUST be first (index 0) after
        transposing so that frames are contiguous in C-order memory.
        Zig's extractFrame slices data[n*frame_size..(n+1)*frame_size], which
        only gives a correct single time-point when t is the slowest (leading) dim.
        Example for nibabel/ANTs 4D (x,y,z,t): use (3, 0, 2, 1) → (t, x, z, y)

    Returns:
    ------------
    np.ndarray
        prepared np.ndarray (should be of type float32)
    """
    # order matters here:
    arr = np.transpose(arr, transpose)
    arr = np.array(arr, order="C", dtype=np.float32)
    return arr


def nifti1_to_VDB(
    nifti_path: str,
    output_dir: str,
    normalize: bool,
) -> str:
    """
    Writes a VDB from a nifti1file

    WARNING:
    Uses native parsing which is currently in active development.
    This may not cover all your use cases.
    Recomend using ndarray_to_VDB paired with a third party NIfTI parser.
    See neurovolume_examples for more
    """
    BUF_SIZE = 4096  # somewhat arbitrary, should be big enough for file name
    save_location = c.create_string_buffer(BUF_SIZE)
    nv.nifti1ToVDB_c.argtypes = [
        c.c_char_p,
        c.c_char_p,
        c.c_bool,
        c.POINTER(c.c_char),
        c.c_size_t,
    ]
    nv.nifti1ToVDB_c.restype = c.c_size_t
    nv.nifti1ToVDB_c(b(nifti_path), b(output_dir), normalize, save_location, BUF_SIZE)

    return save_location.value.decode()


# FIX: almost all of these `case "NIfTI1"` switches are redundant,
# the same logic is following in the zig code


def num_frames(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            nv.numFrames_c.argtypes = [
                c.c_char_p,
                c.c_char_p,
            ]
            nv.numFrames_c.restype = c.c_size_t
            num_frames = nv.numFrames_c(b(filepath), b(filetype))
            return num_frames
        case _:
            err_msg = f"{filetype} is unsupported for num_frames access"
            raise ValueError(err_msg)


# LLM: claude wrote this function
def init_four_dim(
    base_name: str,
    save_folder: str,
    overwrite: bool,
    source_format: int,  # 0=ndarray, 1=nifti1 (mirrors volume.zig SourceFormat)
    data: np.ndarray,
    transform: np.ndarray,
    source_fps: float,
    playback_fps: float,
    speed: float,
    dims: tuple,
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

    nv.initFourDim.argtypes = [
        c.c_char_p,  # base_name
        c.c_char_p,  # save_folder
        c.c_bool,  # overwrite
        c.c_int,  # source_format
        c.POINTER(c.c_float),  # data
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


def pixdim(filepath: str, filetype: str, dim: int) -> float:
    match filetype:
        case "NIfTI1":
            nv.pixdim_c.argtypes = [c.c_char_p, c.c_char_p, c.c_int]
            nv.pixdim_c.restype = c.c_float
            pixdim = nv.pixdim_c(b(filepath), b(filetype), dim)
            return pixdim
        case _:
            err_msg = f"{filetype} is unsupported for pixdim access"
            raise ValueError(err_msg)


# WARN: never tested or used and test file just puts this as 0 for some reason
def slice_duration(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            nv.sliceDuration_c.argtypes = [
                c.c_char_p,
                c.c_char_p,
            ]
            nv.sliceDuration_c.restype = c.c_size_t
            slice_duration = nv.sliceDuration_c(b(filepath), b(filetype))
            return slice_duration
        case _:
            err_msg = f"{filetype} is unsupported for slice_duration access"
            raise ValueError(err_msg)


def unit(filepath: str, filetype: str, unit_kind: str) -> str:
    BUF_SIZE = 64  # generously padded, tbh
    unit_name = c.create_string_buffer(BUF_SIZE)
    nv.unit_c.argtypes = [
        c.c_char_p,
        c.c_char_p,
        c.c_char_p,
        c.POINTER(c.c_char),
        c.c_size_t,
    ]
    nv.unit_c.restype = c.c_size_t
    nv.unit_c(b(filepath), b(filetype), b(unit_kind), unit_name, BUF_SIZE)
    return unit_name.value.decode()


def source_fps(filepath: str, filetype: str) -> int:  # DEPRECATED: most likely
    match filetype:
        case "NIfTI1":
            if num_frames(filepath, filetype) == 1:
                # staic file, frames per second is zero
                return 0

            time_unit = unit(filepath, filetype, "time")
            time_value = pixdim(filepath, filetype, 4)
            match time_unit:
                # time_in_seconds / time_value
                case "Seconds":
                    return 1 / time_value
                case "Miliseconds":
                    return 0.001 / time_value
                case "Microseconds":
                    return 0.000001 / time_value

                # These will probably be different
                case "Hertz":
                    raise ValueError("hz not implemented yet")
                case "Parts_per_million":
                    raise ValueError("ppm not implemented yet")
                case "Radians_per_second":
                    raise ValueError("rpm not implemented yet")
                case _:
                    raise ValueError(unit, "is an unknown unit, not implemented yet")

        case _:
            err_msg = f"{filetype} is unsupported for num_frames access"
            raise ValueError(err_msg)
