package open

import (
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"strings"
)

// Opens files whether or not they are gziped
func GZipOrAnything(filepath string) (bool, io.ReadCloser, error) { //from Heng Huang's repo
	isGZ := false
	f, err := os.Open(filepath)
	if err != nil {
		return isGZ, nil, err
	}
	filepathS := strings.Split(filepath, ".")
	if filepathS[len(filepathS)-1] == "gz" {
		isGZ = true
		fmt.Println("Opening gzip file: ", filepath)
		gzipReader, err := gzip.NewReader(f)
		if err != nil {
			return isGZ, nil, err
		}
		return isGZ, gzipReader, nil
	}
	fmt.Println("Opening non-gz file: ", filepath)
	return isGZ, f, nil
}
