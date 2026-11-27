// Package fixture holds everyday code that golangci-lint v1 accepted via its
// default exclusions; the v2 template must keep it quiet (exclusions presets).
package fixture

import "os"

func ReadFirstByte(path string) (byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer f.Close()
	buf := make([]byte, 1)
	_, err = f.Read(buf)
	return buf[0], err
}
