package main

import (
	"log"
	"os"
)

func Err_check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	Read_conf()

	if _, err := os.Stat("booru.db"); err != nil {
		new_db()
	}

	go dir_watch()
	go dequeue()
	select {}
}
