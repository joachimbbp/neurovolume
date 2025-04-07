package volume

type point struct {
	x, y, z float32
	value   float64
}

type affine3D struct {
	// Row-major 3x4 matrix:
	// [ x1 x2 x3 tx ]
	// [ y1 y2 y3 ty ]
	// [ z1 z2 z3 tz ]
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

//pointcloud is a list of [x][y][z][t][value]åå

func Transform(vol Volume, transform affine3D) Volume {
	totalPoints := vol.Shape[0] * vol.Shape[1] * vol.Shape[2] * vol.Shape[3]
	cloud := make([]point, totalPoints)

	var maxX float32 = 0
	var maxY float32 = 0
	var maxZ float32 = 0
	var newPoint point

	for x := 0; x < vol.Shape[0]; x++ {
		for y := 0; y < vol.Shape[1]; y++ {
			for z := 0; z < vol.Shape[2]; z++ {
				for t := 0; t < vol.Shape[3]; t++ {
					newPoint = transform.apply(point{x: float32(x), y: float32(y), z: float32(z), value: vol.Data[x][y][z][t]})
					cloud = append(cloud, newPoint)
					if newPoint.x > maxX {
						maxX = newPoint.x
					}
					if newPoint.y > maxY {
						maxX = newPoint.y
					}
					if newPoint.z > maxZ {
						maxZ = newPoint.z
					}
				}
			}
		}

	}

	var output Volume
	//output.Shape //okay but you've got to truncate these up!

	return output

}

// func (vol *Volume) FromCloud(cloud []point) Volume {

// 	return vol
// }
