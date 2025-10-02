//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
const debug = @import("debug.zig");
const nifti1 = @import("nifti1.zig");
const ArrayList = std.array_list.Managed;
const vdb543 = @import("vdb543.zig");

//_: CONSTS:
const id_4x4 = zools.matrix.IdentityMatrix4x4;
const config = @import("config.zig.zon");

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

// Returns path to VDB file (or folder containing sequence if fMRI)
pub export fn nifti1ToVDB(c_nifti_filepath: [*:0]const u8, c_output_dir: [*:0]const u8, normalize: bool, out_buf: [*]u8, out_cap: usize) usize {
    //TODO: loud vs quiet debug, certainly some kind of loadng feature
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const nifti_filepath = std.mem.span(c_nifti_filepath);
    const output_dir = std.mem.span(c_output_dir);
    const img_deprecated = nifti1.Image.init(nifti_filepath) catch { //DEPRECATED: img should be universal
        return 0;
    };
    defer img_deprecated.deinit();
    (&img_deprecated).printHeader();

    var static = true;
    if (img_deprecated.header.dim[0] == 4) {
        static = false;
    } //TODO: coverage for any weird dim numbers
    var vdb_path: ArrayList(u8) = undefined;
    const minmax = nifti1.MinMax3D(img_deprecated) //DEPRECATED: will live in new img
        catch {
            print("minmax error\n", .{});
            return 0;
        };
    //output folder / new filename / framename_0
    var n_split = std.mem.splitBackwardsSequence(u8, nifti_filepath, "/");
    var name_split = std.mem.splitBackwardsSequence(u8, n_split.first(), ".");
    const ext = name_split.first();
    _ = ext;
    const basename = name_split.rest();
    const base_seq_folder = std.fmt.allocPrint(gpa_alloc, "{s}/{s}", .{ output_dir, basename }) catch {
        print("allocPrint error (in !static block)\n", .{});
        return 0;
    };

    if (!static) {
        print("non static fmri!\n", .{});
        static = false;

        defer gpa_alloc.free(base_seq_folder);
        const vdb_seq_folder = zools.save.versionFolder(base_seq_folder, arena_alloc) catch { //EXORCISE: allocator naming convention
            return 0;
        };
        //CLEAN: This feels really hacky and verbose
        var buf = ArrayList(u8).init(arena_alloc);
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
            const frame_path = zools.sequence.elementName(
                vdb_seq_folder_slice,
                basename,
                ".vdb",
                frame,
                leading_zeros,
                arena_alloc,
            ) catch {
                print("Error on sequence element name\n", .{});
                return 0;
            };

            defer arena_alloc.free(frame_path);

            var buffer = ArrayList(u8).init(arena_alloc);
            defer buffer.deinit();

            var vdb = vdb543.buildFrame(
                arena_alloc,
                img_deprecated,
                minmax,
                normalize,
                frame,
            ) catch {
                print("Error on buildVDBFrame\n", .{});
                return 0;
            };
            //write VDB frame
            const versioned_vdb_filepath = vdb543.writeFrame(
                &buffer,
                &vdb,
                frame_path,
                arena_alloc,
            ) catch {
                print("Error on writeVDBFrame\n", .{});
                return 0;
            };

            print("new frame: {s}\n", .{versioned_vdb_filepath.items});
        }
        vdb_path = vdb_seq_folder;
    }
    if (static) {
        //Signifies a static, 3D MRI
        print("Static MRI\n", .{});
        var buffer = ArrayList(u8).init(arena_alloc);
        defer buffer.deinit();

        var vdb = vdb543.buildFrame(
            arena_alloc,
            img_deprecated,
            minmax,
            normalize,
            0,
        ) catch {
            print("Error on buildVDBFrame\n", .{});
            return 0;
        };

        const frame_path = std.fmt.allocPrint(
            arena_alloc,
            "{[dir]s}/{[bn]s}.vdb",
            .{ .dir = base_seq_folder, .bn = basename },
        ) catch {
            print("error on allocprint\n", .{});
            return 0;
        };
        const versioned_vdb_filepath = vdb543.writeFrame(
            &buffer,
            &vdb,
            frame_path,
            arena_alloc,
        ) catch {
            print("Error on writeVDBFrame\n", .{});
            return 0;
        };
        print("new vdb file: {s}\n", .{versioned_vdb_filepath.items});
    }

    //NOTE: Returning the name here:
    //LLM: inspired. More or less copypasta
    if (out_cap == 0) return 0;

    var src = vdb_path.items;
    const n = if (src.len + 1 <= out_cap) src.len else out_cap - 1;
    //Q: I don't fully grasp the reason for the above code
    @memcpy(out_buf[0..n], src[0..n]);
    out_buf[n] = 0; //NULL terminate
    return n;
    //LLM END:
}

//_: Debug and Test Functions
test "echo module" {
    print("🪾root.zig test print\n", .{});
}
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

//_: Root Tests:
// Each module has it's own test suite. The root module contains tests that must
// incorportate multiple modules (such as nifti->vdb), as well as general import
// tests for zools ("imports");

const t = zools.timer;
const test_utils = @import("test_utils.zig");
test "imports" {
    const timer_start = t.Click();
    defer t.Stop(timer_start);
    defer print("\nUUID Timer test:\n", .{});
    zools.debug.helloZools();
    for (0..5) |_| {
        print("random uuid: {s}\n", .{zools.uuid.v4()});
    }
}

pub fn staticTestNifti1ToVDB(comptime save_dir: []const u8) !void {
    //TODO::
    //- [ ] Eventually this should be integrated more tightly as to test
    //the actual nifti1->VDB functions, not just the VDB writing as it does now?
    //This will probably mean splitting that function out into smaller functions
    //- [ ] Make this a bit more responsive?
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    var arena_alloc = arena.allocator();

    var buffer = ArrayList(u8).init(arena_alloc);
    defer buffer.deinit();

    const path = config.testing.files.nifti1_t1;
    //TODO: Move this test file path to
    const img = try nifti1.Image.init(path); //DEPRECATED:
    defer img.deinit();
    (&img).printHeader();
    const dims = img.header.dim;
    //check to make sure it's a static 3D image:
    if (dims[0] != 3) {
        print(
            "Warning! Not a static 3D file. Has {any} dimensions\nPlease check test file source",
            .{dims[0]},
        );
        return test_utils.TestPatternError.FileError;
    }
    const minmax = try nifti1.MinMax3D(img);

    var vdb = try vdb543.buildFrame(
        arena_alloc,
        img,
        minmax,
        true,
        0,
    );

    //WIP: build and write VDB functions moving about
    try vdb543.writeVDB(&buffer, &vdb, id_4x4);
    try test_utils.saveTestPattern(
        save_dir,
        "static_nifti1_test_file",
        &arena_alloc,
        &buffer,
    );
}

test "static nifti to vdb" {
    try staticTestNifti1ToVDB("tmp");
    print("☁️ 🧠 static nifti test saved as VDB\n", .{});
}
