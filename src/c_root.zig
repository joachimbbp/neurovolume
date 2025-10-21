//C-ABI Translation of Zig functions for the Python library
const std = @import("std");
const root = @import("root.zig");
const config = @import("config.zig.zon");
const print = std.debug.print;

pub export fn nifti1ToVDB_C(
    c_nifti_filepath: [*:0]const u8,
    normalize: bool,
    fpath_buff: [*]u8,
    fpath_cap: usize,
) usize {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const filepath = root.nifti1ToVDB(
        c_nifti_filepath,
        config.paths.vdb_output_dir,
        normalize,
        arena_alloc,
    ) catch {
        return 0;
    };
    defer gpa_alloc.free(filepath);
    const n = if (filepath.len + 1 <= filepath) filepath.len else fpath_cap - 1;
    @memcpy(fpath_buff[0..n], filepath[0..n]);
    return n;
}

//TODO:
//let's have other functions (probably in root)
//that grab the header csv etc from the file

//WARN: oh boy you need to add this to the build
//          linking it in root.zig seems messy....
//

test "static nifti to vdb - c root" {
    //    try staticTestNifti1ToVDB("tmp");
    //NOTE: There's a little mismatch in the testing/actual functionality at the moment, hence this:
    //TODO: reconcile these by bringing the tmp save out of the function itself and then calling
    //either that or the default persistent location in the real nifti1ToVDB function!
    print("🌊 c_root nifti to vdb\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const filepath = try nifti1ToVDB(
        config.testing.files.nifti1_t1,
        config.testing.dirs.output,
        true,
        arena_alloc,
    );
    print("☁️ 🧠 static nifti test saved as VDB\n", .{});
    print("🗃️ Output filepath:\n       {s}\n", .{filepath});
}
