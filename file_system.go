package main

/*
#cgo windows LDFLAGS: -L${SRCDIR}/winfsp/lib
*/
import "C"

import (
	"io"
	"os"
	"syscall"

	"github.com/winfsp/cgofuse/fuse"
)

const (
	filename = "hello"
	contents = "hello, world\n"
)

const test_path = `C:\Users\nobody\Documents\code\compiled\go\kaimen\test_images\test\fuck\more\7ea50c1cece31d98c345b05573bc6e8c.mp4`
const test_ext = `.mp4`

type fs struct {
	fuse.FileSystemBase
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

func (self *fs) Open(path string, flags int) (errc int, fh uint64) {
	if flags&^syscall.O_RDONLY != 0 {
		return 0, uint64(syscall.EACCES) // deny write attempts
	}

	return 0, 0
}

func (self *fs) Getattr(path string, stat *fuse.Stat_t, fh uint64) (errc int) {
	switch path {
	case "/":
		stat.Mode = fuse.S_IFDIR | 0555
		return 0
	case "/" + filename + test_ext:
		var info os.FileInfo
		var err error

		info, err = os.Stat(test_path)
		if err != nil {
			if os.IsNotExist(err) {
				return -int(syscall.ENOENT)
			}
			Err_check(err)
		}

		copyFusestatFromFileInfo(stat, info)
		return 0
	default:
		return -fuse.ENOENT
	}
}

func (self *fs) Read(path string, buff []byte, ofst int64, fh uint64) (n int) {
	file, err := os.Open(test_path)
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

func (self *fs) Readdir(path string,
	fill func(name string, stat *fuse.Stat_t, ofst int64) bool,
	ofst int64,
	fh uint64) (errc int) {
	fill(".", nil, 0)
	fill("..", nil, 0)
	fill(filename+test_ext, nil, 0)
	return 0
}

func mount() {
	hellofs := &fs{}
	host := fuse.NewFileSystemHost(hellofs)
	host.Mount("", os.Args[1:])
}
