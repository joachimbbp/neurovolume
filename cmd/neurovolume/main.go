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

	t1_vol.NormalizeVolume() //Time Elapsed:  5453341708
	fmt.Println("min ", t1_vol.MinVal, " max ", t1_vol.MaxVal)

	horizontal, coronal, sagittal := t1_vol.GetMiddleSlices()
	render.SaveAsImage(horizontal, "/Users/joachimpfefferkorn/repos/neurovolume/output/horizontal.PNG")
	render.SaveAsImage(coronal, "/Users/joachimpfefferkorn/repos/neurovolume/output/coronal.PNG")
	render.SaveAsImage(sagittal, "/Users/joachimpfefferkorn/repos/neurovolume/output/sagittal.PNG")

	//-------------//
	end_time := time.Now()
	println("Time Elapsed: ", end_time.Sub(start_time))
}
