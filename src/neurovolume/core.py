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

nvol = c.cdll.LoadLibrary(lib_path)  # Neurovolume library


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
    nvol.hello()


def prep_ndarray(
    arr: np.ndarray,
    normalize=True,
    transpose=(0, 2, 1),  # Seems to work for most neuroscience packages
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
        this is set to 0,2,1, which seems to work for ANTs and Nibabel

    Returns:
    ------------
    np.ndarray
        prepared np.ndarray (should be of type float32)
    """
    if normalize:
        arr = (arr - np.min(arr)) / (np.max(arr) - np.min(arr))
    arr = np.transpose(arr, transpose)
    arr = np.array(arr, order="C", dtype=np.float32)
    return arr


def ndarray_to_VDB(
    arr: np.ndarray,
    save_path: str,
    transform: np.ndarray = None,
):
    """
    Creates a VDB file from an ndarray.
    use prep_ndarray to prepprocess ndarrays coming straight
    out of nibabel or ANTs (might work on other data too)

    Parameters:
    ---------
    arr: numpy.ndarray
        The ndarray you wish to conver
    save_path: str
        Full filepath for the .vdb
    transform: numpy.ndarray
    """
    # LLM: full up copypasta error handling
    parent_dir = os.path.dirname(save_path)
    if parent_dir and not os.path.exists(parent_dir):
        raise FileNotFoundError(f"Parent directory does not exist: {parent_dir}")

    # LOTS OF LLM: here
    if transform is None:
        transform = np.eye(4, dtype=np.float64)
    affine_flat = transform.flatten().astype(np.float64)

    dims = np.array(arr.shape, dtype=np.uint64)

    nvol.ndArrayToVDB_c.argtypes = [
        np.ctypeslib.ndpointer(dtype=np.float32, flags="C_CONTIGUOUS"),
        c.POINTER(c.c_size_t),
        np.ctypeslib.ndpointer(dtype=np.float64, flags="C_CONTIGUOUS"),
        c.c_char_p,
    ]
    nvol.ndArrayToVDB_c.restype = c.c_size_t
    res = nvol.ndArrayToVDB_c(
        arr,
        dims.ctypes.data_as(c.POINTER(c.c_size_t)),
        affine_flat,
        save_path.encode("utf-8"),
    )
    if res == 0:
        print("error!")


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
    nvol.nifti1ToVDB_c.argtypes = [
        c.c_char_p,
        c.c_char_p,
        c.c_bool,
        c.POINTER(c.c_char),
        c.c_size_t,
    ]
    nvol.nifti1ToVDB_c.restype = c.c_size_t
    nvol.nifti1ToVDB_c(b(nifti_path), b(output_dir), normalize, save_location, BUF_SIZE)

    return save_location.value.decode()


# FIX: almost all of these `case "NIfTI1"` switches are redundant,
# the same logic is following in the zig code


def num_frames(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            nvol.numFrames_c.argtypes = [
                c.c_char_p,
                c.c_char_p,
            ]
            nvol.numFrames_c.restype = c.c_size_t
            num_frames = nvol.numFrames_c(b(filepath), b(filetype))
            return num_frames
        case _:
            err_msg = f"{filetype} is unsupported for num_frames access"
            raise ValueError(err_msg)


def pixdim(filepath: str, filetype: str, dim: int) -> float:
    match filetype:
        case "NIfTI1":
            nvol.pixdim_c.argtypes = [c.c_char_p, c.c_char_p, c.c_int]
            nvol.pixdim_c.restype = c.c_float
            pixdim = nvol.pixdim_c(b(filepath), b(filetype), dim)
            return pixdim
        case _:
            err_msg = f"{filetype} is unsupported for pixdim access"
            raise ValueError(err_msg)


# WARN: never tested or used and test file just puts this as 0 for some reason
def slice_duration(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            nvol.sliceDuration_c.argtypes = [
                c.c_char_p,
                c.c_char_p,
            ]
            nvol.sliceDuration_c.restype = c.c_size_t
            slice_duration = nvol.sliceDuration_c(b(filepath), b(filetype))
            return slice_duration
        case _:
            err_msg = f"{filetype} is unsupported for slice_duration access"
            raise ValueError(err_msg)


def unit(filepath: str, filetype: str, unit_kind: str) -> str:
    BUF_SIZE = 64  # generously padded, tbh
    unit_name = c.create_string_buffer(BUF_SIZE)
    nvol.unit_c.argtypes = [
        c.c_char_p,
        c.c_char_p,
        c.c_char_p,
        c.POINTER(c.c_char),
        c.c_size_t,
    ]
    nvol.unit_c.restype = c.c_size_t
    nvol.unit_c(b(filepath), b(filetype), b(unit_kind), unit_name, BUF_SIZE)
    return unit_name.value.decode()


def source_fps(filepath: str, filetype: str) -> int:
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


#
# def real_size():
#     # TODO: will need to get measurement units and as well as the pixdim
#
#     # TODO: def runtime
#     # which will include a lot fo the stuff in fps as well as temporal_offset

