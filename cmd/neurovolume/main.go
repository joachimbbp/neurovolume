package main

import (
	"fmt"
	"os"

	"github.com/joachimbbp/neurovolume/pkg/open"
	"github.com/joachimbbp/neurovolume/pkg/vdb"
)

func main() {
	/*
	   .nii
	   go run main.go /Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii /Users/joachimpfefferkorn/repos/neurovolume/output
	   go run main.go /Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold /Users/joachimpfefferkorn/repos/neurovolume/output

	   .gz
	   go run main.go /Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii.gz /Users/joachimpfefferkorn/repos/neurovolume/output
	   go run main.go /Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii.gz /Users/joachimpfefferkorn/repos/neurovolume/output

	*/

	niftiPath := os.Args[1]
	vol := open.NIfTI1(niftiPath)
	fmt.Println(vol.BaseName, " loaded, shape: ", vol.Shape)
	vol.NormalizeVolume()
	fmt.Println("Normalized: ", vol.Normalized)

	outputFolder := os.Args[2]
	vol.SaveMetadata(outputFolder)
	vdb.WriteFromVolume(&vol, outputFolder, "")

}
