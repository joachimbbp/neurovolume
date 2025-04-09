package render

import (
	"fmt"
	"image"
	"image/color"
	"image/png"
	"log"
	"math"
	"os"

	"github.com/joachimbbp/neurovolume/pkg/volume"
)

// GPT copypasta:
// normalizeData8Bit scales the float64 values to the range [0, 255]
func normalizeData8Bit(data [][]float64) [][]uint8 {
	min, max := math.MaxFloat64, -math.MaxFloat64
	height, width := len(data), len(data[0])

	// Find min and max values
	for _, row := range data {
		for _, val := range row {
			if val < min {
				min = val
			}
			if val > max {
				max = val
			}
		}
	}

	// Normalize to [0, 255]
	norm := make([][]uint8, height)
	for y := range data {
		norm[y] = make([]uint8, width)
		for x, val := range data[y] {
			if max-min != 0 {
				norm[y][x] = uint8((val - min) / (max - min) * 255)
			} else {
				norm[y][x] = 0
			}
		}
	}

	return norm
}

func SaveAsImage(data [][]float64, filename string) error {
	normData := normalizeData8Bit(data)
	height, width := len(normData), len(normData[0])

	img := image.NewGray(image.Rect(0, 0, width, height))

	// Set pixel values
	for y := 0; y < height; y++ {
		for x := 0; x < width; x++ {
			img.SetGray(x, y, color.Gray{Y: normData[y][x]})
		}
	}

	// Create file
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	// Encode as PNG
	return png.Encode(file, img)
}

func SaveAsCSV(grid volume.Grid, filename string, divider int) {
	println("Saving Data to CSV File ", filename)
	f, err := os.Create(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	for t := 0; t < grid.Shape[3]; t++ {
		println("	Time Stamp ", t+1, "/", grid.Shape[3])
		for z := 0; z < grid.Shape[2]; z++ {
			//println("		Z index ", z+1, "/", vol.Shape[2])
			for y := 0; y < grid.Shape[1]; y++ {
				for x := 0; x < grid.Shape[0]; x++ {
					if x%divider == 0 {
						_, err := f.WriteString(fmt.Sprintf("%.5f", float32(grid.Data[x][y][z][t])) + ",")
						if err != nil {
							log.Fatal(err)
						}
					} else {
						continue
					}
				}
			}
		}
	}
}
func GetMiddleSlices(grid *volume.Grid) ([][]float64, [][]float64, [][]float64) {
	t := grid.Shape[3] / 2

	horizontal := make([][]float64, grid.Shape[0])
	sagittal := make([][]float64, grid.Shape[1])
	coronal := make([][]float64, grid.Shape[2])

	println("making horizontal slice")
	z := grid.Shape[2] / 2
	for x := range horizontal {
		horizontal[x] = make([]float64, grid.Shape[1])
		for y := range horizontal[x] {
			horizontal[x][y] = grid.Data[x][y][z][t]
		}
	}

	println("making sagittal slice")
	x := grid.Shape[0] / 2
	for y := range sagittal {
		sagittal[y] = make([]float64, grid.Shape[2])
		for z := range sagittal[y] {
			sagittal[y][z] = grid.Data[x][y][z][t]
		}
	}
	println("making coronal slice")
	y := grid.Shape[1] / 2
	for z := range coronal {
		coronal[z] = make([]float64, grid.Shape[0])
		for x := range coronal[z] {
			coronal[z][x] = grid.Data[x][y][z][t]
		}
	}
	//Currently the orientation is a bit weird but that's okay!
	return horizontal, coronal, sagittal
}
