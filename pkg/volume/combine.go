package volume

import "math"

type point struct {
	x, y, z float32
	value   float64
}

type affine3D struct {
	// Row-major 3x4 matrix:
	// [ x1 x2 x3 tx ]
	// [ y1 y2 y3 ty ]
	// [ z1 z2 z3 tz ]
	// [ 0  0  0  1  ] ????
	x1, x2, x3, tx float32
	y1, y2, y3, ty float32
	z1, z2, z3, tz float32
}

func (a *affine3D) apply(input point) point {
	var output point
	output.value = input.value

	output.x = a.x1*input.x + a.x2*input.y + a.x3*input.z + a.tx
	output.y = a.y1*input.x + a.y2*input.y + a.y3*input.z + a.ty
	output.z = a.z1*input.x + a.z2*input.y + a.z3*input.z + a.tz
	return output
}

// Adds bold to
func CombineAnatAndBold(bold Grid, anat Grid) {
	//totalPoints := bold.Shape[0] * bold.Shape[1] * bold.Shape[2] * bold.Shape[3]
	var cloud []point

	var maxX int = 0
	var maxY int = 0
	var maxZ int = 0
	var newPoint point

	for x := 0; x < bold.Shape[0]; x++ {
		for y := 0; y < bold.Shape[1]; y++ {
			for z := 0; z < bold.Shape[2]; z++ {
				for t := 0; t < bold.Shape[3]; t++ {
					newPoint = bold.SpatialTransform.apply(point{x: float32(x), y: float32(y), z: float32(z), value: bold.Data[x][y][z][t]})
					cloud = append(cloud, newPoint)

					if newPoint.x > float32(maxX) {
						maxX = int(math.Ceil(float64(newPoint.x)))
					}
					if newPoint.y > float32(maxY) {
						maxY = int(math.Ceil(float64(newPoint.y)))
					}
					if newPoint.z > float32(maxZ) {
						maxZ = int(math.Ceil(float64(newPoint.z)))
					}
				}
			}
		}

	}

	// Now move through the anatomy scan and match
	for x := 0; x < anat.Shape[0]; x++ {
		for y := 0; y < anat.Shape[1]; y++ {
			for z := 0; z < anat.Shape[2]; z++ {
				for t := 0; t < anat.Shape[3]; t++ {
					print(t) //bye red squiggles
					//check if there is a cloud point "here"
					//best way of thinking about this?
					//probably hash the cloud to return a
				}
			}
		}
	}

}

func GetAverageBoldValues(x, y, z, t int, cloud []point) {
	//
}

// func (vol *Volume) FromCloud(cloud []point) Volume {

// 	return vol
// }
