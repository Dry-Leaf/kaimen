package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/winfsp/cgofuse/fuse"
)

var host *fuse.FileSystemHost

const root = `C:\Users\nobody\Documents\code\compiled\go\kaimen\test\`

var result_map = make(map[string]string)
var hd_result_map = make(map[string]int)
var hd_meta_map = make(map[string]hydrus_metadata)
var nams []string
var hy_nams []string
var search_nam = []string{".", "..", "results"}
var initial_query = true

type KAIMEN_FS struct {
	fuse.FileSystemBase
}

func copyFusestatFromHydrusMeta(stat *fuse.Stat_t, hmd hydrus_metadata) {
	stat.Mode = 0666
	stat.Mode |= fuse.S_IFREG
	stat.Size = hmd.Size
	stat.Nlink = 1
	t := time.Unix(hmd.Time_modified, 0)
	stat.Mtim.Sec = t.Unix()
	stat.Mtim.Nsec = int64(t.Nanosecond())
	stat.Atim.Sec = t.Unix()
	stat.Atim.Nsec = int64(t.Nanosecond())
	stat.Ctim.Sec = t.Unix()
	stat.Ctim.Nsec = int64(t.Nanosecond())
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
		var err error

		_, filename := filepath.Split(path)
		if strings.HasPrefix(filename, "hydrus") {
			info := hd_meta_map[filename]
			copyFusestatFromHydrusMeta(stat, info)
		} else {
			var info os.FileInfo
			real_path := result_map[filename]

			info, err = os.Stat(real_path)
			if err != nil {
				if os.IsNotExist(err) {
					delete_file(real_path)
					return -int(fuse.ENOENT)
				}
				Err_check(err)
			}
			copyFusestatFromFileInfo(stat, info)
		}

		return 0
	}
}

func (self *KAIMEN_FS) Read(path string, buff []byte, ofst int64, fh uint64) (n int) {
	_, filename := filepath.Split(path)

	if strings.HasPrefix(filename, "hydrus") {
		fileData, cached := hydrus_conn.fileCache[filename]

		if !cached {
			hd_id := hd_result_map[filename]
			request_url := hy_address + fmt.Sprintf(get_file, hd_id) + hy_access_param

			fileData, err := hydrus_conn.get_bytes(request_url)
			if err != nil {
				log.Printf("Hydrus fetch failed: %v", err)

				if strings.Contains(err.Error(), "connection refused") ||
					strings.Contains(err.Error(), "actively refused it") {
					return -int(fuse.ENOTCONN)
				}

				if strings.Contains(err.Error(), "404") || strings.Contains(err.Error(), "status: 404") {
					return -int(fuse.ENOENT)
				}
				return -int(fuse.EIO)
			}

			hydrus_conn.cacheMu.Lock()
			if hydrus_conn.fileCache == nil {
				hydrus_conn.fileCache = make(map[string][]byte)
			}
			hydrus_conn.fileCache[filename] = fileData
			hydrus_conn.cacheMu.Unlock()
		}

		if ofst >= int64(len(fileData)) {
			return 0
		}

		end := ofst + int64(len(buff))
		if end > int64(len(fileData)) {
			end = int64(len(fileData))
		}

		n = copy(buff, fileData[ofst:end])
		return n

	} else {
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
	}

	return n
}

func (self *KAIMEN_FS) Readdir(path string,
	fill func(name string, stat *fuse.Stat_t, ofst int64) bool,
	ofst int64,
	fh uint64) (errc int) {

	var namp *[]string
	var hnamp *[]string

	if path != "/results" {
		namp = &search_nam
	} else {
		if initial_query {
			nams = append([]string{".", ".."}, query_recent()...)
			if hydrus_enabled {
				hy_nams = hydrus_conn.query_recent()
			}
		}
		namp = &nams
		hnamp = &hy_nams
	}

	// cnams = append([]string{".", ".."}, cnams...)
	for _, name := range *namp {
		fill(name, nil, 0)
	}

	if hydrus_enabled {
		for _, name := range *hnamp {
			fill(name, nil, 0)
		}
	}

	return 0
}

func (self *KAIMEN_FS) Release(path string, fh uint64) (errc int) {
	_, filename := filepath.Split(path)

	if strings.HasPrefix(filename, "hydrus") {
		hydrus_conn.cacheMu.Lock()

		if _, exists := hydrus_conn.fileCache[filename]; exists {
			delete(hydrus_conn.fileCache, filename)
		}

		hydrus_conn.cacheMu.Unlock()
	}

	return 0
}

var shrine_loc string
var result_loc string

func mount() {
	mount_dir := exe_dir

	if owd := os.Getenv("OWD"); owd != "" {
		mount_dir = owd
	}

	shrine_loc = filepath.Join(mount_dir, "shrine")
	result_loc = filepath.Join(shrine_loc, "results")

	if runtime.GOOS == "windows" {
		os.RemoveAll(shrine_loc)
	} else {
		os.Remove(shrine_loc)
		err := os.MkdirAll(shrine_loc, 0755)
		Err_check(err)
	}

	hellofs := &KAIMEN_FS{}
	host = fuse.NewFileSystemHost(hellofs)
	host.Mount(shrine_loc, os.Args[1:])
}
