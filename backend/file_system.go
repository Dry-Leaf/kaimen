package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"github.com/winfsp/cgofuse/fuse"
)

const root = `C:\Users\nobody\Documents\code\compiled\go\kaimen\test\`

var result_map = make(map[string]string)
var nams []string
var search_nam = []string{".", "..", "results"}
var initial_query = true

type KAIMEN_FS struct {
	fuse.FileSystemBase
}

func copyFusestatFromFileInfo(stat *fuse.Stat_t, info os.FileInfo) {
	// File mode (permissions + type)
	stat.Mode = uint32(info.Mode().Perm())
	if info.IsDir() {
		stat.Mode |= fuse.S_IFDIR
	} else {
		stat.Mode |= fuse.S_IFREG
	}

	// File size
	stat.Size = info.Size()

	// Number of links (1 for files, 2 for dirs)
	if info.IsDir() {
		stat.Nlink = 2
	} else {
		stat.Nlink = 1
	}

	// Timestamps: just use ModTime for all three
	t := info.ModTime()
	stat.Mtim.Sec = t.Unix()
	stat.Mtim.Nsec = int64(t.Nanosecond())
	stat.Atim.Sec = t.Unix()
	stat.Atim.Nsec = int64(t.Nanosecond())
	stat.Ctim.Sec = t.Unix()
	stat.Ctim.Nsec = int64(t.Nanosecond())
}

func (self *KAIMEN_FS) Open(path string, flags int) (errc int, fh uint64) {
	if flags&^fuse.O_RDONLY != 0 {
		return 0, uint64(fuse.EACCES) // deny write attempts
	}

	return 0, 0
}

func (self *KAIMEN_FS) Getattr(path string, stat *fuse.Stat_t, fh uint64) (errc int) {
	switch path {
	case "/":
		stat.Mode = fuse.S_IFDIR | 0555
		return 0
	case "/results":
		stat.Mode = fuse.S_IFDIR | 0555
		return 0
	default:
		var info os.FileInfo
		var err error

		_, filename := filepath.Split(path)
		real_path := result_map[filename]

		info, err = os.Stat(real_path)
		if err != nil {
			if os.IsNotExist(err) {
				fmt.Println("PATH DOES NOT EXIST:")
				fmt.Println(real_path)
				delete_file(real_path)
				return -int(fuse.ENOENT)
			}
			Err_check(err)
		}

		copyFusestatFromFileInfo(stat, info)
		return 0
	}
}

func (self *KAIMEN_FS) Read(path string, buff []byte, ofst int64, fh uint64) (n int) {
	_, filename := filepath.Split(path)
	real_path := result_map[filename]

	file, err := os.Open(real_path)
	if err != nil {
		if os.IsNotExist(err) {
			return -int(fuse.ENOENT)
		}
		Err_check(err)
	}
	defer file.Close()

	n, err = file.ReadAt(buff, ofst)
	if err != nil && err != io.EOF {
		return int(fuse.EIO)
	}

	return n
}

func (self *KAIMEN_FS) Readdir(path string,
	fill func(name string, stat *fuse.Stat_t, ofst int64) bool,
	ofst int64,
	fh uint64) (errc int) {

	var namp *[]string

	if path != "/results" {
		namp = &search_nam
	} else {
		for {
			if pending_remove.IsEmpty() {
				if initial_query {
					nams = append([]string{".", ".."}, query_recent()...)
				}
				namp = &nams
				break
			}
			time.Sleep(time.Second)
		}
	}

	// cnams = append([]string{".", ".."}, cnams...)
	for _, name := range *namp {
		fill(name, nil, 0)
	}

	return 0
}

func mount() {
	hellofs := &KAIMEN_FS{}
	host := fuse.NewFileSystemHost(hellofs)
	host.Mount("", os.Args[1:])
}
