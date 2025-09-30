package main

import (
	"database/sql"
	"os"

	_ "github.com/mattn/go-sqlite3"
)

const file_table = `CREATE TABLE files (
		md5 TEXT PRIMARY KEY,
		file_path TEXT NOT NULL
	)`

const tag_table = `CREATE TABLE tags (
		name TEXT PRIMARY KEY
	)`

const file_tag_table = `CREATE TABLE file_tags (
		md5 TEXT,
		tag TEXT,
		FOREIGN KEY(md5) REFERENCES files(md5),
		FOREIGN KEY(tag) REFERENCES tags(name)
	)`

func new_db() {
	file, err := os.Create("booru.db")
	Err_check(err)

	file.Close()

	conn, err := sql.Open("sqlite3", "booru.db")
	Err_check(err)
	defer conn.Close()

	for _, stmt := range []string{file_table, tag_table, file_tag_table} {
		statement, err := conn.Prepare(stmt)
		Err_check(err)
		statement.Exec()
	}
}
