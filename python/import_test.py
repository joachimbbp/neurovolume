from ctypes import cdll, c_char_p

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
# lib.nifti1ToVDB(nifti_path, True)
