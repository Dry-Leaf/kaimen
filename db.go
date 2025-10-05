package main

import (
	"database/sql"
	"os"

	_ "github.com/mattn/go-sqlite3"
)

type MIRROR_FILE struct {
	md5       string
	extension string
	file_path string
}

const file_table = `CREATE TABLE files (
		md5 TEXT PRIMARY KEY,
		extension TEXT NOT NULL,
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

const new_image = `INSERT INTO files(md5,extension,file_path) VALUES(?,?,?)`

const new_tag = `INSERT INTO tags(name) VALUES(?)`

const new_relation = `INSERT INTO file_tags(md5, tag) VALUES(?,?)`

const image_exists = `SELECT COUNT(md5) FROM files WHERE md5 = ?`

const query_images = `SELECT * FROM files`

func dup_check(md5sum string) int {
	conn, err := sql.Open("sqlite3", "booru.db")
	Err_check(err)
	defer conn.Close()

	var result int

	err = conn.QueryRow(image_exists, md5sum).Scan(&result)
	Err_check(err)

	return result
}

func insert_metadata(md5sum, path, ext string, tags []string) {
	conn, err := sql.Open("sqlite3", "booru.db")
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	new_image_stmt, err := tx.Prepare(new_image)
	Err_check(err)
	new_image_stmt.Exec(md5sum, ext, path)

	new_relation_stmt, err := tx.Prepare(new_relation)
	Err_check(err)

	new_tag_stmt, err := tx.Prepare(new_tag)
	Err_check(err)

	for _, tag := range tags {
		new_tag_stmt.Exec(tag)
		new_relation_stmt.Exec(md5sum, tag)
	}

	tx.Commit()
}

func new_db() {
	file, err := os.Create("booru.db")
	Err_check(err)

	file.Close()

	conn, err := sql.Open("sqlite3", "booru.db")
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	for _, stmt := range []string{file_table, tag_table, file_tag_table} {
		statement, err := tx.Prepare(stmt)
		Err_check(err)
		statement.Exec()
	}

	tx.Commit()
}
