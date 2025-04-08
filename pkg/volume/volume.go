package volume

import (
	"encoding/json"
	"fmt"
	"log"
	"math"
	"os"
)

type Grid struct {
	Name             string
	Data             [][][][]float64
	SpatialTransform affine3D
	FrameOffset      int
	DerivedFrom      string //Last stage of creation (perhaps make a list later, or linked list to previous vol, bigger question with modifier stack tbh)
	Channel          int    // To be used for modifier stacks
	BaseName         string
	Shape            [4]int  //Could probably clamp at int16 if memory becomes an issue
	FPS              float32 //Frames Per Second

	Normalized bool
	MinVal     float64 // For normalization
	MaxVal     float64 // For normalization
	Mean       float64

	ScanDatatype string
}

type Volume struct {
	Name  string
	Grids []Grid
}

type Metadata struct {
	Frames int
}

/*------- Essential Utilities ---------*/
func (grid *Grid) SaveMetadata(outputFolder string) {
	//Currently we only care about whether or not it is a sequence, but this eventually could just save the Header out (which might be useful)
	metadata := Metadata{
		Frames: grid.Shape[3],
	}

	println("Saving metadata:\n		", metadata.Frames, "\n", "	to ", outputFolder)

	filepath := fmt.Sprintf("%s/%s_metadata.json", outputFolder, grid.BaseName)

	f, err_c := os.Create(filepath)
	if err_c != nil {
		log.Fatal(err_c)
	}
	defer f.Close()

	json_output, _ := json.MarshalIndent(metadata, "", "\t")
	f.Write(json_output)
}

/*------- Math-y/Normalization things ---------*/
func (grid *Grid) NormalizeVolume(resetMinMax bool) {
	fmt.Println("Normalizing Volume. Start minmax:")
	grid.MinMax(true)
	for x := 0; x < grid.Shape[0]; x++ {
		for y := 0; y < grid.Shape[1]; y++ {
			for z := 0; z < grid.Shape[2]; z++ {
				for t := 0; t < grid.Shape[3]; t++ {
					grid.Data[x][y][z][t] = (grid.Data[x][y][z][t] - grid.MinVal) / (grid.MaxVal - grid.MinVal)

				}
			}
		}
	}
	if resetMinMax {
		fmt.Println("Volume Normalized. End minmax should be 0.0-1.0:")
		grid.MinMax(true)
	}
	grid.Normalized = true
}
func (grid *Grid) SetMean() {
	var sum float64 = 0
	var len float64 = 0
	shape := grid.Shape //kinda redundant?
	for x := 0; x < shape[0]; x++ {
		for y := 0; y < shape[1]; y++ {
			for z := 0; z < shape[2]; z++ {
				for t := 0; t < shape[3]; t++ {
					len += 1
					sum += grid.Data[x][y][z][t]
				}
			}
		}
	}

	grid.Mean = sum / len
}
func (grid *Grid) MinMax(printInfo bool) {
	var min_val, max_val = math.MaxFloat64, -math.MaxFloat64

	var min_idx, max_idx = [4]int{}, [4]int{}
	shape := grid.Shape
	for x := 0; x < shape[0]; x++ {
		for y := 0; y < shape[1]; y++ {
			for z := 0; z < shape[2]; z++ {
				for t := 0; t < shape[3]; t++ {
					val := grid.Data[x][y][z][t]
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
	grid.MinVal = min_val
	grid.MaxVal = max_val
	if printInfo {
		fmt.Println("Min Max Info")
		fmt.Println("	Shape", grid.Shape)
		fmt.Println("	Min: ", min_val, "at idx", min_idx)
		fmt.Println("	Max: ", max_val, "at idx", max_idx)
	}
}

/*------- Debugging and Render Helpers ---------*/
func (grid *Grid) SaveAsCSV(filename string, divider int) {
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
func (grid *Grid) GetMiddleSlices() ([][]float64, [][]float64, [][]float64) {
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

func (grid *Grid) PrintVolumeInfo() {
	fmt.Println("Volume Information:")
	fmt.Println("	Basename: ", grid.BaseName)
	fmt.Println("	Shape: ", grid.Shape)
	fmt.Println("	Frames Per Second: ", grid.ScanDatatype)
	fmt.Println("	Normalized: ", grid.Normalized)
	fmt.Println("	Min val:", grid.MinVal, "Max val: ", grid.MaxVal)
	fmt.Println("	Mean: ", grid.Mean)
	fmt.Println("	Scan Derived From: ", grid.DerivedFrom)
	fmt.Println("	Original Scan Datatype: ", grid.ScanDatatype)
}
