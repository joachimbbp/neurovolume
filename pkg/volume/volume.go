package volume

import (
	"math"

	"github.com/joachimbbp/neurovolume/pkg/nifti"
)

type Volume struct {
	Data       [][][][]float64
	Shape      [4]int
	MinVal     float64
	MaxVal     float64
	Normalized bool
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
	vol.Shape = [4]int{int(img.Nx), int(img.Ny), int(img.Nz), int(img.Nt)}

	//Still not sure *exactly* how this loop works
	vol.Data = make([][][][]float64, vol.Shape[0])
	for x := range vol.Data {
		vol.Data[x] = make([][][]float64, vol.Shape[1])
		for y := range vol.Data[x] {
			vol.Data[x][y] = make([][]float64, vol.Shape[2])
			for z := range vol.Data[x][y] {
				vol.Data[x][y][z] = make([]float64, vol.Shape[3])
				for t := range vol.Data[x][y][z] {
					vol.Data[x][y][z][t] = float64(img.GetAt(uint32(x), uint32(y), uint32(z), uint32(t)))
				}
			}
		}
	}
	vol.Normalized = false
}

func (vol *Volume) NormalizeVolume() {
	vol.MinMax()
	for x := 0; x < vol.Shape[0]; x++ {
		for y := 0; y < vol.Shape[1]; y++ {
			for z := 0; z < vol.Shape[2]; z++ {
				for t := 0; t < vol.Shape[3]; t++ {
					vol.Data[x][y][z][t] = vol.Data[x][y][z][t] - vol.MinVal/(vol.MinVal-vol.MaxVal)

				}
			}
		}
	}
	vol.Normalized = true
}

// Middle of Horizontal Plane for now
func (vol *Volume) GetMiddleSlices() ([][]float64, [][]float64, [][]float64) {
	t := vol.Shape[3] / 2

	horizontal := make([][]float64, vol.Shape[0])
	sagittal := make([][]float64, vol.Shape[1])
	coronal := make([][]float64, vol.Shape[2])
	//Might switch the names

	println("making horizontal slice")
	z := vol.Shape[2] / 2
	for x := range horizontal {
		horizontal[x] = make([]float64, vol.Shape[1])
		for y := range horizontal[x] {
			horizontal[x][y] = vol.Data[x][y][z][t]
		}
	}

	println("making sagittal slice")
	x := vol.Shape[0] / 2
	for y := range sagittal {
		sagittal[y] = make([]float64, vol.Shape[2])
		for z := range sagittal[y] {
			sagittal[y][z] = vol.Data[x][y][z][t]
		}
	}
	println("making coronal slice")
	y := vol.Shape[1] / 2
	for z := range coronal {
		coronal[z] = make([]float64, vol.Shape[0])
		for x := range coronal[z] {
			coronal[z][x] = vol.Data[x][y][z][t]
		}
	}

	return horizontal, coronal, sagittal
}

//------------

// Gets the Minimum and Maximum value from the volume Data
func (vol *Volume) MinMax() {
	var min_val, max_val = math.MaxFloat64, -math.MaxFloat64

	shape := getShape4d(vol.Data)
	for x := 0; x < shape[0]; x++ {
		for y := 0; y < shape[1]; y++ {
			for z := 0; z < shape[2]; z++ {
				for t := 0; t < shape[3]; t++ {
					val := vol.Data[x][y][z][t]
					if val < min_val {
						min_val = val
					}
					if val > max_val {
						max_val = val
					}
				}
			}
		}
	}
	vol.MinVal = min_val
	vol.MaxVal = max_val

}

// Sets the Shape for the Volume
func (vol *Volume) GetShape() {
	//Just a wrapper around the garbage GPT code
	vol.Shape = getShape4d(vol.Data)
}

// ChatGPT copypasta and it doesn't look great (but it works)
func getShape4d(data [][][][]float64) [4]int {
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
