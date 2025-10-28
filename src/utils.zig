//Universal scaling types to be shared across different data types
//Subject to change as we reimplement getAt
//More or less a replacement for img
pub const Scaling = struct {
    sclSlope: f32,
    sclInter: f32,
    dim: [4]usize, //x y z t

    //DOES BYTES PER VOXEL GO HERE? IDK
    //WIP: stopped here
};
