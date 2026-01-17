//Zig library root

//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const util = @import("util.zig");
const zip = util.zipPairs;
const nifti1 = @import("nifti1.zig");
const vdb543 = @import("vdb543.zig");
const root = @import("root.zig");
const t = @import("timer.zig");
const constants = @import("constants.zig");

//_: CONSTS:
const config = @import("config.zig.zon");
const SupportError = error{
    Dimensions,
};
//_: Globals:
//LLM: suggested to make allocators global
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const gpa_alloc = gpa.allocator();
var arena = std.heap.ArenaAllocator.init(gpa_alloc);
const arena_alloc = arena.allocator();

//_: C library:

// Print "hello neurovolume" to terminal for testing purposes
pub export fn hello() void {
    print("hello neurovolume\n", .{});
}
test "hello" {
    hello();
}

pub export fn nifti1ToVDB_c(
    fpath: [*:0]const u8,
    output_dir: [*:0]const u8,
    normalize: bool,
    fpath_buff: [*]u8,
    fpath_cap: usize,
) usize {
    const fpath_slice: []const u8 = std.mem.span(fpath); //LLM: suggested line
    const output_dir_slice: []const u8 = std.mem.span(output_dir);
    const filepath = root.nifti1ToVDB(
        fpath_slice,
        output_dir_slice,
        normalize,
        arena_alloc,
    ) catch {
        return 0;
    };
    const n = if (filepath.len + 1 <= fpath_cap) filepath.len else fpath_cap - 1;
    @memcpy(fpath_buff[0..n], filepath[0..n]);
    arena_alloc.free(filepath);
    return n;
}

pub export fn sliceDuration_c( //WARN: not really used, tbh. Test file has 0 slice duration for no reason
    fpath: [*:0]const u8,
    filetype: [*:0]const u8,
) f32 {
    const fpath_slice: []const u8 = std.mem.span(fpath);
    if (std.mem.eql(u8, std.mem.span(filetype), "NIfTI1") == true) {
        const hdr_ptr = nifti1.getHeader(fpath_slice) catch {
            return 0;
        };
        const slice_duration = hdr_ptr.sliceDuration;
        return slice_duration;
    } else {
        print("⚠️📂 Unsuported filetype: {s}\n", .{filetype});
        return 0;
    }
}

pub export fn pixdim_c( //WARN: not really used, tbh. Test file has 0 slice duration for no reason
    fpath: [*:0]const u8,
    filetype: [*:0]const u8,
    dim: u8,
) f32 {
    const fpath_slice: []const u8 = std.mem.span(fpath);
    if (std.mem.eql(u8, std.mem.span(filetype), "NIfTI1") == true) {
        const hdr_ptr = nifti1.getHeader(fpath_slice) catch {
            return 0;
        };
        const pixdim = hdr_ptr.pixdim; //probably should error handle here tbh!
        return pixdim[dim];
    } else {
        print("⚠️📂 Unsuported filetype: {s}\n", .{filetype});
        return 0;
    }
}

//_: voxels

pub export fn setVoxel_c(
    vdb: *vdb543.VDB,
    pos: *const [3]u32,
    value: f32,
) usize {
    vdb543.setVoxel(vdb, .{ pos.*[0], pos.*[1], pos.*[2] }, value, arena_alloc) catch {
        return 0;
    };
    return 1;
    //WARN: don't forget to free everything in this arena after writing the VDB!
}

test "static nifti to vdb - c level" {
    //note: there's a little mismatch in the testing/actual functionality at the moment, hence this:
    //perhaps: reconcile these by bringing the tmp save out of the function itself and then calling
    //either that or the default persistent location in the real nifti1tovdb function!

    print("🌊 c level nifti to vdb\n", .{});

    var fpath_buff: [4096]u8 = undefined; //very arbitrary length!
    //todo: make the lenght a bit more robust. what should it be???

    const start = t.Click();
    const fpath_len = nifti1ToVDB_c(
        config.testing.files.nifti1_t1,
        config.paths.vdb_output_dir,
        true,
        &fpath_buff,
        fpath_buff.len,
    );
    _ = t.Lap(start, "static nifti1 to vdb timer");
    print("☁️ 🧠 static nifti test saved as vdb\n", .{});
    print("🗃️ output filepath:\n       {s}\n", .{fpath_buff[0..fpath_len]});
}
test "bold nifti to vdb - c level" {
    print("🌊 c level bold nifti to vdb\n", .{});

    var fpath_buff: [4096]u8 = undefined; //very arbitrary length!
    //todo: make the lenght a bit more robust. what should it be???

    const start = t.Click();
    const fpath_len = nifti1ToVDB_c(
        config.testing.files.bold,
        config.paths.vdb_output_dir,
        true,
        &fpath_buff,
        fpath_buff.len,
    );
    _ = t.Lap(start, "bold nifti timer");
    print("☁️🩸🧠 bold nifti test saved as vdb\n", .{});
    const bhdr = try nifti1.getHeader(config.testing.files.bold);
    const b_trans = try nifti1.getTransform(bhdr.*);
    print("         transform: {any}\n", .{b_trans});
    print("🗃️ output filepath:\n       {s}\n", .{fpath_buff[0..fpath_len]});
}
test "header data extraction to c" {
    //_: num frames
    const ftype = "NIfTI1";
    const num_frames_static = numFrames_c(
        config.testing.files.nifti1_t1,
        ftype,
    );
    try std.testing.expect(num_frames_static == 1);
    print("🧠📷🌊 c level num frames for static is: {d}\n", .{num_frames_static});
    const num_frames_bold = numFrames_c(
        config.testing.files.bold,
        ftype,
    );
    try std.testing.expect(num_frames_bold != 1); // fix: yeaaaah this should be exact to the known testfile len!
    print("🧠🎞️🌊 c level num frames for bold: {d}\n", .{num_frames_bold});

    //_: slice duration
    const slice_duration = sliceDuration_c(
        config.testing.files.bold,
        ftype,
    );
    print("🧠🍕🌊 c level slice duration: {d}\n", .{slice_duration}); //warn: our testfiles just have zero slice duration. oh well!

    //_: measurement units
    var t_unit_buff: [20]u8 = undefined;
    const t_unit_len = unit_c(
        config.testing.files.bold,
        "NIfTI1",
        "time",
        &t_unit_buff,
        t_unit_buff.len,
    );
    print("🕰️ 🧠 temporal units: {s}\n", .{t_unit_buff[0..t_unit_len]});
    var s_unit_buff: [20]u8 = undefined;
    const s_unit_len = unit_c(
        config.testing.files.bold,
        "NIfTI1",
        "space",
        &s_unit_buff,
        s_unit_buff.len,
    );
    print("📐 🧠 spatial units: {s}\n", .{s_unit_buff[0..s_unit_len]});

    //_: pixel dimensions
    const bold_time = pixdim_c(config.testing.files.bold, "NIfTI1", 4);
    const bold_x = pixdim_c(config.testing.files.bold, "NIfTI1", 1);

    print("⏰ bold time dim: {d:.10}\n", .{bold_time});
    print(" bold x dim: {d:.10}\n", .{bold_x});

    const t1_time = pixdim_c(config.testing.files.nifti1_t1, "NIfTI1", 4);
    const t1_x = pixdim_c(config.testing.files.nifti1_t1, "NIfTI1", 1);

    print("⏰ t1 time dim: {d:.10}\n", .{t1_time});
    print(" t1 x dim: {d:.10}\n", .{t1_x});
}
