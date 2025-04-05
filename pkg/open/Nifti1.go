/*
- Maybe Nifti1 is its own package? idk
- Step one, load image
- Step two, build volume with that image
*/

package open

import (
	"encoding/binary"
	"fmt"
	"io"
	"math"

	"github.com/joachimbbp/neurovolume/pkg/utils"
	"github.com/joachimbbp/neurovolume/pkg/volume"
)

type NIfTI1Header struct {
	//from Heng Huang's repo

	/**** 348 bytes total ****/
	SizeofHdr    int32    /*!< MUST be 348           */ /* int32 sizeof_hdr;      */
	DataType     [10]byte /*!< ++UNUSED++            */ /* char data_type[10];  */
	DbName       [18]byte /*!< ++UNUSED++            */ /* char db_name[18];    */
	Extents      int32    /*!< ++UNUSED++            */ /* int32 extents;         */
	SessionError int16    /*!< ++UNUSED++            */ /* short session_error; */
	Regular      byte     /*!< ++UNUSED++            */ /* char regular;        */
	DimInfo      byte     /*!< MRI slice ordering.   */ /* char hkey_un0;       */

	/*--- was image_dimension substruct ---*/
	Dim      [8]int16 /*!< Data array dimensions.*/ /* short dim[8];        */
	IntentP1 float32  /*!< 1st intent parameter. */ /* short unused8;       */
	/* short unused9;       */
	IntentP2 float32 /*!< 2nd intent parameter. */ /* short unused10;      */
	/* short unused11;      */
	IntentP3 float32 /*!< 3rd intent parameter. */ /* short unused12;      */
	/* short unused13;      */
	IntentCode    int16      /*!< NIFTI_INTENT_* code.  */ /* short unused14;      */
	Datatype      int16      /*!< Defines data type!    */ /* short datatype;      */
	Bitpix        int16      /*!< Number bits/voxel.    */ /* short bitpix;        */
	SliceStart    int16      /*!< First slice index.    */ /* short dim_un0;       */
	Pixdim        [8]float32 /*!< Grid spacings.        */ /* float32 pixdim[8];     */
	VoxOffset     float32    /*!< Offset into .nii file */ /* float32 vox_offset;    */
	SclSlope      float32    /*!< Data scaling: slope.  */ /* float32 funused1;      */
	SclInter      float32    /*!< Data scaling: offset. */ /* float32 funused2;      */
	SliceEnd      int16      /*!< Last slice index.     */ /* float32 funused3;      */
	SliceCode     byte       /*!< Slice timing order.   */
	XyztUnits     byte       /*!< Units of pixdim[1..4] */
	CalMax        float32    /*!< Max display intensity */ /* float32 cal_max;       */
	CalMin        float32    /*!< Min display intensity */ /* float32 cal_min;       */
	SliceDuration float32    /*!< Time for 1 slice.     */ /* float32 compressed;    */
	Toffset       float32    /*!< Time axis shift.      */ /* float32 verified;      */
	Glmax         int32      /*!< ++UNUSED++            */ /* int32 glmax;           */
	Glmin         int32      /*!< ++UNUSED++            */ /* int32 glmin;           */

	/*--- was data_history substruct ---*/
	Descrip [80]byte /*!< any text you like.    */ /* char descrip[80];    */
	AuxFile [24]byte /*!< auxiliary filename.   */ /* char aux_file[24];   */

	QformCode int16 /*!< NIFTI_XFORM_* code.   */ /*-- all ANALYZE 7.5 ---*/
	SformCode int16 /*!< NIFTI_XFORM_* code.   */ /*   fields below here  */
	/*   are replaced       */
	QuaternB float32 /*!< Quaternion b param.   */
	QuaternC float32 /*!< Quaternion c param.   */
	QuaternD float32 /*!< Quaternion d param.   */
	QoffsetX float32 /*!< Quaternion x shift.   */
	QoffsetY float32 /*!< Quaternion y shift.   */
	QoffsetZ float32 /*!< Quaternion z shift.   */

	SrowX [4]float32 /*!< 1st row affine transform.   */
	SrowY [4]float32 /*!< 2nd row affine transform.   */
	SrowZ [4]float32 /*!< 3rd row affine transform.   */

	IntentName [16]byte /*!< 'name' or meaning of data.  */

	Magic [4]byte /*!< MUST be "ni1\0" or "n+1\0". */
}

func (header *NIfTI1Header) loadHeader(filepath string) {
	fmt.Println("Loading Header")
	//Right now gzipOpen is called twice, might not be the most performant
	_, reader, gErr := GZipOrAnything(filepath)
	if gErr != nil {
		panic(fmt.Sprintf("Error unzipping NIfTI1 Header:\n\t%s", gErr))
	}
	defer reader.Close()
	bErr := binary.Read(reader, binary.LittleEndian, header)
	if bErr != nil {
		panic(fmt.Sprintf("Error Reading Binary NIfTI1 Header:\n\t%s", bErr))
	}
}

// Custom NIfTI1 Image for Neurovolume (probably more minimal than other "img" types)
type NIfT1Image struct {
	Data          [][][][]float64
	Header        NIfTI1Header
	Filepath      string
	bytesPerVoxel uint32
	byte2floatF   func([]byte) float32
	rawData       []byte
	fromGZ        bool
}

func (img *NIfT1Image) loadImage(filepath string) {
	fmt.Println("Loading Image")
	img.Filepath = filepath
	var header NIfTI1Header
	header.loadHeader(filepath)
	img.Header = header
	img.bytesPerVoxel = uint32(img.Header.Bitpix) / 8
	switch img.bytesPerVoxel {
	case 1:
		img.byte2floatF = func(b []byte) float32 {
			return float32(b[0])
		}
	case 2:
		img.byte2floatF = func(b []byte) float32 {
			v := int16(binary.LittleEndian.Uint16(b))
			return float32(v)
		}
	case 4:
		img.byte2floatF = func(b []byte) float32 {
			v := binary.LittleEndian.Uint32(b)
			return math.Float32frombits(v)
		}
	case 8:
		img.byte2floatF = func(b []byte) float32 {
			v := binary.LittleEndian.Uint64(b)
			return float32(math.Float64frombits(v))
		}
	default:
		panic("(img *Nifti1Image) byte2float only supports 8, 16, 32, and 64-bit formats")
	}

	var data []byte
	var err error
	isGZ, reader, err := GZipOrAnything(filepath)
	img.fromGZ = isGZ
	if err != nil {
		fmt.Println("open data error")
		return
	}
	defer reader.Close()

	data, err = io.ReadAll(reader)
	if err != nil {
		fmt.Println("read data error")
		return
	}
	img.rawData = data[uint(img.Header.VoxOffset):len(data)]

}

func NIfTI1(filepath string) volume.Volume {
	var img NIfT1Image
	img.loadImage(filepath)
	var vol volume.Volume

	if img.Header.Pixdim[4] == 0 {
		vol.FPS = 0
	} else {
		vol.FPS = 1 / img.Header.Pixdim[4] //Pixdim[4] being seconds per frame
	}

	vol.Shape = [4]int{
		int(img.Header.Dim[1]),
		int(img.Header.Dim[2]),
		int(img.Header.Dim[3]),
		int(img.Header.Dim[4]),
	}
	vol.BaseName = utils.GetBasename(img.Filepath)
	switch img.Header.Datatype {
	case 0:
		vol.ScanDatatype = "unknown"
	case 1:
		vol.ScanDatatype = "bool"
	case 2:
		vol.ScanDatatype = "unsigned char"
	case 4:
		vol.ScanDatatype = "signed short"
	case 8:
		vol.ScanDatatype = "signed int"
	case 16:
		vol.ScanDatatype = "float"
	case 32:
		vol.ScanDatatype = "complex"
	case 64:
		vol.ScanDatatype = "double"
	case 128:
		vol.ScanDatatype = "rgb"
	case 255:
		vol.ScanDatatype = "all"
	case 256:
		vol.ScanDatatype = "signed char"
	case 512:
		vol.ScanDatatype = "unsigned short"
	case 768:
		vol.ScanDatatype = "unsigned int"
	case 1024:
		vol.ScanDatatype = "long long"
	case 1280:
		vol.ScanDatatype = "unsigned long long"
	case 1536:
		vol.ScanDatatype = "long double"
	case 1792:
		vol.ScanDatatype = "double pair"
	case 2048:
		vol.ScanDatatype = "long double pair"
	case 2304:
		vol.ScanDatatype = "rgba"
	default:
		vol.ScanDatatype = "unknown"
	}
	vol.Data = make([][][][]float64, vol.Shape[0])
	for x := range vol.Data {
		vol.Data[x] = make([][][]float64, vol.Shape[1])
		for y := range vol.Data[x] {
			vol.Data[x][y] = make([][]float64, vol.Shape[2])
			for z := range vol.Data[x][y] {
				vol.Data[x][y][z] = make([]float64, vol.Shape[3])
				for t := range vol.Data[x][y][z] {
					vol.Data[x][y][z][t] = float64(img.getAt(x, y, z, t, vol.Shape))
				}
			}
		}
	}
	vol.Normalized = false
	if img.fromGZ {
		vol.DerivedFrom = "NIfTI1 GZ"
	} else {
		vol.DerivedFrom = "NIfTI1"
	}
	return vol
}

func (img *NIfT1Image) getAt(x int, y int, z int, t int, shape [4]int) float32 {
	nx := shape[0]
	ny := shape[1]
	nz := shape[2]
	index := uint64(t*nx*ny*nz + z*nx*ny + y*nx + x)
	rawVal := img.byte2floatF(img.rawData[index*uint64(img.bytesPerVoxel) : (index+1)*uint64(img.bytesPerVoxel)])
	if img.Header.SclSlope != 0 {
		return img.Header.SclSlope*rawVal + img.Header.SclInter
	} else {
		return rawVal
	}
}
