package volume

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"os"
)

type Volume struct {
	BaseName string
	Data     [][][][]float64
	Shape    [4]int //Could probably clamp at int16 if memory becomes an issue

	Normalized bool
	MinVal     float64 // For normalization
	MaxVal     float64 // For normalization
	Mean       float64

	ScanDatatype string
	DerivedFrom  string
}
type Metadata struct {
	Frames int
}

/*------- Essential Utilities ---------*/
func (vol *Volume) SaveMetadata(outputFolder string) {
	//Currently we only care about whether or not it is a sequence, but this eventually could just save the Header out (which might be useful)
	metadata := Metadata{
		Frames: vol.Shape[3],
	}

	println("Saving metadata:\n		", metadata.Frames, "\n", "	to ", outputFolder)

	filepath := fmt.Sprintf("%s/%s_metadata.json", outputFolder, vol.BaseName)

	f, err_c := os.Create(filepath)
	if err_c != nil {
		log.Fatal(err_c)
	}
	defer f.Close()

	json_output, _ := json.MarshalIndent(metadata, "", "\t")
	f.Write(json_output)
}

/*------- Math-y/Normalization things ---------*/
func (vol *Volume) NormalizeVolume(resetMinMax bool) {
	fmt.Println("Normalizing Volume. Start minmax:")
	vol.MinMax(true)
	for x := 0; x < vol.Shape[0]; x++ {
		for y := 0; y < vol.Shape[1]; y++ {
			for z := 0; z < vol.Shape[2]; z++ {
				for t := 0; t < vol.Shape[3]; t++ {
					vol.Data[x][y][z][t] = (vol.Data[x][y][z][t] - vol.MinVal) / (vol.MaxVal - vol.MinVal)

				}
			}
		}
	}
	if resetMinMax {
		fmt.Println("Volume Normalized. End minmax should be 0.0-1.0:")
		vol.MinMax(true)
	}
	vol.Normalized = true
}
func (vol *Volume) SetMean() {
	var sum float64 = 0
	var len float64 = 0
	shape := vol.Shape
	for x := 0; x < shape[0]; x++ {
		for y := 0; y < shape[1]; y++ {
			for z := 0; z < shape[2]; z++ {
				for t := 0; t < shape[3]; t++ {
					len += 1
					sum += vol.Data[x][y][z][t]
				}
			}
		}
	}

	vol.Mean = sum / len
}
func (vol *Volume) MinMax(printInfo bool) {
	var min_val, max_val = math.MaxFloat64, -math.MaxFloat64

	var min_idx, max_idx = [4]int{}, [4]int{}
	shape := vol.Shape
	for x := 0; x < shape[0]; x++ {
		for y := 0; y < shape[1]; y++ {
			for z := 0; z < shape[2]; z++ {
				for t := 0; t < shape[3]; t++ {
					val := vol.Data[x][y][z][t]
					if val < min_val {
						min_val = val
						min_idx = [4]int{x, y, z, t}
					}
					if val > max_val {
						max_val = val
						max_idx = [4]int{x, y, z, t}
					}
				}
			}
		}
	}
	vol.MinVal = min_val
	vol.MaxVal = max_val
	if printInfo {
		fmt.Println("Min Max Info")
		fmt.Println("	Shape", vol.Shape)
		fmt.Println("	Min: ", min_val, "at idx", min_idx)
		fmt.Println("	Max: ", max_val, "at idx", max_idx)
	}
}

/*------- Debugging and Render Helpers ---------*/
func (vol *Volume) SaveAsCSV(filename string, divider int) {
	println("Saving Data to CSV File ", filename)
	f, err := os.Create(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer f.Close()
	for t := 0; t < vol.Shape[3]; t++ {
		println("	Time Stamp ", t+1, "/", vol.Shape[3])
		for z := 0; z < vol.Shape[2]; z++ {
			//println("		Z index ", z+1, "/", vol.Shape[2])
			for y := 0; y < vol.Shape[1]; y++ {
				for x := 0; x < vol.Shape[0]; x++ {
					if x%divider == 0 {
						_, err := f.WriteString(fmt.Sprintf("%.5f", float32(vol.Data[x][y][z][t])) + ",")
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
func (vol *Volume) GetMiddleSlices() ([][]float64, [][]float64, [][]float64) {
	t := vol.Shape[3] / 2

	horizontal := make([][]float64, vol.Shape[0])
	sagittal := make([][]float64, vol.Shape[1])
	coronal := make([][]float64, vol.Shape[2])

	println("making horizontal slice")
	z := vol.Shape[2] / 2
	for x := range horizontal {
		horizontal[x] = make([]float64, vol.Shape[1])
		for y := range horizontal[x] {
			horizontal[x][y] = vol.Data[x][y][z][t]
		}
	}

	println("making sagittal slice")
	x := vol.Shape[0] / 2
	for y := range sagittal {
		sagittal[y] = make([]float64, vol.Shape[2])
		for z := range sagittal[y] {
			sagittal[y][z] = vol.Data[x][y][z][t]
		}
	}
	println("making coronal slice")
	y := vol.Shape[1] / 2
	for z := range coronal {
		coronal[z] = make([]float64, vol.Shape[0])
		for x := range coronal[z] {
			coronal[z][x] = vol.Data[x][y][z][t]
		}
	}
	//Currently the orientation is a bit weird but that's okay!
	return horizontal, coronal, sagittal
}

func (vol *Volume) PrintVolumeInfo() {
	fmt.Println("Volume Information:")
	fmt.Println("	Basename: ", vol.BaseName)
	fmt.Println("	Shape: ", vol.Shape)
	fmt.Println("	Normalized: ", vol.Normalized)
	fmt.Println("	Min val:", vol.MinVal, "Max val: ", vol.MaxVal)
	fmt.Println("	Mean: ", vol.Mean)
	fmt.Println("	Scan Derived From: ", vol.DerivedFrom)
	fmt.Println("	Original Scan Datatype: ", vol.ScanDatatype)
}
