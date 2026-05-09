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

}
