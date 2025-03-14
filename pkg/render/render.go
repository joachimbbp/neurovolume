package render

import (
	"image"
	"image/color"
	"image/png"
	"math"
	"os"
)

// GPT copypasta:
// normalizeData scales the float64 values to the range [0, 255]
func normalizeData(data [][]float64) [][]uint8 {
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
	normData := normalizeData(data)
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
