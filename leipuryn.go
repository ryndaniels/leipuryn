package main

import (
	"archive/zip"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

const (
	// LatestImageURL is where to download the latest raspbian image from, if one isn't provided locally
	latestImageURL = "https://downloads.raspberrypi.org/raspbian_lite_latest"
)
const (
	// LatestImageSHA is from raspberrypi.org
	latestImageSHA = "47ef1b2501d0e5002675a50b6868074e693f78829822eef64f3878487953234d"
)

func main() {
	fmt.Println("welcome to leipuryn")

	imageURL := flag.String("url", "", "url to the raspbian image to download")
	flag.Parse()

	zipPath := downloadImage(*imageURL)
	// We are *only* downloading the zip with the img in it. iso support can get in the sea.
	fmt.Printf("Unzipping %s...\n", zipPath)
	unzip(zipPath, ".")
}

func downloadImage(imageURL string) string {
	if imageURL == "" {
		imageURL = latestImageURL
	}

	filePath := "raw_pi_dough.zip"
	if _, err := os.Stat(filePath); !os.IsNotExist(err) {
		fmt.Printf("File %s already exists, not overwriting...\n", filePath)
	} else {
		out, err := os.Create(filePath)
		defer out.Close()
		checkError(err)

		fmt.Printf("Downloading file from %s to %s, this could take a while...\n", imageURL, filePath)

		cmd := exec.Command("curl", "-#", "-o", filePath, "-L", imageURL)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		err = cmd.Run()
		checkError(err)
	}

	hasher := sha256.New()
	f, err := os.Open(filePath)
	checkError(err)
	defer f.Close()
	if _, err := io.Copy(hasher, f); err != nil {
		panic(err)
	}

	if hex.EncodeToString(hasher.Sum(nil)) != latestImageSHA {
		fmt.Println("Checksums don't match, aborting!")
		os.Exit(2)
	}

	return filePath
}

func checkError(err error) {
	if err != nil {
		panic(err)
	}
}

// Thank you to https://stackoverflow.com/a/24792688/10548407
func unzip(src, dest string) error {
	r, err := zip.OpenReader(src)
	if err != nil {
		return err
	}
	defer func() {
		if err := r.Close(); err != nil {
			panic(err)
		}
	}()

	os.MkdirAll(dest, 0755)

	// Closure to address file descriptors issue with all the deferred .Close() methods
	extractAndWriteFile := func(f *zip.File) error {
		rc, err := f.Open()
		if err != nil {
			return err
		}
		defer func() {
			if err := rc.Close(); err != nil {
				panic(err)
			}
		}()

		path := filepath.Join(dest, f.Name)

		if f.FileInfo().IsDir() {
			os.MkdirAll(path, f.Mode())
		} else {
			os.MkdirAll(filepath.Dir(path), f.Mode())
			f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
			if err != nil {
				return err
			}
			defer func() {
				if err := f.Close(); err != nil {
					panic(err)
				}
			}()

			_, err = io.Copy(f, rc)
			if err != nil {
				return err
			}
		}
		return nil
	}

	for _, f := range r.File {
		err := extractAndWriteFile(f)
		if err != nil {
			return err
		}
	}

	return nil
}
