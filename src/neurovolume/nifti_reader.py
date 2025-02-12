import struct
import numpy as np
#Very much WIP
#lets see how far we can go without using numpy

#relevant docs:
# https://docs.python.org/3/library/struct.html
# https://brainder.org/2012/09/23/the-nifti-file-format/


#TODO
# [ ] When cleaning up, make sure you're using lexical scoping

nifti_file_path = "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"

datatypes = {
    0: "unknown, -",
    1: "bool, 1",
    2: "unsigned char, 8",
    4: "signed short, 16",
    8: "signed int, 32",
    16: "float, 32",
    32: "complex, 64",
    64: "double, 64",
    128: "rgb, 24",
    255: "all, -",
    256: "signed char, 8",
    512: "unsigned short, 16",
    768: "unsigned int, 32",
    1024: "long long, 64",
    1280: "unsigned long long, 64",
    1536: "long double, 128",
    1792: "double pair, 128",
    2048: "long double pair, 256",
    2304: "rgba, 32"
} #there is an obvious pattern here, you could probably do a list

def read_nifti(nifti_file_path):
    with open (nifti_file_path, 'rb') as nf:
        def read_hdr_field(offset, size, f_string):
            '''
            offset and size are in bytes
            '''
            nf.seek(offset)
            data = nf.read(size)
            return struct.unpack(f_string, data)

        endianness = '<' #default to little
        dimensions = read_hdr_field(40, 16, f'{endianness}8h')
        #This is how the blogpost specifies but feels like not
        # a great way of doing this???
        if 7 > dimensions[0] < 1:
            endianness = '>'
            dimensions = read_hdr_field(40, 16, f'{endianness}8h')
        print(f"Detected endianness: {'Little' if endianness == '<' else 'Big'}", f"sign: {endianness}")


        header_size = read_hdr_field(0, 4, f'{endianness}1i')[0]
        bitpix = read_hdr_field(72, 2, f'{endianness}1h')[0] #bits per voxel
        dimensions = read_hdr_field(40, 16, f'{endianness}8h')
        vox_offset = read_hdr_field(108, 4, f'{endianness}1f')[0] #Float for ANALYZE filetype compatibility
        datatype = datatypes[read_hdr_field(70, 2, f'{endianness}1h')[0]]

        pixdim = read_hdr_field(76, 32, f'{endianness}8f')
        xyzt_units = int(str(ord(read_hdr_field(123, 1, f'{endianness}1s')[0])), 2) #indexing just the xyz coordinates for now, t is [1]
        #got 2 which is millimeter, which checks out
        print('pixdim: ', pixdim)
        print('xyzt units', type(xyzt_units), xyzt_units)



        qform_code = read_hdr_field(252, 2, f'{endianness}1h')
        sform_code = read_hdr_field(254, 2, f'{endianness}1h')
        print('🟦 qform code ', qform_code)
        print('🟦 sform code ', sform_code)
        #Both return 1, thus I believe we use method 3?

        # We need to get the affines from here:
        srow_x = read_hdr_field(280, 16, f'{endianness}4f')
        srow_y = read_hdr_field(296, 16, f'{endianness}4f')
        srow_z = read_hdr_field(312, 16, f'{endianness}4f')
        print(f'🟩 srow_x {srow_x}\n   srow_y {srow_y}\n   srow_z {srow_z}', )

        print(f'Header Size: {header_size}\nBitpix: {bitpix}\nDatatype: {datatype}\nVox Offset: {vox_offset}\ndimensions: {dimensions}')
        print("Datatype num: ", read_hdr_field(70, 2, f'{endianness}1h')[0])

        scl_slope = read_hdr_field(112, 4, f'{endianness}1f')[0]
        scl_inter = read_hdr_field(116, 4, f'{endianness}1f')[0]
        print(f"scl_slope: {scl_slope}, scl_inter: {scl_inter}")


        # Slice Acquisition Information -------------------
        slice_code = ord(read_hdr_field(122, 1, f'{endianness}1c')[0])  # Convert to integer
        slice_start = read_hdr_field(74, 2, f'{endianness}1h')[0]  # Use 'h' for short
        slice_end = read_hdr_field(120, 2, f'{endianness}1h')[0]  # Same here
        slice_duration = read_hdr_field(132, 4, f'{endianness}1f')[0]  # 'f' for float

        print('🍕 slice code', slice_code)
        #got 0 which means unknown
        print('  slice start', slice_start, 'slice end ', slice_end)
        print('  slice duration ', slice_duration)
        # ---------------------------------------------------


        def read_img_3D(offset=int(vox_offset)):

            num_voxels = (dimensions[1] * dimensions[2] * dimensions[3])
            num_bytes = num_voxels * bitpix // 8
            dtype_override = np.dtype(f'{endianness}i2')
            print("number of voxels: ", num_voxels, "\nnumber of byres: ", num_bytes, "vox offset int", offset, "dtype override: ", dtype_override)

            # From the original header file https://nifti.nimh.nih.gov/pub/dist/src/niftilib/nifti1.h
            # #define DT_SIGNED_SHORT            4     /* signed short (16 bits/voxel) */

            nf.seek(offset)
            print(f"Current file position: {nf.tell()} (Expected: {offset})")
            # data_sample = file.read(16)  # Read first 16 bytes at offset
            # print(f"First 16 bytes after seeking: {data_sample.hex()}")
            print(f"Using dtype: {dtype_override}, Endianness: {dtype_override.byteorder}")

            voxels = np.frombuffer(nf.read(num_bytes), dtype=dtype_override, count=num_voxels)

            print("💠voxels", len(voxels), type(voxels), voxels.shape)
            print("Expected voxel count:", dimensions[1] * dimensions[2] * dimensions[3], "Actual voxel count:", len(voxels))

            return voxels.reshape(dimensions[1], dimensions[2], dimensions[3]) #were just doing 3D for now...
        
        voxels = read_img_3D()

#GPT-------
        # Apply scaling if needed
        if scl_slope != 0:
            voxels = voxels.astype(np.int16) * scl_slope + scl_inter
            #Very weird, but this does give us an output of an array with float64 as the dtype
            #this matches the nibabel implementation
            print("Applied intensity scaling")
        else:
            print("No scaling applied (scl_slope = 0)")
#-----------
        print("volume shape: ", voxels.shape)
        print("Volume dtype", voxels.dtype)

#        hard coding method 3 for now
        def method_3(voxel_array):
            print(np.ndindex(voxel_array.shape))
            # print("input shape", voxel_array.shape)
            # print("using method 3 to transform volume")            
            # #got gpt to write this matrix because I am lazy
            # transformation_matrix = np.array([
            # [srow_x[0], srow_x[1], srow_x[2], srow_x[3]],
            # [srow_y[0], srow_y[1], srow_y[2], srow_y[3]],
            # [srow_z[0], srow_z[1], srow_z[2], srow_z[3]],
            # [0, 0, 0, 1]
            #                     ])
            
            # cloud = []
            # debug_iter = 0
            # for index in np.ndindex(voxel_array.shape):
            #     x, y, z = index
            #     ijk1 = np.array([x, y, z, 1])
            #     point = (transformation_matrix @ ijk1)
            #     debug_iter += 1
            #     if debug_iter % 100 == 0:
            #         print(f'iteration {debug_iter}, point: {point}')

        _ = method_3(voxels)
        return voxels
    
#read_nifti(nifti_file_path)


