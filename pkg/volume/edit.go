package volume

import "fmt"

func Subtract(experimental Volume, control Volume) Volume {
	if experimental.Shape[3] != control.Shape[3] {
		fmt.Printf("Mismatched Frame Lengths: experimental: %v control: %v\n", experimental.Shape[3], control.Shape[3])
		if control.Shape[0] == experimental.Shape[0] && control.Shape[1] == experimental.Shape[1] && control.Shape[2] == experimental.Shape[2] {
			fmt.Println("Spatial dimensions are the same. Experimental: ", experimental.Shape, "Control: ", control.Shape)
			if experimental.Shape[3] < control.Shape[3] {
				fmt.Println("control time longer than experimental time")
				control = TrimFrames(control, experimental.Shape[3])
			} else if control.Shape[3] < experimental.Shape[3] {
				fmt.Println("experimental time is longer than control time")
				experimental = TrimFrames(experimental, control.Shape[3])
			}
		}
	} else {
		fmt.Println("Experimental and Control are of equal length. Experimental: ", experimental.Shape, "Control: ", control.Shape)
	}

	var result Volume
	result.Shape = experimental.Shape
	result.Data = make([][][][]float64, result.Shape[0])
	for x := range experimental.Data {
		result.Data[x] = make([][][]float64, experimental.Shape[1])
		for y := range experimental.Data[x] {
			result.Data[x][y] = make([][]float64, experimental.Shape[2])
			for z := range experimental.Data[x][y] {
				result.Data[x][y][z] = make([]float64, experimental.Shape[3])
				for t := range experimental.Data[x][y][z] {
					result.Data[x][y][z][t] = experimental.Data[x][y][z][t] - control.Data[x][y][z][t]
					if result.Data[x][y][z][t] < 0.0 { //clip at zero
						//fmt.Println("Clipping: ", result.Data[x][y][z][t])
						result.Data[x][y][z][t] = 0.0
					}
				}
			}
		}
	}
	result.DerivedFrom = "Method of Subtraction"

	result.BaseName = experimental.BaseName + "_MINUS_" + control.BaseName
	return result
}

func TrimFrames(input Volume, length int) Volume {
	fmt.Println("Trimming frames. Length:", length, " input shape: ", input.Shape)

	if length > input.Shape[3] {
		fmt.Println("Length ", length, " is greater than number of frames ", input.Shape[3], "\nReturning original volume")
		return input
	}

	var output Volume
	output.Shape = [4]int{
		input.Shape[0],
		input.Shape[1],
		input.Shape[2],
		length,
	}
	fmt.Println("Output shape; ", output.Shape)
	output.Data = make([][][][]float64, output.Shape[0])
	for x := range input.Data {
		// fmt.Println("x", x)
		output.Data[x] = make([][][]float64, input.Shape[1])
		for y := range input.Data[x] {
			// fmt.Println("y", y)

			output.Data[x][y] = make([][]float64, input.Shape[2])
			for z := range input.Data[x][y] {
				// fmt.Println("z", z)

				output.Data[x][y][z] = make([]float64, input.Shape[3])
				for t := range length {
					// fmt.Println(t)
					output.Data[x][y][z][t] = input.Data[x][y][z][t]
				}
			}
		}
	}

	output.BaseName = input.BaseName + "_TRIMMED"
	output.DerivedFrom = "Frame Trimming"
	output.NormalizeVolume(true)
	output.SetMean() //For debugging only
	fmt.Println("New Volume from Frame Trimming info:")
	output.PrintVolumeInfo()

	return output
}
