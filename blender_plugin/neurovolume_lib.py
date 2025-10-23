import ctypes as c
print("running library")
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
            print(err_msg)
            # TODO: Error handling


# Not really used, tbh! #WARN: never tested
def slice_duration(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            nvol.sliceDuration_c.argtypes = [c.c_char_p, c.c_char_p,]
            nvol.sliceDuration_c.restype = c.c_size_t
            slice_duration = nvol.sliceDuration_c(b(filepath), b(filetype))
            return slice_duration
        case _:
            err_msg = f"{filetype} is unsupported for slice_duration access"
            print(err_msg)
            # TODO: Error handling


def fps(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            if num_frames(filepath, filetype) == 0:
                print("staic file, frames per second of zero!")
                return 0
        case _:
            err_msg = f"{filetype} is unsupported for num_frames access"
            print(err_msg)
            # TODO: Error handling


def unit(filepath: str, filetype: str, unit_kind: str) -> str:
    BUF_SIZE = 64  # generously padded, tbh
    unit_name = c.create_string_buffer(BUF_SIZE)
    nvol.unit_c.argtypes = [c.c_char_p, c.c_char_p,
                            c.c_char_p, c.POINTER(c.c_char), c.c_size_t]
    nvol.unit_c.restype = c.c_size_t
    nvol.unit_c(b(filepath), b(filetype), b(unit_kind), unit_name, BUF_SIZE)
    return unit_name.value.decode()

#
# def real_size():
#     # TODO: will need to get measurement units and as well as the pixdim
#
#     # TODO: def runtime
#     # which will include a lot fo the stuff in fps as well as temporal_offset
