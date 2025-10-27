import ctypes as c
print("running neurovolume library")
# _: Things that will eventually live in a config file:

lib_path = "/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"
output_dir = "./output"
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



def nifti1_to_VDB(filepath: str, normalize: bool) -> str:
    BUF_SIZE = 4096  # somewhat arbitrary, should be big enough for file name
    save_location = c.create_string_buffer(BUF_SIZE)
    nvol.nifti1ToVDB_c.argtypes = [c.c_char_p,
                                   c.c_char_p,
                                   c.c_bool,
                                   c.POINTER(c.c_char),
                                   c.c_size_t]
    nvol.nifti1ToVDB_c.restype = c.c_size_t
    nvol.nifti1ToVDB_c(b(filepath),
                       b(output_dir),
                       normalize,
                       save_location,
                       BUF_SIZE)

    return save_location.value.decode()


# FIX: almost all of these `case "NIfTI1"` switches are redundant,
# the same logic is following in the zig code


def num_frames(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            nvol.numFrames_c.argtypes = [c.c_char_p, c.c_char_p,]
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


# Not really used, tbh! #WARN: never tested and test file just puts this as 0 for some reason
def slice_duration(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            nvol.sliceDuration_c.argtypes = [c.c_char_p, c.c_char_p,]
            nvol.sliceDuration_c.restype = c.c_size_t
            slice_duration = nvol.sliceDuration_c(b(filepath), b(filetype))
            return slice_duration
        case _:
            err_msg = f"{filetype} is unsupported for slice_duration access"
            raise ValueError(err_msg)


def unit(filepath: str, filetype: str, unit_kind: str) -> str:
    BUF_SIZE = 64  # generously padded, tbh
    unit_name = c.create_string_buffer(BUF_SIZE)
    nvol.unit_c.argtypes = [c.c_char_p, c.c_char_p,
                            c.c_char_p, c.POINTER(c.c_char), c.c_size_t]
    nvol.unit_c.restype = c.c_size_t
    nvol.unit_c(b(filepath), b(filetype), b(unit_kind), unit_name, BUF_SIZE)
    return unit_name.value.decode()


def source_fps(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            if num_frames(filepath, filetype) == 1:
                #staic file, frames per second is zero
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
                    raise ValueError(
                        unit, "is an unknown unit, not implemented yet")

        case _:
            err_msg = f"{filetype} is unsupported for num_frames access"
            raise ValueError(err_msg)


#
# def real_size():
#     # TODO: will need to get measurement units and as well as the pixdim
#
#     # TODO: def runtime
#     # which will include a lot fo the stuff in fps as well as temporal_offset
