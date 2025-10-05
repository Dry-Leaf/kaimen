package main

import (
	"database/sql"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"syscall"

	"github.com/winfsp/cgofuse/fuse"
)

const root = `C:\Users\nobody\Documents\code\compiled\go\kaimen\test\`

var result_map = make(map[string]string)

type kaimen_fs struct {
	fuse.FileSystemBase
}

func errno(err error) int {
	if nil != err {
		return -int(err.(syscall.Errno))
	} else {
		return 0
	}
}

func copyFusestatFromFileInfo(stat *fuse.Stat_t, info os.FileInfo) {
	// File mode (permissions + type)
	stat.Mode = uint32(info.Mode().Perm())
	if info.IsDir() {
		stat.Mode |= syscall.S_IFDIR
	} else {
		stat.Mode |= syscall.S_IFREG
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

func (self *kaimen_fs) Open(path string, flags int) (errc int, fh uint64) {
	if flags&^syscall.O_RDONLY != 0 {
		return 0, uint64(syscall.EACCES) // deny write attempts
	}

	return 0, 0
}

func (self *kaimen_fs) Getattr(path string, stat *fuse.Stat_t, fh uint64) (errc int) {
	switch path {
	case "/":
		stat.Mode = fuse.S_IFDIR | 0555
		return 0
	case "/search":
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
				return -int(syscall.ENOENT)
			}
			Err_check(err)
		}

		copyFusestatFromFileInfo(stat, info)
		return 0
	}
}

func (self *kaimen_fs) Read(path string, buff []byte, ofst int64, fh uint64) (n int) {
	_, filename := filepath.Split(path)
	real_path := result_map[filename]

	file, err := os.Open(real_path)
	if err != nil {
		if os.IsNotExist(err) {
			return -int(syscall.ENOENT)
		}
		Err_check(err)
	}
	defer file.Close()

	n, err = file.ReadAt(buff, ofst)
	if err != nil && err != io.EOF {
		return int(syscall.EIO)
	}

	return n
}

func (self *kaimen_fs) Readdir(path string,
	fill func(name string, stat *fuse.Stat_t, ofst int64) bool,
	ofst int64,
	fh uint64) (errc int) {

	var nams []string

	if path != "/search" {
		nams = []string{".", "..", "search"}
	} else {
		conn, err := sql.Open("sqlite3", "booru.db")
		Err_check(err)
		defer conn.Close()

		file_rows, err := conn.Query(query_images)
		if err != sql.ErrNoRows {
			Err_check(err)
		}

		for file_rows.Next() {
			var cmirror mirror_file
			err = file_rows.Scan(&cmirror.md5, &cmirror.extension, &cmirror.file_path)
			Err_check(err)

			result_map[cmirror.md5+cmirror.extension] = cmirror.file_path

			nams = append(nams, cmirror.md5+cmirror.extension)
		}
	}

	nams = append([]string{".", ".."}, nams...)
	for _, name := range nams {
		fill(name, nil, 0)
	}

	fmt.Println(nams)

	return 0
}

func mount() {
	hellofs := &kaimen_fs{}
	host := fuse.NewFileSystemHost(hellofs)
	host.Mount("", os.Args[1:])
}
