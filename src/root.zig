//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools/src/root.zig");
const debug = @import("debug.zig");
const nifti1 = @import("nifti1.zig");
const ArrayList = std.array_list.Managed;
const vdb543 = @import("vdb543.zig");

//_: Debug and Test Functions
pub export fn hello() void {
    print("🪾 Root level print\n", .{});
    debug.helloNeurovolume();
    zools.debug.helloZools();
}
pub export fn echo(word: [*:0]const u8) [*:0]const u8 {
    print("zig level echo print: {s}\n", .{word});
    return word;
}
pub export fn echoHam(word: [*:0]const u8, output_buffer: [*]u8, buf_len: usize) usize {
    //LLM START:
    const input = std.mem.span(word);
    const suffix = " ham";
    const total_len = input.len + suffix.len;
    if (total_len + 1 > buf_len) {
        return 0;
    }
    @memcpy(output_buffer[0..input.len], input); //HUMAN EDIT: changed to @memcpy
    @memcpy(output_buffer[input.len..][0..suffix.len], suffix); //HUMAN EDIT:
    output_buffer[total_len] = 0; // Null terminate

    return total_len;
    //LLM ENDAlignManaged(u8)li:
}

pub export fn alwaysFails() usize {
    std.testing.expect(true == false) catch
        {
            return 0;
        };
    return 1;
}

//LLM:
pub export fn writePathToBufC(
    path_nt: [*:0]const u8, // C string from Python
    out_buf: [*]u8,
    out_cap: usize,
) usize {
    if (out_cap == 0) return 0;

    const src = std.mem.span(path_nt); // []const u8 (no NUL)
    const want = src.len;
    const n = if (want + 1 <= out_cap) want else out_cap - 1;

    @memcpy(out_buf[0..n], src[0..n]);
    out_buf[n] = 0; // NUL-terminate

    return n; // bytes written (excludes NUL)
}
//LLM END:

//_: Actual functions:

pub export fn numFrames(c_filepath: [*:0]const u8) i16 {
    //WARN:
    //Maybe a little computationally redundant with nifti1ToVDB
    //Still figuring out the best lib architecture here, tbh
    //Writes to the buffer, file saving happens on the python level
    const filepath = std.mem.span(c_filepath);
    const img = nifti1.Image.init(filepath) catch {
        print("Failed to load nifti image\n", .{});
        return 0;
    };
    defer img.deinit();
    const num_frames = img.header.dim[4];
    print("zig level dim print: {d}\n", .{num_frames});
    return num_frames;
}

// /input/source_file.any -> /output/soure_file.vdb
fn filenameVDB(alloc: std.mem.Allocator, input_path: [:0]const u8, output_dir: [:0]const u8) ![]u8 {
    //NOTE: might be good to make this public eventually
    const ext = "vdb";
    const f = "{s}/{s}.{s}";
    const p = try zools.path.Parts.init(input_path);
    const output = try std.fmt.allocPrint(alloc, f, .{ output_dir, p.basename, ext });
    return output;
}
// names folder after input_path item basename, for fMRI sequences
fn dirNameFromFile(alloc: std.mem.Allocator, filepath: [:0]const u8, parent_dir: [:0]const u8) ![]u8 {
    const f = "{s}/{s}";
    const p = try zools.path.Parts.init(filepath);
    const output = try std.fmt.allocPrint(alloc, f, .{ parent_dir, p.basename });
    return output;
}

test "dir name" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();
    defer _ = gpa.deinit();
    const parent = "./output";
    const filepath = "/Users/joachimpfefferkorn/repos/neurovolume/output/sub-01_T1w_1.vdb";
    const dir = try dirNameFromFile(alloc, filepath, parent);
    print("dir name from filepath: {s}\n", .{dir});
    alloc.free(dir);
}

// Writes and saves VDB File
fn writeVDB(
    alloc: std.mem.Allocator,
    input_path: [:0]const u8,
    output_dir: [:0]const u8,
    img_deprecated: nifti1.Image,
    normalize: bool,
    transform: [4][4]f64,
) !ArrayList(u8) {
    //TODO: This function should be universal to all possible file formats
    //WARN: not sure about arena here, and your naming convention
    //is all over the place!
    // Writes VDB and saves it to disk
    var buffer = ArrayList(u8).init(alloc);
    defer buffer.deinit();

    const minmax = try nifti1.MinMax3D(img_deprecated);
    const dim = img_deprecated.header.dim;
    var vdb = try vdb543.VDB.build(alloc);

    print("iterating nifti file\n", .{});
    for (0..@as(usize, @intCast(dim[3]))) |z| {
        for (0..@as(usize, @intCast(dim[2]))) |x| {
            for (0..@as(usize, @intCast(dim[1]))) |y| {
                const val = try img_deprecated.getAt4D(x, y, z, 0, normalize, minmax);
                try vdb543.setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, @floatCast(val), alloc);
            }
        }
    }
    vdb543.writeVDB(&buffer, &vdb, transform); // assumes compatible signature

    const default_save_path = try filenameVDB(alloc, input_path, output_dir);
    const vdb_filepath = try zools.save.version(default_save_path, buffer, alloc);
    return vdb_filepath;
}
// Returns path to VDB file (or folder containing sequence if fMRI)
pub export fn nifti1ToVDB(c_nifti_filepath: [*:0]const u8, c_output_dir: [*:0]const u8, normalize: bool, out_buf: [*]u8, out_cap: usize) usize {
    //TODO: loud vs quiet debug, certainly some kind of loaidng feature
    const nifti_filepath = std.mem.span(c_nifti_filepath);
    const output_dir = std.mem.span(c_output_dir);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator(); //TODO: standardize these
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator();

    const img_deprecated = nifti1.Image.init(nifti_filepath) catch { //DEPRECATED: img should be universal
        return 0;
    };
    defer img_deprecated.deinit();
    (&img_deprecated).printHeader();

    const Identity4x4: [4][4]f64 = .{
        .{ 1.0, 0.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0, 0.0 },
        .{ 0.0, 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 0.0, 1.0 },
    };

    const num_dims = img_deprecated.header.dim[0];
    if (num_dims == 3) {
        //Signifies a static, 3D MRI
        print("Static MRI\n", .{});
        const vdb_filepath = writeVDB(allocator, nifti_filepath, output_dir, img_deprecated, normalize, Identity4x4) catch {
            return 0;
        };

        //NOTE: Returning the name here:
        //LLM: inspired. More or less copypasta
        if (out_cap == 0) return 0;
        const src = vdb_filepath.items;
        const n = if (src.len + 1 <= out_cap) src.len else out_cap - 1;
        //Q: I don't fully grasp the reason for the above code
        @memcpy(out_buf[0..n], src[0..n]);
        out_buf[n] = 0; //NULL terminate
        return n;
        //LLM END:
    }
    if (num_dims == 4) {
        print("Time series MRI\n unsuported right now\n", .{});
        return 0;
        //        const seq_dir =
    } else {
        print("unrecognized dim number: {d}, returning 0 for error\n", .{num_dims});
        return 0;
    }
}
