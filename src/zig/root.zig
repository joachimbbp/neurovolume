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
const SupportError = error{
    Dimensions,
    Type,
};
