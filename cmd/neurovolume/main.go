package main

import (
	"fmt"
	"math"

	"github.com/joachimbbp/neurovolume/pkg/nifti"
)

func main() {
	println("Main function executing. ")
	t1_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"
	//	bold_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_task-rest_bold.nii"

	var t1_img nifti.Nifti1Image // Pointer to struct
	t1_img.LoadImage(t1_path, true)
	// slice := t1_img.GetSlice(1, 1)
	// fmt.Println(minmax(slice))
	vol := t1_img.BuildVolume()
	fmt.Println(vol.Shape())
}

func minmax(array [][]float32) (float32, float32) {
	//would be cool for this to be n-dimensional!
	min := float32(math.MaxFloat32)
	max := float32(-math.MaxFloat32)
	for _, row := range array {
		for _, val := range row {
			if val < min {
				min = val
			}
			if val > max {
				max = val
			}
		}
	}
	return min, max
}
