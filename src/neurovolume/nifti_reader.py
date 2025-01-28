import struct

#Very much WIP
#lets see how far we can go without using numpy

#relevant docs:
# https://docs.python.org/3/library/struct.html
# https://brainder.org/2012/09/23/the-nifti-file-format/

nifti_file_path = "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"

with open (nifti_file_path, 'rb') as nf:
    def read_hdr_field(offset, size, f_string, file=nf):
        '''
        offset and size are in bytes
        '''
        file.seek(offset)
        data = file.read(size)
        return struct.unpack(f_string, data)
    
    header_size = read_hdr_field(0, 4, '@1i')[0]
    bitpix = read_hdr_field(72, 4, '@1i')[0]
    datatype = read_hdr_field(70, 4, '@1i')[0]
    dimensions = read_hdr_field(40, 16, '@8h')
    vox_offset = read_hdr_field(108, 4, '@1f') #Float for ANALYZE filetype compatibility

    print(f'Header Size: {header_size}\nBitpix: {bitpix}\nDatatype: {datatype}\nVox Offset: {vox_offset}\ndimensions: {dimensions}')


