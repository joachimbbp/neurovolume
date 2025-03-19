package main

import (
	"fmt"
	"time"

	"github.com/joachimbbp/neurovolume/pkg/render"
	"github.com/joachimbbp/neurovolume/pkg/vdb"
	"github.com/joachimbbp/neurovolume/pkg/volume"
)

// Test suite for anatomy scans (no temporal dimension)
func gackTesting() {
	start_time := time.Now()
	println("Main function executing")
	t1_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"
	//t1_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/mni/mni_icbm152_t1_tal_nlin_sym_09a.nii"
	//	bold_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_task-rest_bold.nii"
	//-------------//

	var t1_vol volume.Volume
	t1_vol.LoadDataFromNifti(t1_path) //Time Elapsed:  5178212542

	divider := 500
	t1_vol.SaveAsCSV("/Users/joachimpfefferkorn/repos/neurovolume/output/t1_Pre_Normalization.txt", divider)
	t1_vol.MinMax(true)
	t1_vol.SetMean()
	fmt.Printf("Vol minmax pre-normalization %0.2f to %0.2f, mean: %0.2f\n", t1_vol.MinVal, t1_vol.MaxVal, t1_vol.Mean)
	print("\n")
	t1_vol.NormalizeVolume() //Time Elapsed:  5453341708
	t1_vol.MinMax(true)
	t1_vol.SetMean()
	t1_vol.SaveAsCSV("/Users/joachimpfefferkorn/repos/neurovolume/output/t1_Post_normalization.txt", divider)
	fmt.Printf("Vol minmax post-normalization %0.2f to %0.2f, mean: %0.2f\n", t1_vol.MinVal, t1_vol.MaxVal, t1_vol.Mean)

	horizontal, coronal, sagittal := t1_vol.GetMiddleSlices()
	render.SaveAsImage(horizontal, "/Users/joachimpfefferkorn/repos/neurovolume/output/horizontal.PNG")
	render.SaveAsImage(coronal, "/Users/joachimpfefferkorn/repos/neurovolume/output/coronal.PNG")
	render.SaveAsImage(sagittal, "/Users/joachimpfefferkorn/repos/neurovolume/output/sagittal.PNG")

	vdb.WriteFromVolume(&t1_vol)
	//-------------//
	end_time := time.Now()
	println("Time Elapsed: ", end_time.Sub(start_time))
}

func main() {
	t1_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"
	var t1_vol volume.Volume
	t1_vol.LoadDataFromNifti(t1_path)
	println("basename: ", t1_vol.BaseName)
}
