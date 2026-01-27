package main

import (
	"log"
	"os"

	"fyne.io/systray"
)

func Err_check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	Read_conf()

	if _, err := os.Stat(db_path); err != nil {
		new_db()
	}

	indexing = make(map[string]bool)
	initial_crawl()

	go dequeue()
	go server()
	go systray.Run(onReady, onExit)

	mount()
}
