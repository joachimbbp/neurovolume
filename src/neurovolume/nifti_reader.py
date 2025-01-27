import numpy as np

class NIFTIReader:
    def __init__(self, file_path):
        self.file_path = file_path
        self.header = None
        self.data = None

    def read(self):
        with open(self.file_path, "rb") as f:
            # Read the first 4 bytes to determine header size
            sizeof_hdr = np.frombuffer(f.read(4), dtype=np.int32)[0]
            f.seek(0)  # Reset file pointer
            if sizeof_hdr == 348:
                self.header = self._read_nifti1_header(f)
            elif sizeof_hdr == 540:
                self.header = self._read_nifti2_header(f)
            else:
                raise ValueError("Invalid NIFTI file: unsupported header size.")
            self.data = self._read_data(f)

    def _read_nifti1_header(self, f):
        f.seek(0)
        header = {}

        # Read NIFTI-1 header fields
        header["sizeof_hdr"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        if header["sizeof_hdr"] != 348:
            raise ValueError("Invalid NIFTI-1 file: incorrect header size.")

        header["data_type"] = f.read(10).decode("ascii").strip("\x00")
        header["db_name"] = f.read(18).decode("ascii").strip("\x00")
        header["extents"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        header["session_error"] = np.frombuffer(f.read(2), dtype=np.int16)[0]
        header["regular"] = f.read(1).decode("ascii")
        header["dim_info"] = f.read(1).decode("ascii")

        header["dim"] = np.frombuffer(f.read(16), dtype=np.int16)
        header["intent_p1"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["intent_p2"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["intent_p3"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["intent_code"] = np.frombuffer(f.read(2), dtype=np.int16)[0]
        header["datatype"] = np.frombuffer(f.read(2), dtype=np.int16)[0]
        header["bitpix"] = np.frombuffer(f.read(2), dtype=np.int16)[0]
        header["slice_start"] = np.frombuffer(f.read(2), dtype=np.int16)[0]
        header["pixdim"] = np.frombuffer(f.read(32), dtype=np.float32)
        header["vox_offset"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["scl_slope"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["scl_inter"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["slice_end"] = np.frombuffer(f.read(2), dtype=np.int16)[0]
        header["slice_code"] = np.frombuffer(f.read(1), dtype=np.uint8)[0]
        header["xyzt_units"] = np.frombuffer(f.read(1), dtype=np.uint8)[0]
        header["cal_max"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["cal_min"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["slice_duration"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["toffset"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["glmax"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        header["glmin"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        header["descrip"] = f.read(80).decode("ascii").strip("\x00")
        header["aux_file"] = f.read(24).decode("ascii").strip("\x00")
        header["qform_code"] = np.frombuffer(f.read(2), dtype=np.int16)[0]
        header["sform_code"] = np.frombuffer(f.read(2), dtype=np.int16)[0]
        header["quatern_b"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["quatern_c"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["quatern_d"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["qoffset_x"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["qoffset_y"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["qoffset_z"] = np.frombuffer(f.read(4), dtype=np.float32)[0]
        header["srow_x"] = np.frombuffer(f.read(16), dtype=np.float32)
        header["srow_y"] = np.frombuffer(f.read(16), dtype=np.float32)
        header["srow_z"] = np.frombuffer(f.read(16), dtype=np.float32)
        header["intent_name"] = f.read(16).decode("ascii").strip("\x00")
        header["magic"] = f.read(4).decode("ascii").strip("\x00")

        return header

    def _read_nifti2_header(self, f):
        f.seek(0)
        header = {}

        # Read NIFTI-2 header fields
        header["sizeof_hdr"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        if header["sizeof_hdr"] != 540:
            raise ValueError("Invalid NIFTI-2 file: incorrect header size.")

        f.seek(4)  # Skip sizeof_hdr
        header["magic"] = f.read(8).decode("ascii").strip("\x00")
        header["datatype"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        header["bitpix"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        header["dim"] = np.frombuffer(f.read(64), dtype=np.int64)
        header["intent_p1"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["intent_p2"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["intent_p3"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["pixdim"] = np.frombuffer(f.read(64), dtype=np.float64)
        header["vox_offset"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["scl_slope"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["scl_inter"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["cal_max"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["cal_min"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["slice_duration"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["toffset"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["descrip"] = f.read(80).decode("ascii").strip("\x00")
        header["aux_file"] = f.read(24).decode("ascii").strip("\x00")
        header["qform_code"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        header["sform_code"] = np.frombuffer(f.read(4), dtype=np.int32)[0]
        header["quatern_b"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["quatern_c"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["quatern_d"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["qoffset_x"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["qoffset_y"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["qoffset_z"] = np.frombuffer(f.read(8), dtype=np.float64)[0]
        header["srow_x"] = np.frombuffer(f.read(32), dtype=np.float64)
        header["srow_y"] = np.frombuffer(f.read(32), dtype=np.float64)
        header["srow_z"] = np.frombuffer(f.read(32), dtype=np.float64)

        return header

    def _get_numpy_dtype(self, datatype):
        # Mapping NIFTI datatype to NumPy dtype
        datatype_map = {
            2: np.uint8,     # 8-bit unsigned integer
            4: np.int16,     # 16-bit signed integer
            8: np.int32,     # 32-bit signed integer
            16: np.float32,  # 32-bit floating point
            64: np.float64,  # 64-bit floating point
            256: np.int8,    # 8-bit signed integer
            512: np.uint16,  # 16-bit unsigned integer
            768: np.uint32,  # 32-bit unsigned integer
            1024: np.int64,  # 64-bit signed integer
            1280: np.uint64, # 64-bit unsigned integer
        }
        dtype = datatype_map.get(datatype)
        if dtype is None:
            raise ValueError(f"Unsupported NIFTI datatype: {datatype}")
        return dtype


    def _read_data(self, f):
        # Seek to voxel offset specified in the header
        f.seek(int(self.header["vox_offset"]))

        # Determine NumPy dtype from datatype in header
        dtype = self._get_numpy_dtype(self.header["datatype"])

        # Determine the shape of the volume based on `dim`
        shape = tuple(self.header["dim"][1:self.header["dim"][0] + 1])

        # Read and reshape data
        data = np.frombuffer(f.read(), dtype=dtype).reshape(shape)

        # Apply scaling (if provided in the header)
        if self.header["scl_slope"] != 0:
            data = data * self.header["scl_slope"] + self.header["scl_inter"]

        return data


    def get_header(self):
        return self.header

    def get_data(self):
        return self.data


# Example Usage
if __name__ == "__main__":
    file_path = "example.nii"  # Replace with your NIFTI file path
    reader = NIFTIReader(file_path)
    reader.read()
    print("Header:", reader.get_header())
    print("Data shape:", reader.get_data().shape)
