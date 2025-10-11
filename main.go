package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
)

func Err_check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func init() {
	home, err := os.UserHomeDir()
	Err_check(err)
	db_path = filepath.Join(home, "booru.db")

	db_uri = fmt.Sprintf(`file:///%s?_foreign_keys=on`, filepath.ToSlash(db_path))
}

func main() {
	Read_conf()

	if _, err := os.Stat(db_path); err != nil {
		new_db()
	}

	//must be passed an absolute path
	filepath.WalkDir(`C:\Users\nobody\Documents\code\compiled\go\kaimen\test_images`, initial_crawl)

	go dir_watch()
	go dequeue()
	mount()
}
