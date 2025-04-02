package main

import (
	"fmt"
	"os"

	"github.com/joachimbbp/neurovolume/pkg/vdb"
	"github.com/joachimbbp/neurovolume/pkg/volume"
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

	var img volume.Nifti1Image
	img.LoadImage(niftiPath)
	fmt.Println("Loaded ", img.Filepath, "\nHeader vals:\n	", img.Header) //TODO pretty print functions for debugging

	vol := img.BuildVolume()
	fmt.Println("volume shape: ", vol.Shape)
	vol.NormalizeVolume()

	outputFolder := os.Args[2]
	vol.SaveMetadata(outputFolder)
	vdb.WriteFromVolume(&vol, outputFolder, "")

}
