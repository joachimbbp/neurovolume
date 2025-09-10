from ctypes import cdll

lib_path = "/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"

lib = cdll.LoadLibrary(lib_path)

lib.hello()
# lib.nifti1ToVDB(id(lib_path), True)
echo_me = b"ham spam land echo\n"
lib.echo(echo_me)
