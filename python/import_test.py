from ctypes import cdll

lib_path = "/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"

lib = cdll.LoadLibrary(lib_path)
nifti_path = b"/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"
lib.hello()
echo_me = b"ham spam land echo\n"
lib.echo(echo_me)
lib.nifti1ToVDB(nifti_path, True)
