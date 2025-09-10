from ctypes import cdll

lib_path = b"/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"

lib = cdll.LoadLibrary(lib_path)

lib.hello()
echo_me = b"ham spam land echo\n"
lib.echo(echo_me)
lib.nifti1ToVDB(lib_path, True)
