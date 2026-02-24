//Zig library root

//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const zip = util.zipPairs;
const rev = util.reverseSlice;
const nifti1 = @import("nifti1.zig");
const vdb543 = @import("vdb543.zig");
const constants = @import("constants.zig");
const save = @import("save.zig");

//_: CONSTS:
const config = @import("config.zig.zon");

//TODO:
//development is focusing on the python library for now
//this can be found in c_root.zig and core.py
//Once that is finished, work will begin on the zig library
