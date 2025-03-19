package main

import (
	"github.com/joachimbbp/neurovolume/pkg/vdb"
	"github.com/joachimbbp/neurovolume/pkg/volume"
)

// Test suite for anatomy scans (no temporal dimension)

func main() {
	bold_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold"
	//bold_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii"

	var bold_vol volume.Volume
	bold_vol.LoadDataFromNifti(bold_path)

	bold_vol.NormalizeVolume() //Time Elapsed:  5453341708
	// t1_vol.MinMax(true)
	//t1_vol.SetMean() //I need to set the mean for it to worK???????
	//Lets try it with no mean!
	//NOPe, sans mean is fine. What on earth went wrong in the last re-factor????

	vdb.WriteFromVolume(&bold_vol, "/Users/joachimpfefferkorn/repos/neurovolume/output", "buffer_moved")
}
