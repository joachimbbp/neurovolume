from ctypes import cdll

lib_path = "/Users/joachimpfefferkorn/repos/neurovolume/zig-out/lib/libneurovolume.dylib"

lib = cdll.LoadLibrary(lib_path)

lib.deps_test()
print(lib.add(5, 6))
