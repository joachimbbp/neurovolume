//Zig library root

//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
const nifti1 = @import("nifti1.zig");
const vdb543 = @import("vdb543.zig");
const volume = @import("volume.zig");

//_: CONSTS:
const id_4x4 = zools.matrix.IdentityMatrix4x4; //DEPRECATED: transform should derrive from the actual nifti file
const config = @import("config.zig.zon");

//_: Zig Library:

// Returns path to VDB file (or folder containing sequence if fMRI)
pub fn nifti1ToVDB(
    nifti_filepath: []const u8,
    output_dir: []const u8,
    normalize: bool,
    arena_alloc: std.mem.Allocator,
) ![]const u8 {
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
    var filepath: []const u8 = undefined;
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

        filepath = vdb_seq_folder.items;
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
        //ROBOT: Claude sonet 4.5 suggested this:
        if (std.fs.path.dirname(base_seq_folder)) |dir_path| {
            try std.fs.cwd().makePath(dir_path);
        }

        const frame_path = try std.fmt.allocPrint(
            arena_alloc,
            "{[dir]s}/{[bn]s}.vdb",
            .{ .dir = output_dir, .bn = basename },
        );
        print("🐛 DEBUG PRINTY: frame_path: {s} \n", .{frame_path});

        const versioned_vdb_filepath = try vdb543.writeFrame(
            &buffer,
            &vdb,
            frame_path,
            arena_alloc,
        );
        print("new vdb file: {s}\n", .{versioned_vdb_filepath.items});
        filepath = versioned_vdb_filepath.items;
    }

    return filepath;
}

//_: C library:
pub export fn nifti1ToVDB_c(
    fpath: [*:0]const u8,
    output_dir: [*:0]const u8,
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

    const fpath_slice: []const u8 = std.mem.span(fpath); //LLM: suggested line
    const output_dir_slice: []const u8 = std.mem.span(output_dir);
    const filepath = nifti1ToVDB(
        fpath_slice,
        output_dir_slice,
        normalize,
        arena_alloc,
    ) catch {
        return 0;
    };
    defer arena_alloc.free(filepath); //needed????
    const n = if (filepath.len + 1 <= fpath_cap) filepath.len else fpath_cap - 1;
    @memcpy(fpath_buff[0..n], filepath[0..n]);
    return n;
}

//gets the xyzt_units from nifti
pub export fn unit_c(
    fpath: [*:0]const u8,
    filetype: [*:0]const u8,
    unit_kind: [*:0]const u8, //"time" or "space", can be "na" or other types for other file formats
    unitName_buff: [*]u8,
    unitName_cap: usize, //currently the largest is 18
) usize {
    //WARN: this leaned way to heavily on LLMs, I definately can't explain exactly why or how a lot of this works!
    print("🐛 checkpoint: running xyztUnits_c\n", .{});

    var name: []const u8 = undefined;
    const fpath_slice: []const u8 = std.mem.span(fpath);
    const unit_kind_slice: []const u8 = std.mem.span(unit_kind);
    if (std.mem.eql(u8, std.mem.span(filetype), "NIfTI1") == true) {
        const Unit = enum(u8) {
            Unknown = 0,
            //spatial
            Meter = 1,
            Milimeter = 2,
            Micron = 3,
            //temporal
            Seconds = 8,
            Miliseconds = 16,
            Microseconds = 24,
            Hertz = 32,
            Parts_per_million = 40,
            Radians_per_second = 48,
        };

        const hdr_ptr = nifti1.getHeader(fpath_slice) catch {
            return 0;
        };

        const field = hdr_ptr.xyztUnits;
        print("🐛 field binary: {b:0>8} field decimal: {d} field type: {any}\n", .{ field, field, @TypeOf(field) });
        //LLM:
        const spatial_code = field & 0x07;
        print("🐛 spatial_code binary: {b:0>8} decimal: {d} (mask: 0x07 = {b:0>8})\n", .{ spatial_code, spatial_code, @as(u8, 0x07) });
        const temporal_code = (field & 0x38) >> 3;
        print("🐛 temporal_code binary: {b:0>8} decimal: {d} (mask: 0x38 = {b:0>8})\n", .{ temporal_code, temporal_code, @as(u8, 0x38) });
        //LLMEND:

        if (std.mem.eql(u8, unit_kind_slice, "time") == true) {
            const unit: Unit = @enumFromInt(temporal_code << 3); //LLM: has to shift back
            name = @tagName(unit);
            print("🐛 temporal unit: {s}\n", .{name});
        } else if (std.mem.eql(u8, unit_kind_slice, "space") == true) {
            const unit: Unit = @enumFromInt(spatial_code);
            name = @tagName(unit);
            print("🐛 spatial unit: {s}\n", .{name});
        } else {
            print("⚠️📜 Unsuported unit kind: {s}\n", .{unit_kind_slice});
            return 0;
        }
    } else {
        print("⚠️📂 Unsuported filetype: {s}\n", .{filetype});
        return 0;
    }

    print("🐛 deubggy name of unit: {s}\n", .{name});
    const n = if (name.len + 1 <= unitName_cap) name.len else name.len - 1;
    @memcpy(unitName_buff[0..n], name[0..n]);
    return n;
}
pub export fn numFrames_c(
    fpath: [*:0]const u8,
    filetype: [*:0]const u8,
) usize {
    const fpath_slice: []const u8 = std.mem.span(fpath);
    if (std.mem.eql(u8, std.mem.span(filetype), "NIfTI1") == true) {
        const hdr_ptr = nifti1.getHeader(fpath_slice) catch {
            return 0;
        };
        const num_frames: usize = @intCast(hdr_ptr.dim[4]);
        return num_frames;
    } else {
        print("⚠️📂 Unsuported filetype: {s}\n", .{filetype});
        return 0;
    }
}

// test "static nifti to vdb - c level" {
//     //NOTE: There's a little mismatch in the testing/actual functionality at the moment, hence this:
//     //TODO: reconcile these by bringing the tmp save out of the function itself and then calling
//     //either that or the default persistent location in the real nifti1ToVDB function!
//     print("🌊 c level nifti to vdb\n", .{});
//
//     var fpath_buff: [4096]u8 = undefined; //very arbitrary length!
//     //TODO: make the lenght a bit more robust. What should it be???
//
//     const fpath_len = nifti1ToVDB_c(
//         config.testing.files.nifti1_t1,
//         config.paths.vdb_output_dir,
//         true,
//         &fpath_buff,
//         fpath_buff.len,
//     );
//     print("☁️ 🧠 static nifti test saved as VDB\n", .{});
//     print("🗃️ Output filepath:\n       {s}\n", .{fpath_buff[0..fpath_len]});
// }

test "header data extraction to C" {
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
    try std.testing.expect(num_frames_bold != 1); // FIX: yeaaaah this should be exact to the known testfile len!
    print("🧠🎞️🌊 c level num frames for Bold: {d}\n", .{num_frames_bold});
    //_: Measurement units
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

    //TODO: more tests
}
