import ctypes as c

# _: Things that will eventually live in a config file:
lib_path = "/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"
output_dir = "./output"
static_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
fmri_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii"

nvol = c.cdll.LoadLibrary(lib_path)  # Neurovolume library


def b(string):
    """
    Returns the utf-u8 encoded bytes literal of the string
    Equivalent to 'b"inputstring"'
    """
    return string.encode("utf-8")


def num_frames(filepath) -> int:
    print("filepath: ", b(filepath))
    nvol.numFrames.argtypes = [c.c_char_p]
    nvol.numFrames.restype = c.c_int16
    num_frames = nvol.numFrames(b(filepath))
    return num_frames

# TODO:
# [ ] load static file
# [ ] load fMRI
# def load_nifti(filepath: str) -> str:


def nifti1_to_VDB(filepath: str, normalize: bool) -> str:
    BUF_SIZE = 256  # somewhat arbitrary, should be big enough for file name
    nvol.nifti1ToVDB.argtypes = [c.c_char_p,
                                 c.c_char_p,
                                 c.c_bool,
                                 c.POINTER(c.c_char),
                                 c.c_size_t]
    nvol.nifti1ToVDB.restype = c.c_size_t
    save_location = c.create_string_buffer(BUF_SIZE)
    nvol.nifti1ToVDB(b(filepath), b(output_dir), True, save_location, BUF_SIZE)
    return save_location.value.decode()


# SECTION: Testing:
# Static:
# save_location = nifti1_to_VDB(static_testfile, True)
# print("VDB saved to: ", save_location, "\n")
# nf = num_frames(static_testfile)
# print("python level num frames: ", nf)
#
# fMRI:

fmri_save_location = nifti1_to_VDB(fmri_testfile, True)
print("VDB fmri saved to: ", fmri_save_location, "\n")
print("python level num frames: ", num_frames(fmri_testfile))
