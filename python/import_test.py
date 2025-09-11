# NOTE: this is more or less a scratchpad


from ctypes import cdll, c_char_p
import ctypes
lib_path = "/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"

# NOTE: you could do simple wrappers that abstract away the 'b' infront of the strings
lib = cdll.LoadLibrary(lib_path)
lib.echo.argtypes = [c_char_p]
# nifti_path = b"/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
lib.echo.restype = c_char_p
# lib.hello()
lib.hello()
echo_me = b"ham spam land echo\0"
print(lib.echo(echo_me))
result = lib.echo(echo_me)
print(f"echo result: {result.decode('utf-8')}")

print("should be zero: ", lib.alwaysFails())
# LLM START:
lib.echoHam.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_size_t]
lib.echoHam.restype = ctypes.c_size_t

# Allocate a buffer
BUF_SIZE = 256
out_buf = ctypes.create_string_buffer(BUF_SIZE)

# Call Zig function
written = lib.echoHam(b"spam", out_buf, BUF_SIZE)

print("Written bytes:", written)
print("Output string:", out_buf.value.decode())

# NOTE: don't forget about these!
lib.writePathToBufC.argtypes = [
    ctypes.c_char_p, ctypes.POINTER(ctypes.c_char), ctypes.c_size_t]
lib.writePathToBufC.restype = ctypes.c_size_t

string_buf = ctypes.create_string_buffer(BUF_SIZE)
written_string_len = lib.writePathToBufC(
    b"ham/land/spam", string_buf, BUF_SIZE)

print("string: ", string_buf.value.decode())

# SECTION: Nifti
nifti_path = b"/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
lib.nifti1ToVDB.argtypes = [
    ctypes.c_char_p, ctypes.c_bool, ctypes.POINTER(ctypes.c_char), ctypes.c_size_t]
lib.nifti1ToVDB.restype = ctypes.c_size_t
save_loc_buf = ctypes.create_string_buffer(BUF_SIZE)
save_loc_len = lib.nifti1ToVDB(nifti_path, True, save_loc_buf, BUF_SIZE)
print("save location: ", save_loc_buf.value.decode())
