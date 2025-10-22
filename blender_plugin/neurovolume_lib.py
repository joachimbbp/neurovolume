import ctypes as c
print("running library")
# _: Things that will eventually live in a config file:

lib_path = "/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"
output_dir = "./output"
static_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
fmri_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii"

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


def num_frames(filepath: str, filetype: str) -> int:
    match filetype:
        case "NIfTI1":
            # hdr = c.create_string_buffer(348)
            nvol.numFrames_c.argtypes = [c.c_char_p, c.c_char_p,]
            nvol.numFrames_c.restype = c.c_size_t
            num_frames = nvol.numFrames_c(b(filepath), b(filetype))
            return num_frames
        case _:
            err_msg = f"{filetype} is unsupported for num_frames access"
            print(err_msg)
            # TODO: Error handling

# _: Testing:

# t1_save_location = nifti1_to_VDB(static_testfile, True)
# t1_nf = num_frames(static_testfile, "NIfTI1")
# print("🐍 static VDB saved to: ", t1_save_location, " with ", t1_nf, " frames\n")

# fmri_save_location = nifti1_to_VDB(fmri_testfile, True)
# bold_nf = num_frames(fmri_testfile, "NIfTI1")
# print("🐍 bold VDB saved to: ", fmri_save_location, " with ", bold_nf, " frames\n")
