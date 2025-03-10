package main

import (
	"fmt"
	"time"

	"github.com/joachimbbp/neurovolume/pkg/render"
	"github.com/joachimbbp/neurovolume/pkg/volume"
)

func main() {
	start_time := time.Now()
	println("Main function executing")
	t1_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"
	//	bold_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_task-rest_bold.nii"
	//-------------//

	var t1_vol volume.Volume
	t1_vol.LoadDataFromNifti(t1_path) //Time Elapsed:  5178212542

	// for x := 0; x < t1_vol.Shape[0]; x++ {
	// 	for y := 0; y < t1_vol.Shape[1]; y++ {
	// 		for z := 0; z < t1_vol.Shape[2]; z++ {
	// 			for t := 0; t < t1_vol.Shape[3]; t++ {
	// 				if t1_vol.Data[x][y][z][t] > 0.0 && t1_vol.Data[x][y][z][t] != 32768 { //again, that number
	// 					fmt.Println("t1 value foudn: ", t1_vol.Data[x][y][z][t], " at ", x, y, z, t)
	// 				}
	// 			}
	// 		}
	// 	}
	// } //This gives us some real numbers... hmm...
	//Issue is thus in the min max!

	fmt.Println("min ", t1_vol.MinVal, " max ", t1_vol.MaxVal)
	t1_vol.NormalizeVolume() //Time Elapsed:  5453341708
	fmt.Println("min ", t1_vol.MinVal, " max ", t1_vol.MaxVal)
	slice := t1_vol.GetSlice()
	render.SaveAsImage(slice, "/Users/joachimpfefferkorn/repos/neurovolume/output/render.PNG")
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
