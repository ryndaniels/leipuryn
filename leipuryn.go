package main

import (
	"archive/zip"
	"bufio"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const (
	// LatestImageURL is where to download the latest raspbian image from, if one isn't provided locally
	latestImageURL = "https://downloads.raspberrypi.org/rpd_x86_latest"
)
const (
	// LatestImageSHA is from raspberrypi.org
	latestImageSHA = "0148f4b5da4b9c82c731107e4a29e645445d715db8b070609df3c6689df0c8d1"
)

func main() {
	fmt.Println("welcome to leipuryn")

	imageURL := flag.String("url", "", "url to the raspbian image to download")
	imagePath := flag.String("path", "", "path to local raspbian image to use")
	useVbox := flag.Bool("vbox", false, "create a local VM from downloaded image using virtualbox")
	flag.Parse()

	if *imageURL != "" && *imagePath != "" {
		fmt.Println("Please don't specify both a URL and a local path, that's confusing.")
		os.Exit(2)
	}

	if *imagePath == "" {
		*imagePath = downloadImage(*imageURL)
	}

	if filepath.Ext(*imagePath) == ".zip" {
		fmt.Printf("Unzipping %s...\n", *imagePath)
		unzip(*imagePath, ".")
		fmt.Println("As discussed, we're ignoring these and working on ISOs for now, exiting...")
		os.Exit(1)
	} else if filepath.Ext(*imagePath) == ".iso" {
		if *useVbox == true {
			vdiPath := convertToVDI(*imagePath)
			vmName := "Leipuryn Build VM"
			createVM(vmName, vdiPath)
			cleanUpVM(vmName)
		} else {
			// This is the default, and probably what we're doing going forward -
			// putting the flag in to avoid deleting this *yet*
			if runtime.GOOS == "linux" {
				fmt.Println("Going to mount the iso...")
			} else if runtime.GOOS == "windows" || runtime.GOOS == "darwin" {
				fmt.Printf("Mounting locally not supported on %s, exiting...\n", runtime.GOOS)
			}
		}

	} else {
		fmt.Printf("Unexpected file format for %s (expecting .iso or .zip), exiting...\n", *imagePath)
		os.Exit(2)
	}

}

func runVboxCommand(command ...string) {
	VBM := "VBoxManage"
	if p := os.Getenv("VBOX_INSTALL_PATH"); p != "" && runtime.GOOS == "windows" {
		VBM = filepath.Join(p, "VBoxManage.exe")
	}
	cmd := exec.Command(VBM, command...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err := cmd.Run()
	checkError(err)
}

func convertToVDI(imagePath string) string {
	baseName := imagePath[0 : len(imagePath)-len(filepath.Ext(imagePath))]
	vdiPath := baseName + ".vdi"

	if _, err := os.Stat(vdiPath); !os.IsNotExist(err) {
		fmt.Printf("VDI file %s already exists, not overwriting...\n", vdiPath)
	} else {
		fmt.Printf("Using vboxmanage to convert from %s to %s\n", imagePath, vdiPath)
		runVboxCommand("convertfromraw", imagePath, vdiPath)
	}
	return vdiPath
}

func createVM(vmName, vdiPath string) {
	fmt.Printf("Creating a vm named %s from image %s\n", vmName, vdiPath)
	controllerName := "SATA Controller"
	runVboxCommand("createvm", "--name", vmName, "--ostype", "Debian_64", "--register")
	runVboxCommand("modifyvm", vmName, "--cpus", "1", "--memory", "1024", "--vram", "16")

	runVboxCommand("storagectl", vmName, "--name", "IDE", "--add", "ide", "--bootable", "on")
	runVboxCommand("storagectl", vmName, "--name", controllerName, "--add", "sata", "--bootable", "on")
	runVboxCommand("storageattach", vmName, "--storagectl", controllerName, "--port", "1", "--device", "0", "--type", "hdd", "--medium", vdiPath)

	runVboxCommand("startvm", vmName)
	fmt.Printf("VM %s started...", vmName)
	time.Sleep(30 * time.Second)
}

func cleanUpVM(vmName string) {
	conf := askForConfirmation("When you're ready to power off the VM, enter y.")
	if conf {

		fmt.Printf("Powering off VM %s\n...", vmName)
		runVboxCommand("controlvm", vmName, "poweroff")
		time.Sleep(15 * time.Second) // Make sure the poweroff completes so we don't get errors about it being locked
		fmt.Printf("Unregistering and deleting VM %s\n", vmName)
		runVboxCommand("unregistervm", vmName, "--delete")
	} else {
		fmt.Println("Ok, I'll wait...")
		time.Sleep(10 * time.Second)
		cleanUpVM(vmName)
	}
}

func downloadImage(imageURL string) string {
	if imageURL == "" {
		imageURL = latestImageURL
	}

	// TODO this could be a zip or an iso
	filePath := "raw_pi_dough.iso"
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

// Thanks to https://gist.github.com/r0l1/3dcbb0c8f6cfe9c66ab8008f55f8f28b
func askForConfirmation(s string) bool {
	reader := bufio.NewReader(os.Stdin)

	for {
		fmt.Printf("%s [y/n]: ", s)

		response, err := reader.ReadString('\n')
		if err != nil {
			log.Fatal(err)
		}

		response = strings.ToLower(strings.TrimSpace(response))

		if response == "y" || response == "yes" {
			return true
		} else if response == "n" || response == "no" {
			return false
		}
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
