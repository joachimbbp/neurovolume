package volume

import (
	"compress/gzip"
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
		gzipReader, err := gzip.NewReader(f)
		if err != nil {
			return nil, err
		}
		return gzipReader, nil
	}
	return f, nil
}
