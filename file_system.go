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
	filename = "hello.jpg"
	contents = "hello, world\n"
)

type fs struct {
	fuse.FileSystemBase
}

func (self *fs) Open(path string, flags int) (errc int, fh uint64) {
	switch path {
	case "/" + filename:
		return 0, 0
	default:
		return -fuse.ENOENT, ^uint64(0)
	}
}

func (self *fs) Getattr(path string, stat *fuse.Stat_t, fh uint64) (errc int) {
	switch path {
	case "/":
		stat.Mode = fuse.S_IFDIR | 0555
		return 0
	case "/" + filename:
		stat.Mode = fuse.S_IFREG | 0444
		stat.Size = int64(len(contents))
		return 0
	default:
		return -fuse.ENOENT
	}
}

func (self *fs) Read(path string, buff []byte, ofst int64, fh uint64) (n int) {
	file, err := os.Open(`C:\Users\nobody\Documents\code\compiled\go\kaimen\test_images\bf54eaa55b27c16a63bd376410a27531.jpg`)
	Err_check(err)
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
	fill(filename, nil, 0)
	return 0
}

func mount() {
	hellofs := &fs{}
	host := fuse.NewFileSystemHost(hellofs)
	host.Mount("", os.Args[1:])
}
