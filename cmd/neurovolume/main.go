package main

import (
	"os"

	"github.com/joachimbbp/neurovolume/pkg/vdb"
	"github.com/joachimbbp/neurovolume/pkg/volume"
)

func main() {
	//go run main.go /Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii /Users/joachimpfefferkorn/repos/neurovolume/output
	//go run main.go /Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold /Users/joachimpfefferkorn/repos/neurovolume/output
	niftiPath := os.Args[1]
	outputFolder := os.Args[2]

	var vol volume.Volume
	vol.LoadDataFromNifti(niftiPath)

	vol.NormalizeVolume()
	vdb.WriteFromVolume(&vol, outputFolder, "")
}
