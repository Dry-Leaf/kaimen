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
	// if _, err := os.Stat(db_path); err != nil {
	// 	new_db()
	// }

	Read_conf()

	// indexing = make(map[string]bool)
	// initial_crawl()

	// go dequeue()
	// go server()
	// go open_front()

	// mount()
	//
	// `D:\pictures-arc\arc23\641e251001a550631de01858a24a687e.webm`
	// `D:\pictures-arc\arc55\2cb4e866435ad3844f2391f85c4fe6fd.mp4`
	// //"C:\Users\nobody\Pictures\arc\arc55\cd79af9a9660ad08e8be92009b3818c4.png"
	// exif test
	//`D:\pictures-arc\arc23\180f6e381375ae328425332739aa9ff1.jpg`
	// D:\pictures-arc\arc23\7fe06158739e1884dfc12a1416d47ead.png
	_, _, found_meta := get_tags("87d15777ea1a7440871cc7fec40f0e62", ".gif")
	path := `D:\pictures-arc\arc23\87d15777ea1a7440871cc7fec40f0e62.gif`
	info, err := os.Stat(path)
	Err_check(err)
	results := get_meta(path, ".gif", info, false, found_meta)
	fmt.Println(results)
}
