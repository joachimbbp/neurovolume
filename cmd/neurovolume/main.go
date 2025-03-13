package main

import (
	"fmt"
	"time"

	"github.com/joachimbbp/neurovolume/pkg/vdb"
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
	t1_vol.NormalizeVolume()          //Time Elapsed:  5453341708

	// horizontal, coronal, sagittal := t1_vol.GetMiddleSlices()
	// render.SaveAsImage(horizontal, "/Users/joachimpfefferkorn/repos/neurovolume/output/horizontal.PNG")
	// render.SaveAsImage(coronal, "/Users/joachimpfefferkorn/repos/neurovolume/output/coronal.PNG")
	// render.SaveAsImage(sagittal, "/Users/joachimpfefferkorn/repos/neurovolume/output/sagittal.PNG")

	fmt.Println("Normalized? ", t1_vol.Normalized)
	fmt.Println("Minmax: ", t1_vol.MinVal, t1_vol.MaxVal)
	fmt.Println("random data index: ", t1_vol.Data[100][50][50][0])
	vdb.WriteFromVolume(&t1_vol)

	//-------------//
	end_time := time.Now()
	println("Time Elapsed: ", end_time.Sub(start_time))
}
