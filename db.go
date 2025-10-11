package main

import (
	"database/sql"
	"os"

	_ "github.com/mattn/go-sqlite3"
)

var db_uri string
var db_path string

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
		md5 TEXT REFERENCES files(md5) ON DELETE CASCADE,
		tag TEXT REFERENCES tags(name)
	)`

const new_image = `INSERT INTO files(md5,extension,file_path) VALUES(?,?,?)`

const new_tag = `INSERT INTO tags(name) VALUES(?)`

const new_relation = `INSERT INTO file_tags(md5, tag) VALUES(?,?)`

const image_exists = `SELECT COUNT(md5), COALESCE(file_path, '') FROM files WHERE md5 = ?`

const update_path = `UPDATE files SET file_path = ? WHERE md5 = ?`

const query_images = `SELECT * FROM files`

const deletion = `DELETE FROM files WHERE file_path = ?`

func dup_check(md5sum, path string) int {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	var result int
	var rpath string

	dup_check_stmt, err := tx.Prepare(image_exists)
	Err_check(err)
	dup_check_stmt.QueryRow(md5sum).Scan(&result, &rpath)

	if result > 0 && rpath != path {
		update_path_stmt, err := tx.Prepare(update_path)
		Err_check(err)
		update_path_stmt.Exec(path, md5sum)
	}

	tx.Commit()
	return result
}

func delete_file(path string) {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	delete_stmt, err := tx.Prepare(deletion)
	Err_check(err)
	delete_stmt.Exec(path)

	tx.Commit()
}

func insert_metadata(md5sum, path, ext string, tags []string) {
	conn, err := sql.Open("sqlite3", db_uri)
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
	file, err := os.Create(db_path)
	Err_check(err)

	file.Close()

	conn, err := sql.Open("sqlite3", db_uri)
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
