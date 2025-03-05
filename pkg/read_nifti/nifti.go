package read_nifti //once dependencies are eliminated, rename to just nifti

import (
	"fmt"

	"github.com/KyungWonPark/nifti"
)

func Print_Dims() {
	println("Main function executing. ")
	t1_path := "/Users/joachimpfefferkorn/repos/neurovolume/media/openneuro/sub-01_T1w.nii"

	var hdr nifti.Nifti1Header
	hdr.LoadHeader(t1_path)

	var img nifti.Nifti1Image
	img.LoadImage(t1_path, true)

	fmt.Printf("dim: %v\n", hdr.Dim)
	fmt.Printf("img type: %T\n", img)
}
