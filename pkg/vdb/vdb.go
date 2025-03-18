/*
Much of this VDB reader has been adapted from this Jenga FX Repo:
https://github.com/jangafx/simple-vdb-writer?tab=readme-ov-file
While it has been re-written in Go and the functionality has been
expanded, much of the logic remains the same. Please see the
attached License in the comments below:

MIT License

Copyright (c) 2022 JangaFX

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

package vdb

import (
	"bytes"
	"encoding/binary"
	"fmt"
	"log"
	"math"
	"math/bits"
	"os"
	"unsafe"

	"github.com/joachimbbp/neurovolume/pkg/volume"
)

//-------------------- VDBs and Node Structs --------------------

type VDB struct {
	node_5 Node_5
}

type Node_5 struct {
	mask    [512]uint64
	nodes_4 map[uint32]*Node_4
}

type Node_4 struct {
	mask    [64]uint64
	nodes_3 map[uint32]*Node_3
}

type Node_3 struct {
	mask [8]uint64
	// stored as float32 but will be converted to half-float on write
	data [512]float32
}

// New node functions.
func NewNode5() *Node_5 {
	return &Node_5{
		nodes_4: make(map[uint32]*Node_4),
	}
}

func NewNode4() *Node_4 {
	return &Node_4{
		nodes_3: make(map[uint32]*Node_3),
	}
}

func NewNode3() *Node_3 {
	return &Node_3{}
}

//-------------------- Bit Index Functions --------------------

func getBitIndex4(p [3]uint32) uint32 {
	p[0] = p[0] & (4096 - 1)
	p[1] = p[1] & (4096 - 1)
	p[2] = p[2] & (4096 - 1)
	idx3D := [3]uint32{p[0] >> 7, p[1] >> 7, p[2] >> 7}
	return idx3D[2] | (idx3D[1] << 5) | (idx3D[0] << 10)
}

func getBitIndex3(p [3]uint32) uint32 {
	p[0] = p[0] & (128 - 1)
	p[1] = p[1] & (128 - 1)
	p[2] = p[2] & (128 - 1)
	idx3D := [3]uint32{p[0] >> 3, p[1] >> 3, p[2] >> 3}
	return idx3D[2] | (idx3D[1] << 4) | (idx3D[0] << 8)
}

func getBitIndex0(p [3]uint32) uint32 {
	p[0] = p[0] & (8 - 1)
	p[1] = p[1] & (8 - 1)
	p[2] = p[2] & (8 - 1)
	idx3D := [3]uint32{p[0], p[1], p[2]}
	return idx3D[2] | (idx3D[1] << 3) | (idx3D[0] << 6)
}

//-------------------- Voxel Setting --------------------

// Use the existing root node (do not reinitialize it every time).
func set_voxel(vdb *VDB, position [3]uint32, value float32) {
	node_5 := &vdb.node_5

	bit_index_4 := getBitIndex4(position)
	bit_index_3 := getBitIndex3(position)
	bit_index_0 := getBitIndex0(position)

	node_4, found := node_5.nodes_4[bit_index_4]
	if !found {
		node_4 = NewNode4()
		node_5.nodes_4[bit_index_4] = node_4
	}
	node_3, found := node_4.nodes_3[bit_index_3]
	if !found {
		node_3 = NewNode3()
		node_4.nodes_3[bit_index_3] = node_3
	}
	node_5.mask[bit_index_4>>6] |= 1 << (bit_index_4 & (64 - 1))
	node_4.mask[bit_index_3>>6] |= 1 << (bit_index_3 & (64 - 1))
	node_3.mask[bit_index_0>>6] |= 1 << (bit_index_0 & (64 - 1))

	node_3.data[bit_index_0] = value
}

//-------------------- Binary Write Helpers --------------------

// writeSlice writes the raw bytes of a slice.
func writeSlice[T any](buffer *bytes.Buffer, data []T) {
	byteSlice := unsafe.Slice((*byte)(unsafe.Pointer(&data[0])), len(data)*int(unsafe.Sizeof(data[0])))
	buffer.Write(byteSlice)
}

// writeName writes a u32 length then the string (matching Odin).
func writeName(buffer *bytes.Buffer, name string) {
	if err := binary.Write(buffer, binary.LittleEndian, uint32(len(name))); err != nil {
		log.Panic(err)
	}
	buffer.WriteString(name)
}

func writeMetaString(buffer *bytes.Buffer, name string, s string) {
	writeName(buffer, name)
	writeName(buffer, "string")
	writeName(buffer, s)
}

func writeMetaBool(buffer *bytes.Buffer, name string, value bool) {
	writeName(buffer, name)
	writeName(buffer, "bool")
	if err := binary.Write(buffer, binary.LittleEndian, uint32(1)); err != nil {
		log.Panic(err)
	}
	var b byte
	if value {
		b = 1
	} else {
		b = 0
	}
	if err := buffer.WriteByte(b); err != nil {
		log.Panic(err)
	}
}

func writeVec3i(b *bytes.Buffer, vec [3]int32) {
	for _, v := range vec {
		if err := binary.Write(b, binary.LittleEndian, v); err != nil {
			log.Panic(err)
		}
	}
}

//-------------------- Node Header Writers --------------------

// writeNode5Header writes the 5-node header exactly as the Odin code does.
func writeNode5Header(b *bytes.Buffer, node *Node_5) {
	// Write origin (a zero vector).
	writeVec3i(b, [3]int32{0, 0, 0})
	// Write child masks.
	for _, word := range node.mask {
		if err := binary.Write(b, binary.LittleEndian, word); err != nil {
			log.Panic(err)
		}
	}
	// Write value masks (zero-initialized).
	for range node.mask {
		if err := binary.Write(b, binary.LittleEndian, uint64(0)); err != nil {
			log.Panic(err)
		}
	}
	// Write uncompressed flag (6 means no compression).
	if err := b.WriteByte(6); err != nil {
		log.Panic(err)
	}
	// Write 32768 16-bit zeros.
	for i := 0; i < 32768; i++ {
		if err := binary.Write(b, binary.LittleEndian, uint16(0)); err != nil {
			log.Panic(err)
		}
	}
}

func writeNode4Header(b *bytes.Buffer, node *Node_4) {
	// Write child masks.
	for _, word := range node.mask {
		if err := binary.Write(b, binary.LittleEndian, word); err != nil {
			log.Panic(err)
		}
	}
	// Write value masks (zero for now).
	for range node.mask {
		if err := binary.Write(b, binary.LittleEndian, uint64(0)); err != nil {
			log.Panic(err)
		}
	}
	// Write uncompressed flag (6 means no compression).
	if err := b.WriteByte(6); err != nil {
		log.Panic(err)
	}
	// Write 4096 16-bit zeros.
	for i := 0; i < 4096; i++ {
		if err := binary.Write(b, binary.LittleEndian, uint16(0)); err != nil {
			log.Panic(err)
		}
	}
}

//-------------------- Half-Float Conversion --------------------

// writeHalfFloatSlice converts each float32 to a half-float and writes it.
func writeHalfFloatSlice(buffer *bytes.Buffer, data []float32) {
	for _, f := range data {
		half := float32ToHalf(f)
		if err := binary.Write(buffer, binary.LittleEndian, half); err != nil {
			log.Panic(err)
		}
	}
}

// float32ToHalf converts a float32 to a 16-bit half-precision value.
func float32ToHalf(f float32) uint16 {
	fbits := math.Float32bits(f)
	sign := uint16((fbits >> 16) & 0x8000)
	exponent := int((fbits >> 23) & 0xff)
	mantissa := fbits & 0x7fffff

	var half uint16
	if exponent == 255 { // Inf or NaN
		if mantissa != 0 {
			half = sign | 0x7e00 // NaN
		} else {
			half = sign | 0x7c00 // Inf
		}
	} else if exponent > 142 { // Overflow, clamp to Inf.
		half = sign | 0x7c00
	} else if exponent < 113 { // Underflow
		if exponent < 103 {
			half = sign
		} else {
			shift := uint32(113 - exponent)
			sub := (mantissa | 0x800000) >> shift
			half = sign | uint16(sub>>13)
		}
	} else {
		exp := uint16(exponent - 112)
		half = sign | (exp << 10) | uint16(mantissa>>13)
	}
	return half
}

//-------------------- Tree Writer --------------------

// write_tree writes the voxel tree in two passes: first the node headers, then the voxel data.
// This mirrors the structure of the Odin code’s write_tree procedure.
func write_tree(buffer *bytes.Buffer, vdb *VDB) {
	// Write tree header: four uint32 values.
	if err := binary.Write(buffer, binary.LittleEndian, uint32(1)); err != nil {
		log.Panic(err)
	}
	if err := binary.Write(buffer, binary.LittleEndian, uint32(0)); err != nil {
		log.Panic(err)
	}
	if err := binary.Write(buffer, binary.LittleEndian, uint32(0)); err != nil {
		log.Panic(err)
	}
	if err := binary.Write(buffer, binary.LittleEndian, uint32(1)); err != nil {
		log.Panic(err)
	}

	// Write Node_5 header.
	writeNode5Header(buffer, &vdb.node_5)

	// First pass: write each Node_3’s header (its 8 mask words) along with its parent Node_4 header.
	for wordIndex, word := range vdb.node_5.mask {
		for w := word; w != 0; w &= w - 1 {
			key := uint32(wordIndex)*64 + uint32(bits.TrailingZeros64(w))
			node_4, ok := vdb.node_5.nodes_4[key]
			if !ok {
				panic("node4 not found")
			}
			writeNode4Header(buffer, node_4)
			for innerWordIndex, innerWord := range node_4.mask {
				for w := innerWord; w != 0; w &= w - 1 {
					key2 := uint32(innerWordIndex)*64 + uint32(bits.TrailingZeros64(w))
					node_3, ok := node_4.nodes_3[key2]
					if !ok {
						panic("node3 not found")
					}
					// Write all 8 mask words of node_3.
					for _, maskWord := range node_3.mask {
						if err := binary.Write(buffer, binary.LittleEndian, maskWord); err != nil {
							panic(err)
						}
					}
				}
			}
		}
	}

	// Second pass: for each Node_3, write its 8 mask words again, then the uncompressed flag (6) and then its 512 voxel values (as half-floats).
	for wordIndex, word := range vdb.node_5.mask {
		for w := word; w != 0; w &= w - 1 {
			key := uint32(wordIndex)*64 + uint32(bits.TrailingZeros64(w))
			node_4, ok := vdb.node_5.nodes_4[key]
			if !ok {
				panic("node4 not found")
			}
			for innerWordIndex, innerWord := range node_4.mask {
				for w := innerWord; w != 0; w &= w - 1 {
					key2 := uint32(innerWordIndex)*64 + uint32(bits.TrailingZeros64(w))
					node_3, ok := node_4.nodes_3[key2]
					if !ok {
						panic("node3 not found")
					}
					for _, maskWord := range node_3.mask {
						if err := binary.Write(buffer, binary.LittleEndian, maskWord); err != nil {
							panic(err)
						}
					}
					if err := buffer.WriteByte(6); err != nil {
						panic(err)
					}
					writeHalfFloatSlice(buffer, node_3.data[:])
				}
			}
		}
	}
}

//-------------------- Grid and VDB Writers --------------------

// writeGrid writes the grid descriptor, metadata, transform and then the voxel tree.
func writeGrid(buffer *bytes.Buffer, vdb *VDB, transform_matrix [4][4]float64) {
	writeName(buffer, "density")
	writeName(buffer, "Tree_float_5_4_3_HalfFloat")
	if err := binary.Write(buffer, binary.LittleEndian, uint32(0)); err != nil {
		log.Panic(err)
	}
	descPos := uint64(len(buffer.Bytes())) + uint64(8*3)
	if err := binary.Write(buffer, binary.LittleEndian, descPos); err != nil {
		log.Panic(err)
	}
	if err := binary.Write(buffer, binary.LittleEndian, uint64(0)); err != nil {
		log.Panic(err)
	}
	if err := binary.Write(buffer, binary.LittleEndian, uint64(0)); err != nil {
		log.Panic(err)
	}
	if err := binary.Write(buffer, binary.LittleEndian, uint32(0)); err != nil {
		log.Panic(err)
	}

	if err := binary.Write(buffer, binary.LittleEndian, uint32(4)); err != nil {
		log.Panic(err)
	}
	writeMetaString(buffer, "class", "unknown")
	writeMetaString(buffer, "file_compression", "none")
	writeMetaBool(buffer, "is_saved_as_half_float", true)
	writeMetaString(buffer, "name", "density")

	writeName(buffer, "AffineMap")
	binary.Write(buffer, binary.LittleEndian, transform_matrix[0][0])
	binary.Write(buffer, binary.LittleEndian, transform_matrix[1][0])
	binary.Write(buffer, binary.LittleEndian, transform_matrix[2][0])
	binary.Write(buffer, binary.LittleEndian, float64(0))

	binary.Write(buffer, binary.LittleEndian, transform_matrix[0][1])
	binary.Write(buffer, binary.LittleEndian, transform_matrix[1][1])
	binary.Write(buffer, binary.LittleEndian, transform_matrix[2][1])
	binary.Write(buffer, binary.LittleEndian, float64(0))

	binary.Write(buffer, binary.LittleEndian, transform_matrix[0][2])
	binary.Write(buffer, binary.LittleEndian, transform_matrix[1][2])
	binary.Write(buffer, binary.LittleEndian, transform_matrix[2][2])
	binary.Write(buffer, binary.LittleEndian, float64(0))

	binary.Write(buffer, binary.LittleEndian, transform_matrix[0][3])
	binary.Write(buffer, binary.LittleEndian, transform_matrix[1][3])
	binary.Write(buffer, binary.LittleEndian, transform_matrix[2][3])
	// Write bottom-right element as float64(1) (not uint32)
	binary.Write(buffer, binary.LittleEndian, float64(1))

	// Write the voxel tree.
	write_tree(buffer, vdb)
}

// writeVDB writes the overall file header and then the grid.
func writeVDB(buffer *bytes.Buffer, vdb *VDB, transform_matrix [4][4]float64) {
	// Magic number.
	writeSlice(buffer, []byte{0x20, 0x42, 0x44, 0x56, 0x0, 0x0, 0x0, 0x0})
	// File version.
	if err := binary.Write(buffer, binary.LittleEndian, uint32(224)); err != nil {
		log.Panic(err)
	}
	// Library versions (major and minor), OpenVDB 8.1.
	if err := binary.Write(buffer, binary.LittleEndian, uint32(8)); err != nil {
		log.Panic(err)
	}
	if err := binary.Write(buffer, binary.LittleEndian, uint32(1)); err != nil {
		log.Panic(err)
	}
	// No grid offsets.
	if err := binary.Write(buffer, binary.LittleEndian, uint8(0)); err != nil {
		log.Panic(err)
	}
	// Temporary UUID.
	buffer.WriteString("d2b59639-ac2f-4047-9c50-9648f951180c")
	// No metadata.
	if err := binary.Write(buffer, binary.LittleEndian, uint32(0)); err != nil {
		log.Panic(err)
	}
	// One grid.
	if err := binary.Write(buffer, binary.LittleEndian, uint32(1)); err != nil {
		log.Panic(err)
	}
	writeGrid(buffer, vdb, transform_matrix)
}

//-------------------- Main Function --------------------

// Test function to write a Sphere with the vdb writer
func WriteSphere() {
	fmt.Println("Creating a VDB Sphere")
	var buffer bytes.Buffer
	var vdb VDB
	// Initialize the root node only once.
	vdb.node_5 = *NewNode5()

	Radius := 128
	Diameter := Radius * 2
	center := float32(Radius)
	for z := 0; z < Diameter; z++ {
		for y := 0; y < Diameter; y++ {
			for x := 0; x < Diameter; x++ {
				dx := float32(x) - center
				dy := float32(y) - center
				dz := float32(z) - center
				if dx*dx+dy*dy+dz*dz < float32(Radius*Radius) {
					set_voxel(&vdb, [3]uint32{uint32(x), uint32(y), uint32(z)}, 1.0)
				}
			}
		}
	}

	identity_matrix := [4][4]float64{
		{1, 0, 0, 0},
		{0, 1, 0, 0},
		{0, 0, 1, 0},
		{0, 0, 0, 1},
	}

	writeVDB(&buffer, &vdb, identity_matrix)

	if err := os.WriteFile("test_sphere.vdb", buffer.Bytes(), 0644); err != nil {
		fmt.Println("Failed to write file:", err)
	}
}

func WriteFromVolume(vol *volume.Volume) {
	fmt.Println("Writing Volume VDB")

	var vdb VDB
	vdb.node_5 = *NewNode5()
	fmt.Println(vol.Shape)
	fmt.Println("	Setting Voxels")
	t := 0
	for z := 0; z < vol.Shape[2]; z++ {
		for y := 0; y < vol.Shape[1]; y++ {
			for x := 0; x < vol.Shape[0]; x++ {

				voxel := float32(vol.Data[x][y][z][t])

				set_voxel(&vdb, [3]uint32{uint32(x), uint32(y), uint32(z)}, voxel)
			}
		}
	}

	fmt.Println("	Writing VDB")
	var buffer bytes.Buffer
	identity_matrix := [4][4]float64{
		{1, 0, 0, 0},
		{0, 1, 0, 0},
		{0, 0, 1, 0},
		{0, 0, 0, 1},
	}
	writeVDB(&buffer, &vdb, identity_matrix)

	if err := os.WriteFile("/Users/joachimpfefferkorn/repos/neurovolume/output/volume_test5.vdb", buffer.Bytes(), 0644); err != nil {
		fmt.Println("Failed to write file:", err)
	}

}
