package main

import (
	"github.com/joachimbbp/neurovolume/pkg/open"
	"github.com/joachimbbp/neurovolume/pkg/utils"
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

	// niftiPath := os.Args[1]
	// outputFolder := os.Args[2]
	// utils.ClearOutputFolder(outputFolder)

	// vol := open.NIfTI1(niftiPath)
	// vol.NormalizeVolume(true)

	// vol.SaveMetadata(outputFolder)
	// vdb.WriteFromVolume(&vol, outputFolder, "")
	// fmt.Println("Read in Volume:")
	// vol.PrintVolumeInfo()

	//METHOD OF SUBTRACTION, hard coded example:

	// outputFolder := "/Users/joachimpfefferkorn/repos/neurovolume/output"

	// experimental := open.NIfTI1("/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii.gz")
	// experimental.NormalizeVolume(true)
	// control := open.NIfTI1("/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-rest_bold.nii.gz")
	// control.NormalizeVolume(true)

	// result := volume.SubtractAndClip(experimental, control)
	// result.NormalizeVolume(true)

	// result.SaveMetadata(outputFolder)
	// vdb.WriteFromVolume(&result, outputFolder, "")
	// experimental.SaveMetadata(outputFolder)
	// vdb.WriteFromVolume(&experimental, outputFolder, "")
	// control.SaveMetadata(outputFolder)
	// vdb.WriteFromVolume(&control, outputFolder, "")

	// result.SetMean() //for debugging only
	// result.PrintVolumeInfo()

	//interpolation testing:
	outputFolder := "/Users/joachimpfefferkorn/repos/neurovolume/output"
	utils.ClearOutputFolder(outputFolder)
	experimental := open.NIfTI1("/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii.gz")
	stretched := volume.DissolveToRealtime(&experimental, 24)
	stretched.NormalizeVolume(true)
	vdb.WriteFromVolume(&stretched, outputFolder, "")
	stretched.PrintVolumeInfo()
}
