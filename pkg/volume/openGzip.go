package volume

import (
	"compress/gzip"
	"fmt"
	"io"
	"os"
	"strings"
)

// Opens files whether or not they are gziped
func gzipOpen(filepath string) (io.ReadCloser, error) { //from Heng Huang's repo
	f, err := os.Open(filepath)
	if err != nil {
		return nil, err
	}
	filepathS := strings.Split(filepath, ".")
	if filepathS[len(filepathS)-1] == "gz" {
		fmt.Println("Opening gzip file: ", filepath)
		gzipReader, err := gzip.NewReader(f)
		if err != nil {
			return nil, err
		}
		return gzipReader, nil
	}
	fmt.Println("Opening non-gz file: ", filepath)
	return f, nil
}
