package volume

import "fmt"

// Creates a volume based on
func DissolveToRealtime(input *Volume, outputFPS float32) Volume {
	var stretched Volume
	stretched.Data = make([][][][]float64, stretched.Shape[0])

	frameDuration := int(outputFPS / 0.5)

	stretched.Shape = [4]int{
		input.Shape[0],
		input.Shape[1],
		input.Shape[2],
		int(frameDuration * input.Shape[3]),
	}
	fmt.Println("New Shape: ", stretched.Shape, " from: ", input.Shape)

	for x := range stretched.Data {
		stretched.Data[x] = make([][][]float64, stretched.Shape[1])
		for y := range stretched.Data[x] {
			stretched.Data[x][y] = make([][]float64, stretched.Shape[2])
			for z := range stretched.Data[x][y] {
				stretched.Data[x][y][z] = make([]float64, stretched.Shape[3])
				for t := range stretched.Data[x][y][z] {
					print(t)
					//stretched.Data[x][y][z][t] = float64(img.getAt(x, y, z, t, vol.Shape))

				}
			}
		}
	}
	return stretched
}
