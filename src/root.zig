//Zig library root

//_: IMPORTS
const std = @import("std");
const print = std.debug.print;
const zools = @import("zools");
const zip = zools.zip.pairs;
const rev = zools.slice.reverse;
const nifti1 = @import("nifti1.zig");
const vdb543 = @import("vdb543.zig");

//_: CONSTS:
const config = @import("config.zig.zon");
const SupportError = error{
    Dimensions,
};

//_: Zig Library:

// implementation of Jan's increment_cartesian suggestion
fn increment_cartesian(
    comptime num_dims: comptime_int,
    cart_coord: *[num_dims]usize,
    dim_list: [num_dims]usize,
) bool {
    //false if overflow occurs, true if otherwise
    for (0.., dim_list) |i, di| {
        cart_coord[i] += 1;
        if (cart_coord[i] < di) {
            return true;
        }
        cart_coord[i] = 0;
    }
    return false;
}

fn linear_to_cartesian(
    linear_index: usize,
    comptime num_dims: comptime_int, //number of dimensions //HACK: feels redundant?
    comptime DimType: type,
    dims: *const [num_dims]DimType,
) [num_dims]usize {
    var cartesian_index: [num_dims]usize = @splat(0);
    var idx = linear_index;
    //LLM: mostly a Claude translation of Jan's linear_to_cartesian python illustration:
    for (0.., dims[0..num_dims]) |i, di| {
        const di_usize: usize = @intCast(di);
        cartesian_index[i] = idx % di_usize;
        idx = idx / di_usize;
    }
    //BUG: calculating this once per frame is slow on multi-frame seqs!
    return cartesian_index;
}

//hmmm... maybe more things can be comptime!
fn getValue(
    data: *const []const u8,
    idx: usize, //linear index
    bytes_per_voxel: u16, //NIfTI1 convention, will cover all cases
    comptime SourceType: type,
    comptime ResType: type,
    endianness: std.builtin.Endian,
    comptime num_bytes: comptime_int,
    //Scaling: (set both to 0 if they do not apply)
    slope: ResType,
    intercept: ResType,
    //Normalizing
    normalize: bool,
    minmax: [3]ResType, //min, max, max-min
) ResType {
    const bit_start: usize = idx * @as(usize, @intCast(bytes_per_voxel));
    const bit_end: usize = (idx + 1) * @as(usize, @intCast(bytes_per_voxel));
    const bytes_input = data.*[bit_start..bit_end]; //GPT: dereferencing suggested
    const raw_value: f32 = @floatFromInt(std.mem.readInt(
        SourceType,
        bytes_input[0..num_bytes],
        endianness,
    ));
    var res_value = raw_value;
    if (slope != 0 and intercept != 0) {
        res_value = slope * raw_value + intercept;
    }

    if (normalize) {
        res_value = (res_value - minmax[0]) / minmax[2];
    }
    return res_value;
}

//returns .{mininmum value, maximum value, difference between max and min}
pub fn MinMax(
    comptime T: type, //must be float for now
    data: *const []const u8,
    bytes_per_voxel: u16, //NIfTI1 convention but should cover all cases
    slope: f32,
    intercept: f32,
) [3]T //min, max, max-min
{
    const num_voxels = data.len / @as(usize, @intCast(bytes_per_voxel)); //LLM:
    var minmax: [3]T = .{
        std.math.floatMax(T),
        -std.math.floatMax(T),
        undefined,
    };

    for (0..num_voxels) |idx| {
        const val = getValue(
            data,
            idx,
            bytes_per_voxel,
            i16,
            T,
            .little,
            2,
            slope,
            intercept,
            false,
            .{ 0, 0, 0 },
        );
        if (val < minmax[0]) {
            minmax[0] = val;
        }
        if (val > minmax[1]) {
            minmax[1] = val;
        }
    }
    minmax[2] = minmax[1] - minmax[0];
    return minmax;
}
// Returns path to VDB file (or folder containing sequence if fMRI)
pub fn nifti1ToVDB(
    nifti_filepath: []const u8,
    output_dir: []const u8,
    normalize: bool,
    arena_alloc: std.mem.Allocator,
) ![]const u8 {
    const img = try nifti1.Image.init(nifti_filepath);
    defer img.deinit();
    const hdr = try nifti1.getHeader(nifti_filepath);
    const minmax = MinMax(
        f32,
        &img.data,
        img.bytes_per_voxel,
        hdr.sclSlope,
        hdr.sclInter,
    );
    //output folder / new filename / framename_0
    var n_split = std.mem.splitBackwardsSequence(u8, nifti_filepath, "/");
    var name_split = std.mem.splitBackwardsSequence(u8, n_split.first(), ".");
    const ext = name_split.first();
    _ = ext;
    const basename = name_split.rest();
    const base_seq_folder = try std.fmt.allocPrint(arena_alloc, "{s}/{s}", .{ output_dir, basename });
    var filepath: []const u8 = undefined;

    switch (img.header.dim[0]) {
        //_:Static Image
        3 => {
            //Signifies a static, 3D MRI
            const transform = try nifti1.getTransform(hdr.*);
            var buffer = std.array_list.Managed(u8).init(arena_alloc);
            defer buffer.deinit();
            var vdb = try vdb543.VDB.build(arena_alloc);

            const dim_list: [3]usize = .{
                @intCast(hdr.dim[1]),
                @intCast(hdr.dim[2]),
                @intCast(hdr.dim[3]),
            }; //is this the most performant type?

            var cart = [_]usize{ 0, 0, 0 };
            var idx: usize = 0;
            while (true) {
                if (increment_cartesian(3, &cart, dim_list) == false) {
                    break;
                }
                idx += 1;
                const res_value = getValue(
                    &img.data,
                    idx,
                    img.bytes_per_voxel,
                    i16,
                    f32,
                    .little,
                    //WARN: Hard coded for this particular nifti test file:
                    2, //QUESTION: I believe this is the byte to float val?
                    hdr.sclSlope,
                    hdr.sclInter,
                    normalize,
                    minmax,
                );
                try vdb543.setVoxel(
                    &vdb,
                    .{
                        @intCast(cart[0]),
                        @intCast(cart[1]),
                        @intCast(cart[2]),
                    },
                    @floatCast(res_value),
                    arena_alloc,
                );
            }

            //ROBOT: Claude sonet 4.5 suggested this:
            if (std.fs.path.dirname(base_seq_folder)) |dir_path| {
                try std.fs.cwd().makePath(dir_path);
            }

            const frame_path = try std.fmt.allocPrint(
                arena_alloc,
                "{[dir]s}/{[bn]s}.vdb",
                .{ .dir = output_dir, .bn = basename },
            );

            const versioned_vdb_filepath = try vdb543.writeFrame(
                &buffer,
                &vdb,
                frame_path,
                arena_alloc,
                transform,
            );
            filepath = versioned_vdb_filepath.items;
        },
        //_: Time sequence

        4 => {
            const transform = zools.matrix.IdentityMatrix4x4;
            //FIX: native transform doesn't work with bold as of right now!
            const vdb_seq_folder = try zools.save.versionFolder(
                base_seq_folder,
                arena_alloc,
            );
            var buf = std.array_list.Managed(u8).init(arena_alloc);
            defer buf.deinit();
            for (vdb_seq_folder.items) |c| {
                try buf.append(c);
            }
            try buf.append(0);
            const vdb_seq_folder_slice: [:0]const u8 = buf.items[0 .. buf.items.len - 1 :0];

            const num_voxels = img.data.len / @as(usize, @intCast(img.bytes_per_voxel)); //LLM:
            const num_frames: usize = @intCast(img.header.dim[4]);
            const vpf = @as(usize, @intCast(hdr.dim[1])) *
                @as(usize, @intCast(hdr.dim[2])) *
                @as(usize, @intCast(hdr.dim[3])) *
                @as(usize, @intCast(img.bytes_per_voxel));

            print("🔎 INSPECT: Voxels Per Frame: {d}/{d}={d}\n", .{ num_voxels, num_frames, vpf });
            //this should always be an int!
            const leading_zeros = zools.math.numDigitsShort(@bitCast(img.header.dim[4]));

            for (0..num_frames) |frame| {
                const frame_start = frame * vpf;
                const frame_end = frame_start + vpf;
                const frame_data = img.data[frame_start..frame_end]; //its late, i think exclusive zig?
                const num_frame_voxels = frame_data.len / @as(usize, @intCast(img.bytes_per_voxel)); //LLM:
                var vdb = try vdb543.VDB.build(arena_alloc);

                for (0..num_frame_voxels) |idx| {
                    const cart = linear_to_cartesian(
                        idx,
                        3,
                        i16,
                        hdr.dim[1..4],
                    );

                    const res_value = getValue(
                        &frame_data, //LLM: caught this eroneously left as `img.data`
                        idx,
                        img.bytes_per_voxel,
                        i16,
                        f32,
                        .little,
                        //WARN: Hard coded for this particular nifti test file:
                        2, //QUESTION: I believe this is the byte to float val?
                        hdr.sclSlope,
                        hdr.sclInter,
                        normalize,
                        minmax,
                    );
                    try vdb543.setVoxel(
                        &vdb,
                        .{
                            @intCast(cart[0]),
                            @intCast(cart[1]),
                            @intCast(cart[2]),
                        },
                        @floatCast(res_value),
                        arena_alloc,
                    );
                }
                const frame_path = try zools.sequence.elementName(
                    vdb_seq_folder_slice,
                    basename,
                    "vdb",
                    frame,
                    leading_zeros,
                    arena_alloc,
                );

                var buffer = std.array_list.Managed(u8).init(arena_alloc);
                defer buffer.deinit();

                _ = try vdb543.writeFrame(
                    &buffer,
                    &vdb,
                    frame_path,
                    arena_alloc,
                    transform,
                );
            }

            filepath = vdb_seq_folder.items;
        },
        else => {
            std.debug.print("ERROR: {d} unsupported dimension type\n", .{img.header.dim[0]});
            return SupportError.Dimensions;
        },
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
        //LLM:
        const spatial_code = field & 0x07;
        const temporal_code = (field & 0x38) >> 3;
        //LLMEND:

        if (std.mem.eql(u8, unit_kind_slice, "time") == true) {
            const unit: Unit = @enumFromInt(temporal_code << 3); //LLM: has to shift back
            name = @tagName(unit);
        } else if (std.mem.eql(u8, unit_kind_slice, "space") == true) {
            const unit: Unit = @enumFromInt(spatial_code);
            name = @tagName(unit);
        } else {
            print("⚠️📜 Unsuported unit kind: {s}\n", .{unit_kind_slice});
            return 0;
        }
    } else {
        print("⚠️📂 Unsuported filetype: {s}\n", .{filetype});
        return 0;
    }

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

const t = zools.timer;

test "static nifti to vdb - c level" {
    //NOTE: There's a little mismatch in the testing/actual functionality at the moment, hence this:
    //perhaps: reconcile these by bringing the tmp save out of the function itself and then calling
    //either that or the default persistent location in the real nifti1ToVDB function!

    print("🌊 c level nifti to vdb\n", .{});

    var fpath_buff: [4096]u8 = undefined; //very arbitrary length!
    //TODO: make the lenght a bit more robust. What should it be???

    const start = t.Click();
    const fpath_len = nifti1ToVDB_c(
        config.testing.files.nifti1_t1,
        config.paths.vdb_output_dir,
        true,
        &fpath_buff,
        fpath_buff.len,
    );
    _ = t.Lap(start, "Static Nifti1 to VDB Timer");
    print("☁️ 🧠 static nifti test saved as VDB\n", .{});
    print("🗃️ Output filepath:\n       {s}\n", .{fpath_buff[0..fpath_len]});
}
test "bold nifti to vdb - c level" {
    print("🌊 c level BOLD nifti to vdb\n", .{});

    var fpath_buff: [4096]u8 = undefined; //very arbitrary length!
    //TODO: make the lenght a bit more robust. What should it be???

    const start = t.Click();
    const fpath_len = nifti1ToVDB_c(
        config.testing.files.bold,
        config.paths.vdb_output_dir,
        true,
        &fpath_buff,
        fpath_buff.len,
    );
    _ = t.Lap(start, "BOLD nifti timer");
    print("☁️🩸🧠 BOLD nifti test saved as VDB\n", .{});
    const bhdr = try nifti1.getHeader(config.testing.files.bold);
    const b_trans = try nifti1.getTransform(bhdr.*);
    print("         transform: {any}\n", .{b_trans});
    print("🗃️ Output filepath:\n       {s}\n", .{fpath_buff[0..fpath_len]});
}
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

    //_: slice duration
    const slice_duration = sliceDuration_c(
        config.testing.files.bold,
        ftype,
    );
    print("🧠🍕🌊 c level slice duration: {d}\n", .{slice_duration}); //WARN: our testfiles just have zero slice duration. Oh well!

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

    //_: Pixel dimensions
    const bold_time = pixdim_c(config.testing.files.bold, "NIfTI1", 4);
    const bold_x = pixdim_c(config.testing.files.bold, "NIfTI1", 1);

    print("⏰ Bold time dim: {d:.10}\n", .{bold_time});
    print(" Bold x dim: {d:.10}\n", .{bold_x});

    const t1_time = pixdim_c(config.testing.files.nifti1_t1, "NIfTI1", 4);
    const t1_x = pixdim_c(config.testing.files.nifti1_t1, "NIfTI1", 1);

    print("⏰ t1 time dim: {d:.10}\n", .{t1_time});
    print(" t1 x dim: {d:.10}\n", .{t1_x});
}
