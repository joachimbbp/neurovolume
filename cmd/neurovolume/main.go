package main

import (
	"fmt"

	"github.com/KyungWonPark/nifti"
)

func main() {
	println("Main function executing. ")
	t1_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"

	var hdr nifti.Nifti1Header
	hdr.LoadHeader(t1_path)

	fmt.Printf("dim: %v", hdr.Dim)
}
