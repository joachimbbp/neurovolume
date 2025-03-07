package main

import (
	"fmt"

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
	vol := t1_img.BuildVolume(true)
	fmt.Println(vol.Shape())
}
