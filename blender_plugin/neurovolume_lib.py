import ctypes as c

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
    hdr_size = nvol.nifti1ToVDB_c(b(filepath),
                                  b(output_dir),
                                  normalize,
                                  save_location,
                                  BUF_SIZE)

    return save_location.value.decode()


def get_raw_hdr(filepath: str, filetype: str) -> str:
    match filetype:  # HACK: this is repeated in root.zig, ugh
        case "NIfTI1":
            hdr = c.create_string_buffer(348)
            nvol.getHdr_c.argtypes = [c.c_char_p,
                                      c.c_char_p,
                                      c.POINTER(c.c_char)]
            nvol.getHdr_c.restype = c.c_size_t
            hdr_size = nvol.getHdr_c(b(filepath), b(filetype), hdr)
            return hdr.raw[:hdr_size]
        case _:
            err_msg = f"{filetype} is unsupported"
            print(err_msg)
            return err_msg


# _: Testing:

# Static:
save_location = nifti1_to_VDB(static_testfile, True)
print("🐍VVV VB ved to: ", save_location, "\n")
# fMRI:
fmri_save_location = nifti1_to_VDB(fmri_testfile, True)
print("🐍 VDB fmri saved to: ", fmri_save_location, "\n")
# Header:
hdr = get_hdr(static_testfile, "NIfTI1")
print("🐍hdr: ", hdr)
