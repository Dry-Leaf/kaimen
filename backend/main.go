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
	db_path = filepath.Join(home, ".booru.db")

	db_uri = fmt.Sprintf(`file:///%s?_foreign_keys=on&cache=private&_synchronous=NORMAL&_journal_mode=WAL`, filepath.ToSlash(db_path))
}

func main() {
	dirs := Read_conf()

	if _, err := os.Stat(db_path); err != nil {
		new_db()
	}

	for _, dir := range dirs {
		go func() {
			filepath.WalkDir(dir, initial_crawl)
		}()
		go dir_watch(dir)
	}

	go dequeue()
	go server()

	mount()
}
