package main

import (
	"fmt"

	"github.com/joachimbbp/neurovolume/pkg/open"
	"github.com/joachimbbp/neurovolume/pkg/render"
	"github.com/joachimbbp/neurovolume/pkg/utils"
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

	outputFolder := "/Users/joachimpfefferkorn/repos/neurovolume/output"
	utils.ClearOutputFolder(outputFolder)

	bold := open.NIfTI1("/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii.gz")
	bold.NormalizeVolume(true)

	anat := open.NIfTI1("/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_T1w.nii.gz")
	anat.NormalizeVolume(true)

	transformedBold := volume.CombineAnatAndBold(bold, anat)

	fmt.Println("Rendering")
	tmid, _, _ := render.GetMiddleSlices(&transformedBold)
	render.SaveAsImage(tmid, outputFolder+"/"+"transfomredBold.png")
	fmt.Println("Done")

	/* // Default
	// niftiPath := os.Args[1]
	// outputFolder := os.Args[2]
	// //utils.ClearOutputFolder(outputFolder)

	// grid := open.NIfTI1(niftiPath)
	// grid.NormalizeVolume(true)

	// grid.SaveMetadata(outputFolder)
	// vdb.WriteFromVolume(&grid, outputFolder, "")
	// fmt.Println("Read in Grid:")
	// grid.PrintVolumeInfo()
	*/

	/* //--------Method of Subtraction with Interpolation: --------------
	// outputFolder := "/Users/joachimpfefferkorn/repos/neurovolume/output"
	// utils.ClearOutputFolder(outputFolder)

	// experimental := open.NIfTI1("/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-emotionalfaces_run-1_bold.nii.gz")
	// experimental.NormalizeVolume(true)

	// control := open.NIfTI1("/Users/joachimpfefferkorn/repos/neurovolume/media/sub-01_task-rest_bold.nii.gz")
	// control.NormalizeVolume(true)

	// mos := volume.SubtractAndClip(experimental, control)
	// mos.NormalizeVolume(true)

	// stretched := volume.DissolveToRealtime(&mos, 24)
	// stretched.NormalizeVolume(true)

	// vdb.WriteFromVolume(&mos, outputFolder, "")
	// vdb.WriteFromVolume(&stretched, outputFolder, "")
	// stretched.PrintVolumeInfo()
	*/
}
