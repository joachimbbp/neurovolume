//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
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
pub export fn echoHam(word: [*:0]const u8, output_buffer: [*]u8, buf_len: usize) usize { //LLM: Function is gpt copypasta
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

pub export fn writePathToBufC( //LLM: Function is gpt copypasta
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

//_: Actual functions:

pub export fn numFrames(c_filepath: [*:0]const u8) i16 {
    //TIDY:
    //Maybe a little computationally redundant with nifti1ToVDB
    //Still figuring out the best lib architecture here, tbh
    //Writes to the buffer, file saving happens on the python level
    //DEPRECATED: later just spit out the header and get it from there
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
// fn filenameVDB(alloc: std.mem.Allocator, input_path: [:0]const u8, output_dir: [:0]const u8, leading_zeros: u8, frame_num: usize, part_of_sequence: bool) ![]u8 {
//     //NOTE: might be good to make this public eventually
//     const ext = "vdb";
//     const p = try zools.path.Parts.init(input_path);
//     var output: []u8 = undefined;
//     if (part_of_sequence) {
//         //  "{[dir]s}/{[pf]s}_{[n]d:0>[w]}.{[ext]s}"
//         //        output = try std.fmt.allocPrint(alloc, "{s}/{s}_{d}.{s}", .{ output_dir, p.basename, frame_num, ext });
//
//     } else {
//         output = try std.fmt.allocPrint(alloc, "{s}/{s}.{s}", .{ output_dir, p.basename, ext });
//     }
//     return output;
// }
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
// Will version if already present
fn writeVDBFrame(
    alloc: std.mem.Allocator,
    output_path: [:0]const u8,
    img_deprecated: nifti1.Image,
    normalize: bool,
    transform: [4][4]f64,
    frame: usize,
) !ArrayList(u8) {
    //TODO: This function should be universal to all possible file formats
    //This should probably be done on the img level
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
                const val = try img_deprecated.getAt4D(x, y, z, frame, normalize, minmax);
                try vdb543.setVoxel(&vdb, .{ @intCast(x), @intCast(y), @intCast(z) }, @floatCast(val), alloc);
            }
        }
    }
    try vdb543.writeVDB(&buffer, &vdb, transform); // assumes compatible signature
    const vdb_filepath = try zools.save.version(output_path, buffer, alloc);
    return vdb_filepath;
}
// Returns path to VDB file (or folder containing sequence if fMRI)
pub export fn nifti1ToVDB(c_nifti_filepath: [*:0]const u8, c_output_dir: [*:0]const u8, normalize: bool, out_buf: [*]u8, out_cap: usize) usize {
    //TODO: loud vs quiet debug, certainly some kind of loadng feature
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator(); //TODO: standardize these
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const allocator = arena.allocator(); //CURSED: terrible naming convetion mismatch here

    const nifti_filepath = std.mem.span(c_nifti_filepath);
    const output_dir = std.mem.span(c_output_dir);
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

    var static = true;
    if (img_deprecated.header.dim[0] == 4) {
        static = false;
    } //TODO: coverage for any weird dim numbers
    var vdb_path: ArrayList(u8) = undefined;
    if (!static) {
        print("non static fmri!\n", .{});
        static = false;

        //output folder / new filename / framename_0
        var n_split = std.mem.splitBackwardsSequence(u8, nifti_filepath, "/");
        var name_split = std.mem.splitBackwardsSequence(u8, n_split.first(), ".");
        const ext = name_split.first();
        _ = ext;
        const basename = name_split.rest();
        const base_seq_folder = std.fmt.allocPrint(gpa_alloc, "{s}/{s}", .{ output_dir, basename }) catch {
            return 0;
        };

        defer gpa_alloc.free(base_seq_folder);
        const vdb_seq_folder = zools.save.versionFolder(base_seq_folder, allocator) catch { //EXORCISE: allocator naming convention
            return 0;
        };
        //CLEAN: This feels really hacky and verbose
        var buf = ArrayList(u8).init(allocator);
        defer buf.deinit();
        for (vdb_seq_folder.items) |c| {
            buf.append(c) catch {
                return 0;
            };
        }
        buf.append(0) catch {
            return 0;
        };
        const vdb_seq_folder_slice: [:0]const u8 = buf.items[0 .. buf.items.len - 1 :0];

        const frames: usize = @intCast(img_deprecated.header.dim[4]);

        //WARN: technically a bit unsafe, but there shouldnt be negative dimensions. Will iron out when making img univeral
        const leading_zeros = zools.math.numDigitsShort(@bitCast(img_deprecated.header.dim[4]));
        for (0..frames) |frame| {
            //TODO: un-hard code leading zeros (and extension?)
            const frame_path = zools.sequence.elementName(vdb_seq_folder_slice, basename, ".vdb", frame, leading_zeros, allocator) catch {
                print("Error on sequence element name\n", .{});
                return 0;
            };

            defer allocator.free(frame_path);
            //new_frame will include any versioning (which is -honestly- a little messy)
            const new_frame = writeVDBFrame(allocator, vdb_seq_folder_slice, img_deprecated, normalize, Identity4x4, frame) catch {
                print("Error on writeVDBFrame", .{});
                return 0;
            };
            //WARN: Free new_frame?
            print("new frame: {s}\n", .{new_frame.items});
        }
        vdb_path = vdb_seq_folder;
    }
    if (static) {
        //Signifies a static, 3D MRI
        print("Static MRI\n", .{});
        vdb_path = writeVDBFrame(allocator, output_dir, img_deprecated, normalize, Identity4x4, 0) catch {
            return 0;
        };
    }

    //NOTE: Returning the name here:
    //LLM: inspired. More or less copypasta
    if (out_cap == 0) return 0;

    var src = vdb_path.items;
    const n = if (src.len + 1 <= out_cap) src.len else out_cap - 1;
    //Q: I don't fully grasp the reason for the above code
    @memcpy(out_buf[0..n], src[0..n]);
    out_buf[n] = 0; //NULL terminate
    //    print("checkpoint\n        n:{d}", .{n});
    return n;
    //LLM END:
}
