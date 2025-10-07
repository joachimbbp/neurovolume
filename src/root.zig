//Zig library root

//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
const debug = @import("debug.zig");
const nifti1 = @import("nifti1.zig");
const vdb543 = @import("vdb543.zig");
const volume = @import("volume.zig");

//_: CONSTS:
const id_4x4 = zools.matrix.IdentityMatrix4x4;
const config = @import("config.zig.zon");

pub const Output = struct {
    filepath: []const u8,
    header_json: []u8,
    //TODO: Eventually we'll add an image with the normalization etc information!
};

//_: Actual functions:

// Returns path to VDB file (or folder containing sequence if fMRI)
pub fn nifti1ToVDB(
    nifti_filepath: []const u8,
    output_dir: []const u8,
    normalize: bool,
    arena_alloc: std.mem.Allocator,
) !Output {
    //TODO: loud vs quiet debug, certainly some kind of loadng feature
    const img_deprecated = try nifti1.Image.init(nifti_filepath);
    defer img_deprecated.deinit();

    var static = true;
    if (img_deprecated.header.dim[0] == 4) {
        static = false;
    } //TODO: coverage for any weird dim numbers
    const minmax = try nifti1.MinMax3D(img_deprecated); //DEPRECATED: will live in new img

    //output folder / new filename / framename_0
    var n_split = std.mem.splitBackwardsSequence(u8, nifti_filepath, "/");
    var name_split = std.mem.splitBackwardsSequence(u8, n_split.first(), ".");
    const ext = name_split.first();
    _ = ext;
    const basename = name_split.rest();
    const base_seq_folder = try std.fmt.allocPrint(arena_alloc, "{s}/{s}", .{ output_dir, basename });
    if (!static) {
        print("non static fmri!\n", .{});
        static = false;

        const vdb_seq_folder = try zools.save.versionFolder(base_seq_folder, arena_alloc); //CLEAN: This feels really hacky and verbose
        var buf = std.array_list.Managed(u8).init(arena_alloc);
        defer buf.deinit();
        for (vdb_seq_folder.items) |c| {
            try buf.append(c);
        }
        try buf.append(0);
        const vdb_seq_folder_slice: [:0]const u8 = buf.items[0 .. buf.items.len - 1 :0];

        const frames: usize = @intCast(img_deprecated.header.dim[4]);

        //WARN: technically a bit unsafe, but there shouldnt be negative dimensions. Will iron out when making img univeral
        const leading_zeros = zools.math.numDigitsShort(@bitCast(img_deprecated.header.dim[4]));
        for (0..frames) |frame| {
            const frame_path = try zools.sequence.elementName(
                vdb_seq_folder_slice,
                basename,
                ".vdb",
                frame,
                leading_zeros,
                arena_alloc,
            );

            var buffer = std.array_list.Managed(u8).init(arena_alloc);
            defer buffer.deinit();

            var vdb = try vdb543.buildFrame(
                arena_alloc,
                img_deprecated,
                minmax,
                normalize,
                frame,
            ); //write VDB frame
            const versioned_vdb_filepath = try vdb543.writeFrame(
                &buffer,
                &vdb,
                frame_path,
                arena_alloc,
            );

            print("new frame: {s}\n", .{versioned_vdb_filepath.items});
        }

        //TODO: You could probably DRY this!
        return Output{
            .filepath = vdb_seq_folder.items,
            .header_json = header_json_string,
        };
    } else {
        //Signifies a static, 3D MRI
        print("Static MRI\n", .{});
        var buffer = std.array_list.Managed(u8).init(arena_alloc);
        defer buffer.deinit();

        var vdb = try vdb543.buildFrame(
            arena_alloc,
            img_deprecated,
            minmax,
            normalize,
            0,
        );
        // CREATE THE DIRECTORY FIRST! //ROBOT: Claude sonet 4.5 suggested this:
        if (std.fs.path.dirname(base_seq_folder)) |dir_path| {
            try std.fs.cwd().makePath(dir_path);
        }

        const frame_path = try std.fmt.allocPrint(
            arena_alloc,
            "{[dir]s}/{[bn]s}.vdb",
            .{ .dir = base_seq_folder, .bn = basename },
        );
        const versioned_vdb_filepath = try vdb543.writeFrame(
            &buffer,
            &vdb,
            frame_path,
            arena_alloc,
        );
        print("new vdb file: {s}\n", .{versioned_vdb_filepath.items});

        return Output{
            .filepath = versioned_vdb_filepath.items,
            .header_json = header_json_string,
        };
    }
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

test "static nifti to vdb" {
    //    try staticTestNifti1ToVDB("tmp");
    //NOTE: There's a little mismatch in the testing/actual functionality at the moment, hence this:
    //TODO: reconcile these by bringing the tmp save out of the function itself and then calling
    //either that or the default persistent location in the real nifti1ToVDB function!
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa_alloc);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const output = try nifti1ToVDB(
        config.testing.files.nifti1_t1,
        config.testing.dirs.output,
        true,
        arena_alloc,
    );
    //defer arena_alloc.free(output);
    print("☁️ 🧠 static nifti test saved as VDB\n", .{});
    print("📜 Output header JSON:\n{s}\n🗃️ Output filepath: {s}\n", .{
        output.header_json,
        output.filepath,
    });
}
