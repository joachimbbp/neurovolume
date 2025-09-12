import ctypes as c

lib_path = "/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"
nvol = c.cdll.LoadLibrary(lib_path)  # Neurovolume library


def b(string):
    """
    Returns the utf-u8 encoded bytes literal of the string
    Equivalent to 'b"inputstring"'
    """
    return string.encode("utf-8")


def nifti_dims(filepath) -> int:
    nvol.nifti1NumDims.argtypes = [c.c_char_p]
    nvol.nifti1NumDims.restype = c.c_int16
    dim_zero = nvol.nifti1NumDims(b(filepath))
    return dim_zero
    # TODO: If you keep this around, make sure it covers all nifti types


def nifti1ToVDB(filepath: str, normalize: bool) -> str:
    BUF_SIZE = 256  # somewhat arbitrary, should be big enough

    # Q: Why on earth do these work with the wrong function?
    nvol.writePathToBufC.argtypes = [
        c.c_char_p, c.POINTER(c.c_char), c.c_size_t]
    nvol.writePathToBufC.restype = c.c_size_t

    save_location = c.create_string_buffer(BUF_SIZE)
#    save_loc_len = lib.nifti1ToVDB(nifti_path, True, save_loc_buf, BUF_SIZE)
    nvol.nifti1ToVDB(b(filepath), True, save_location, BUF_SIZE)
    return save_location.value.decode()


# SECTION: Testing:
static_testfile = "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
# save_location = nifti1ToVDB(static_testfile, True)
# print("VDB saved to: ", save_location, "\n")
nvol.nifti1NumDims(static_testfile)
