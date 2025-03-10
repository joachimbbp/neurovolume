package main

import (
	"time"

	"github.com/joachimbbp/neurovolume/pkg/volume"
)

func main() {
	start_time := time.Now()
	println("Main function executing")
	t1_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"
	//	bold_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_task-rest_bold.nii"
	//-------------//

	var t1_vol volume.Volume
	t1_vol.LoadDataFromNifti(t1_path)

	//slice := t1_vol.GetSlice(1, 1)
	//fmt.Println(minmax(slice))
	//--------------//
	// var t1_img nifti.Nifti1Image // Pointer to struct
	// t1_img.LoadImage(t1_path, true)
	// // slice := t1_img.GetSlice(1, 1)
	// // fmt.Println(minmax(slice))
	// vol := t1_img.BuildVolume(true)
	// fmt.Println(vol.Shape())

	//-------------//
	end_time := time.Now()
	println("Time Elapsed: ", end_time.Sub(start_time))
}
