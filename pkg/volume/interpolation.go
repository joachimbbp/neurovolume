package volume

import (
	"fmt"
	"strconv"
)

// Creates a volume based on
func DissolveToRealtime(input *Volume, outputFPS float32) Volume {
	var stretched Volume
	stretched.Data = make([][][][]float64, stretched.Shape[0])
	stretched.FPS = outputFPS
	frameDuration := int(outputFPS / 0.5)

	stretched.Shape = [4]int{
		input.Shape[0],
		input.Shape[1],
		input.Shape[2],
		int(frameDuration * input.Shape[3]),
	}
	fmt.Println("New Shape: ", stretched.Shape, " from: ", input.Shape)
	fmt.Println("Frame Duration: ", frameDuration)

	interframeIndex := 0 // frames since last OG frame

	//var offset int

	var aScalar float64
	var bScalar float64
	var aVox float64
	var bVox float64

	stretched.Data = make([][][][]float64, stretched.Shape[0])
	for x := range stretched.Data {
		stretched.Data[x] = make([][][]float64, stretched.Shape[1])
		for y := range stretched.Data[x] {
			stretched.Data[x][y] = make([][]float64, stretched.Shape[2])
			for z := range stretched.Data[x][y] {
				stretched.Data[x][y][z] = make([]float64, stretched.Shape[3])
				ogFrameIndex := 0 // Frames directly from the original volume, not interpolated
				for t := range stretched.Data[x][y][z] {
					if t%frameDuration == 0 { //This is an original frame
						// fmt.Println("x y z t: ", x, y, z, t, "	Og frame index:", ogFrameIndex)
						interframeIndex = 0
						//offset = t / int(stretched.FPS) * ogFrameIndex
						aVox = input.Data[x][y][z][ogFrameIndex]
						stretched.Data[x][y][z][t] = aVox

						if ogFrameIndex+1 <= input.Shape[3]-1 {
							bVox = input.Data[x][y][z][ogFrameIndex+1]
						}
						ogFrameIndex += 1

					} else { //This is an interframe
						interframeIndex += 1
						aScalar = float64((frameDuration - interframeIndex) / frameDuration)
						bScalar = float64(interframeIndex / frameDuration)
						stretched.Data[x][y][z][t] = (aVox * aScalar) + (bVox * bScalar)
					}

				}
			}
		}
	}

	stretched.FPS = outputFPS
	stretched.BaseName = input.BaseName + "_RealtimePlayback_" + strconv.FormatInt(int64(stretched.FPS), 10)
	stretched.DerivedFrom = "DissolveToRealtime"

	return stretched
}
