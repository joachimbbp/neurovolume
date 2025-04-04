package utils

import (
	"fmt"
	"os"
	"strings"
)

func GetBasename(filepath string) string {
	hierarchy := strings.Split(filepath, "/")
	return strings.Split(hierarchy[len(hierarchy)-1], ".")[0]
}

// Clears everything from folder except for the gitignore
func ClearOutputFolder(outputFolder string) {
	entries, _ := os.ReadDir(outputFolder)
	for _, entry := range entries {
		name := entry.Name()
		if name == ".gitignore" {
			continue
		}
		fmt.Println("Removing: ", name)
		os.RemoveAll(outputFolder + "/" + name)
	}
}
