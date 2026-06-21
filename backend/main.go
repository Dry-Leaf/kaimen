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

var exe_dir string

func Err_check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func open_front() {
	current := front_open.Load()

	search_exe := filepath.Join(exe_dir, "search.exe")

	if current {
		return
	} else {
		if front_open.CompareAndSwap(current, true) {
			cmd := exec.Command(search_exe)
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
	exePath, err := os.Executable()
	Err_check(err)
	exe_dir = filepath.Dir(exePath)

	file, err := os.OpenFile("error.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0666)
	Err_check(err)
	defer file.Close()

	log.SetOutput(file)
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	if _, err := os.Stat(db_path); err != nil {
		new_db()
	}

	Read_conf()
	Make_Conns()

	indexing = make(map[string]bool)
	initial_crawl()

	go inference_worker()
	go dequeue()
	go dequeue_inference()
	go server()
	go open_front()

	mount()
}
