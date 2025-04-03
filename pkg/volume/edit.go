package volume

import "fmt"

func Subtract(experimental Volume, control Volume) Volume {
	// if control.Shape != experimental.Shape {
	// 	if control.Shape[0] == experimental.Shape[0] && control.Shape[1] == experimental.Shape[1] && control.Shape[2] == experimental.Shape[2] {
	// 		fmt.Println("Spatial dimensions are the same")
	// 		if control.Shape[3] > experimental.Shape[3] {
	// 			control = TrimFrames(control, experimental.Shape[3])
	// 		} else{}
	// 	}

	//OOOF terrible control flow, but you get the idea TODO refactor above
		panic(fmt.Sprintf("Control Shape, %v, incompatible with Experimental Shape %v", control.Shape, experimental.Shape))
	}
	var result Volume
	for x := range experimental.Data {
		result.Data[x] = make([][][]float64, experimental.Shape[1])
		for y := range experimental.Data[x] {
			result.Data[x][y] = make([][]float64, experimental.Shape[2])
			for z := range experimental.Data[x][y] {
				result.Data[x][y][z] = make([]float64, experimental.Shape[3])
				for t := range experimental.Data[x][y][z] {
					result.Data[x][y][z][t] = experimental.Data[x][y][z][t] - control.Data[x][y][z][t]
				}
			}
		}
	}
	return result
}

func TrimFrames(input Volume, length int) Volume {
	var output Volume
	if length > input.Shape[3] {
		fmt.Println("Length ", length, " is greater than number of frames ", input.Shape[3], "\nReturning original volume")
		return input
	}

	for x := range input.Data {
		output.Data[x] = make([][][]float64, input.Shape[1])
		for y := range input.Data[x] {
			output.Data[x][y] = make([][]float64, input.Shape[2])
			for z := range input.Data[x][y] {
				output.Data[x][y][z] = make([]float64, input.Shape[3])
				for t := range length {
					output.Data[x][y][z][t] = input.Data[x][y][z][t]
				}
			}
		}
	}
	return input
}
