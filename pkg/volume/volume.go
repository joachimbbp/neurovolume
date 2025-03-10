package volume

import (
	"github.com/joachimbbp/neurovolume/pkg/nifti"
)

type Volume struct {
	Data [][][][]float64
	//Modifier Stack
	//VDB
	// Audio
	//CAN I LEAVE SOME OF THESE BLANK IF THEY DON'T EXIST?
	/*
	   	Don't get caught in inheritance hell! Don't inherit anything from this! Why would you? Every scan is a 4D vol (anat is just 1 frame!)

	   This Volume struct exists only because the computer needs to store a few things:
	   - The Raw Data in Scanner Space (will be modified by transforms and stuff, read from the NIfTI file, before written here)
	   - The Modifier Stack
	   - The output VDB
	*/
}

func (vol *Volume) LoadDataFromNifti(filepath string) {
	//TODO eliminate nifti and Gorgonia dependency
	var img nifti.Nifti1Image //I hate that I have to bring this whole thing in! Later it will directly plug into the Volume type
	img.LoadImage(filepath, true)
	shape := [4]int{int(img.Nx), int(img.Ny), int(img.Nz), int(img.Nt)}

	//Normalization has to come *after* you build the volume as you won't know the min/max!

	//Still not sure *exactly* how this works
	vol.Data = make([][][][]float64, shape[0])
	for x := range vol.Data {
		vol.Data[x] = make([][][]float64, shape[1])
		for y := range vol.Data[x] {
			vol.Data[x][y] = make([][]float64, shape[2])
			for z := range vol.Data[x][y] {
				vol.Data[x][y][z] = make([]float64, shape[3])
				for t := range vol.Data[x][y][z] {
					vol.Data[x][y][z][t] = float64(img.GetAt(uint32(x), uint32(y), uint32(z), uint32(t)))
				}
			}
		}
	}
}

// Returns an empty, 4D Tensor to populate with fMRI or MRI data

// Normalizes a 4D Volume (probably can move this and GetShape4d into an internal thing)
// func GetNormalizationData4D(volume [][][][]float64) (float64, float64) {
// 	//TODO make this n-dimensional
// 	var min_val float64 = math.MaxFloat32
// 	var max_val float64 = -math.MaxFloat32
// 	shape := GetShape4d(volume)
// 	for x := 0; x < shape[0]; x++ {
// 		for y := 0; y < shape[1]; y++ {
// 			for z := 0; z < shape[2]; z++ {
// 				for t := 0; t < shape[3]; t++ {
// 					val := float64(img.GetAt(uint32(x), uint32(y), uint32(z), uint32(t)))
// 					if val < min_val {
// 						min_val = val
// 					}
// 					if val > max_val {
// 						max_val = val
// 					}
// 				}
// 			}
// 		}
// 	}
// 	return min_val, max_val
// }

// ChatGPT copypasta and it doesn't look great
func GetShape4d(data [][][][]float64) [4]int {
	return [4]int{
		len(data),
		func() int {
			if len(data) > 0 {
				return len(data[0])
			} else {
				return 0
			}
		}(),
		func() int {
			if len(data) > 0 && len(data[0]) > 0 {
				return len(data[0][0])
			} else {
				return 0
			}
		}(),
		func() int {
			if len(data) > 0 && len(data[0]) > 0 && len(data[0][0]) > 0 {
				return len(data[0][0][0])
			} else {
				return 0
			}
		}(),
	}
}
