//C-ABI Translation of Zig functions for the Python library
//
//NOTE: when you had this in the root module the function calls looked something like:
//pub export fn nifti1ToVDB(c_nifti_filepath: [*:0]const u8, c_output_dir: [*:0]const u8, normalize: bool, out_buf: [*]u8, out_cap: usize,) usize {

// pub export fn writePathToBufC( //LLM: Function is gpt copypasta
//     path_nt: [*:0]const u8, // C string from Python
//     out_buf: [*]u8,
//     out_cap: usize,
// ) usize {
//     if (out_cap == 0) return 0;
//
//     const src = std.mem.span(path_nt); // []const u8 (no NUL)
//     const want = src.len;
//     const n = if (want + 1 <= out_cap) want else out_cap - 1;
//
//     @memcpy(out_buf[0..n], src[0..n]);
//     out_buf[n] = 0; // NUL-terminate
//
//     return n; // bytes written (excludes NUL)
// }
