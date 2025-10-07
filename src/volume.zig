const std = @import("std");
const nifti1 = @import("nifti1.zig");
const config = @import("config.zig.zon");

//This is a WIP, universal replacement for Nifti1/Image
name: []const u8,
//json_hdr: []const u8,
resolution: [3]u64, //Should be more than enough for most scientific data
//frames
//FPS
//Interpolation type

pub const Format = enum {
    NIfTI_1,
};

pub fn init(
    filepath: []const u8,
    Header: type,
    format: Format,
    alloc: std.mem.Allocator,
) !@This() {
    //WARN: This might be specific to Nifti, so don't be afraid to move this logic into the switch!

    //SOURCE: Thank's Robbie!

    const file = try std.fs.cwd().openFile(filepath, .{});
    var buf: [4096]u8 = undefined;
    var file_reader = file.reader(&buf);
    const reader = &file_reader.interface;
    const hdr_ptr = try reader.takeStructPointer(Header);
    //
    //_:JSON
    var out = std.io.Writer.Allocating.init(alloc);
    defer out.deinit();
    var stringifier = std.json.Stringify{
        .writer = &out.writer,
        .options = .{
            .whitespace = .minified,
            .emit_strings_as_arrays = false, // This keeps strings as strings, not arrays
            .escape_unicode = true,
            .emit_nonportable_numbers_as_strings = true,
        },
    };

    try stringifier.write(hdr_ptr.*);
    const json_string = out.writer.buffered();
    std.debug.print("JSON string:\n{s}\n", .{json_string});
    //ROBOT: Claude wrote this to clean up the JSON
    var clean_json = std.array_list.Managed(u8).init(alloc);
    defer clean_json.deinit();

    var i: usize = 0;
    while (i < json_string.len) {
        if (i + 5 < json_string.len and
            std.mem.eql(u8, json_string[i .. i + 6], "\\u0000"))
        {
            i += 6; // Skip the \u0000
        } else {
            try clean_json.append(json_string[i]);
            i += 1;
        }
    }
    //END LLM:
    std.debug.print("cleaned JSON string:\n{s}\n", .{clean_json.items});
    //_:JSON end
    const name = try nameFromPath(filepath, alloc);
    switch (format) {
        Format.NIfTI_1 => {
            const x = @as(u64, @intCast(hdr_ptr.*.dim[1]));
            const y = @as(u64, @intCast(hdr_ptr.*.dim[2]));
            const z = @as(u64, @intCast(hdr_ptr.*.dim[3]));
            return .{
                .name = name,
                .resolution = .{ x, y, z },
            };
        },
    }
}

pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
    //TODO: loop through fields
    alloc.free(self.name);
    //res is comptime so no need to destroy
    //alloc.destroy(self.resolution);
}

//TODO:- deinit
// pub fn deinit(self: *const Image) void {
//       //TODO: everything else
//       //why did robbie put this as destroy for one and free for the other?
//       self.allocator.destroy(self.header);
//       self.allocator.free(self.data);
//   }
//
//TODO: - JSON printing:
//if frames = 1, just print that it's static and omit FPS etc
//TODO: Get at and Min Max
//
//
//_: Utils:
fn nameFromPath(filepath: []const u8, alloc: std.mem.Allocator) ![]const u8 {
    const filename = std.fs.path.basename(filepath);
    var iter = std.mem.splitSequence(u8, filename, ".");
    const name = iter.first();
    return try alloc.dupe(u8, name);
}

//_: Testing:
test "volume" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_alloc = gpa.allocator();
    defer _ = gpa.deinit();
    var vol = try init(
        config.testing.files.nifti1_t1,
        nifti1.Header,
        Format.NIfTI_1,
        gpa_alloc,
    );
    defer vol.deinit(gpa_alloc);
    std.debug.print("n: {s}, r: {any}", .{ vol.name, vol.resolution });
}
