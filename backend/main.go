package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sync/atomic"
)

var front_open atomic.Bool

func Err_check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func open_front() {
	current := front_open.Load()

	if current {
		return
	} else {
		if front_open.CompareAndSwap(current, true) {
			cmd := exec.Command("./search.exe")
			err := cmd.Start()
			Err_check(err)
		}
	}
}

func onExit() {
	os.Exit(0)
}

func init() {
	home, err := os.UserHomeDir()
	Err_check(err)
	db_path = filepath.Join(home, ".booru.db")

	db_uri = fmt.Sprintf(`file:///%s?_foreign_keys=on&cache=private&_synchronous=NORMAL&_journal_mode=WAL`, filepath.ToSlash(db_path))
}

func main() {
	if _, err := os.Stat(db_path); err != nil {
		new_db()
	}

	Read_conf()

	indexing = make(map[string]bool)
	initial_crawl()

	go inference_worker()
	go dequeue()
	go dequeue_inference()
	go server()
	go open_front()

	mount()
	//
	// `D:\pictures-arc\arc23\641e251001a550631de01858a24a687e.webm`
	// `D:\pictures-arc\arc55\2cb4e866435ad3844f2391f85c4fe6fd.mp4`
	// exif test
	//`D:\pictures-arc\arc23\180f6e381375ae328425332739aa9ff1.jpg`
	// D:\pictures-arc\arc23\7fe06158739e1884dfc12a1416d47ead.png
	// md5sum := "180f6e381375ae328425332739aa9ff1"
	// ext := ".jpg"
	// _, complete_meta, found_meta := get_tags(md5sum, ext)
	// path := `D:\pictures-arc\arc23\180f6e381375ae328425332739aa9ff1.jpg`
	// info, err := os.Stat(path)
	// Err_check(err)

	// fmt.Println("found_meta")
	// fmt.Println(found_meta)

	// results := get_meta(path, ext, info, complete_meta, found_meta)
	// insert_metadata(md5sum, results)
}
