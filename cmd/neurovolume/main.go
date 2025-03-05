package main

import (
	"github.com/joachimbbp/neurovolume/pkg/audio"
	"github.com/joachimbbp/neurovolume/pkg/read_nifti"
)

func main() {
	println("Main function executing. ")
	read_nifti.Print_Dims()
	audio.Debug()
}
