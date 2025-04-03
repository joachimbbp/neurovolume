package utils

import "strings"

func GetBasename(filepath string) string {
	hierarchy := strings.Split(filepath, "/")
	return strings.Split(hierarchy[len(hierarchy)-1], ".")[0]
}
