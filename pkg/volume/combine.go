package volume

import "math"

type point struct {
	x, y, z, t float64
	value      float64
}

type affine3D struct {
	a1, a2, a3, a4 float64
	b1, b2, b3, b4 float64
	c1, c2, c3, c4 float64
}

func (affine *affine3D) apply(input point) point {
	// the t of the input point will be always set to 1
	// while input is 4D, the transform will only take place within 3D

	var output point
	output.value = input.value

	output.x = affine.a1*input.x + affine.a2*input.y + affine.a3*input.z
	output.y = affine.b1*input.x + affine.b2*input.y + affine.b3*input.z
	output.z = affine.c1*input.x + affine.c2*input.y + affine.c3*input.z

	return output
}

// yaw
func (affine *affine3D) rotateZ(theta float64) {
	affine.a1 = math.Cos(theta)
	affine.b1 = math.Sin(theta)
	affine.c1 = 0

	affine.a2 = -math.Sin(theta)
	affine.b2 = math.Cos(theta)
	affine.b3 = 0

	affine.a3 = 0
	affine.b3 = 0
	affine.c3 = 0
}

// Adds bold to
func CombineAnatAndBold(bold Grid, anat Grid) {
	//totalPoints := bold.Shape[0] * bold.Shape[1] * bold.Shape[2] * bold.Shape[3]
	var cloud []point
	var newPoint point

	for x := 0; x < bold.Shape[0]; x++ {
		for y := 0; y < bold.Shape[1]; y++ {
			for z := 0; z < bold.Shape[2]; z++ {
				for t := 0; t < bold.Shape[3]; t++ {
					newPoint = bold.SpatialTransform.apply(point{x: float64(x), y: float64(y), z: float64(z), t: float64(t), value: bold.Data[x][y][z][t]})
					cloud = append(cloud, newPoint)
				}
			}
		}

	}

	var transformedBold Grid
	transformedBold.Shape = anat.Shape //Were just clipping it to the anatomy bounds for now

	// Now move through the anatomy scan and match
	for x := 0; x < anat.Shape[0]; x++ {
		for y := 0; y < anat.Shape[1]; y++ {
			for z := 0; z < anat.Shape[2]; z++ {
				for t := 0; t < anat.Shape[3]; t++ {
					transformedBold.Data[x][y][z][t] = getAverageBoldValues(x, y, z, t, cloud)
				}
			}
		}
	}

}

// Returns the average bold values within the given pos->(pos+1) value
func getAverageBoldValues(x, y, z, t int, cloud []point) float64 {
	xff := float64(x)     //x float floor
	xfc := float64(x + 1) //x float ceiling
	yff := float64(y)
	yfc := float64(y + 1)
	zff := float64(z)
	zfc := float64(z + 1)
	tff := float64(t)
	tfc := float64(t + 1)

	numPoints := float64(0)
	totalScalar := float64(0)

	// very terrible naive search, you can make this much more performant!
	for _, point := range cloud {
		if xff <= point.x && point.x <= xfc {
			if yff <= point.y && point.y <= yfc {
				if zff <= point.z && point.z <= zfc {
					if tff <= point.t && point.t <= tfc {
						totalScalar += point.value
					}
				}
			}
		}
	}
	return totalScalar / numPoints
}
