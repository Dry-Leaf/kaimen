package main

import (
	"bytes"
	"compress/gzip"
	"database/sql"
	"fmt"
	"io"
	"os"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

var (
	db_uri         string
	db_path        string
	insert_counter = 0
)

type MIRROR_FILE struct {
	md5       string
	extension string
	file_path string
}

const (
	file_table = `CREATE TABLE IF NOT EXISTS files (
		md5 TEXT PRIMARY KEY,
		extension TEXT NOT NULL,
		file_path TEXT NOT NULL
	);`
	tag_table = `CREATE TABLE IF NOT EXISTS tags (
		name TEXT PRIMARY KEY,
		freq INT NOT NULL,
		category INT NOT NULL
	);`
	file_tag_table = `CREATE TABLE IF NOT EXISTS file_tags (
		md5 TEXT REFERENCES files(md5) ON DELETE CASCADE,
		tag TEXT REFERENCES tags(name)
	);`
	ignored_table = `CREATE TABLE IF NOT EXISTS ignored (
		md5 TEXT PRIMARY KEY
	);`

	new_image = `INSERT INTO files(md5,extension,file_path) VALUES(?,?,?);`

	ignore = `INSERT INTO ignored(md5) VALUES(?)
		ON CONFLICT(md5)
		DO NOTHING;`

	new_tag = `INSERT INTO tags(name, freq, category) VALUES(?, 1, 0)
		ON CONFLICT(name)
		DO UPDATE SET freq = freq + 1 RETURNING freq, category;`

	tag_decrement = `CREATE TRIGGER tag_decrement
		AFTER DELETE ON file_tags
		BEGIN
			UPDATE tags
			SET freq = freq - 1
			WHERE name = OLD.tag;
		END;`

	new_relation = `INSERT INTO file_tags(md5, tag) VALUES(?,?);`

	ignore_exists = `SELECT COUNT(md5) FROM ignored WHERE md5 = ?;`

	image_exists = `SELECT COUNT(md5), COALESCE(file_path, '') FROM files WHERE md5 = ?;`

	update_path = `UPDATE files SET file_path = ? WHERE md5 = ?;`

	update_tag_cat = `UPDATE tags SET category = ? WHERE name = ?;`

	query_recent_images = `SELECT * FROM files LIMIT 50;`

	ignore_deletion = `DELETE FROM ignored WHERE md5 = ?;`

	deletion = `DELETE FROM files WHERE file_path = ?;`

	optimize = `PRAGMA optimize;`

	file_index = `CREATE INDEX idx_files_md5 ON files (md5);`

	file_tag_index = `CREATE INDEX idx_file_tags_md5_tag ON file_tags (md5, tag);`

	file_tag_rindex = `CREATE INDEX idx_file_tags_tag_md5 ON file_tags (tag, md5);`

	tag_index = `CREATE INDEX idx_tags_name_freq ON tags(name ASC, freq DESC);`

	file_count = `SELECT COUNT(*) FROM files;`

	tag_query = `SELECT * FROM tags WHERE name LIKE ? || '%' AND freq > 0 ORDER BY freq DESC LIMIT 10;`

	query_head = `SELECT f.* FROM files f `

	query_include = `JOIN file_tags ft%[1]d ON ft%[1]d.md5 = f.md5 AND ft%[1]d.tag = "%s" `

	query_fuzzy_include = `JOIN file_tags ft%[1]d ON ft%[1]d.md5 = f.md5 AND ft%[1]d.tag LIKE "%s" `

	query_exclude = `LEFT JOIN file_tags fe%[1]d ON fe%[1]d.md5 = f.md5 AND fe%[1]d.tag = "%s" `

	query_exclude_where = `fe%d.md5 IS NULL `

	query_tail = `GROUP BY f.md5;`

	// need this where clause for exluclusion
	// WHERE fe1.md5 IS NULL AND fe2.md5 IS NULL;
	//
	// SELECT f.file_path FROM files f
	// JOIN file_tags ft1 ON ft1.md5 = f.md5 AND ft1.tag = 'include_tag1'
	// JOIN file_tags ft2 ON ft2.md5 = f.md5 AND ft2.tag = 'include_tag2'
	// LEFT JOIN file_tags fe1 ON fe1.md5 = f.md5 AND fe1.tag = 'exclude_tag1'
	// LEFT JOIN file_tags fe2 ON fe2.md5 = f.md5 AND fe2.tag = 'exclude_tag2'
	// WHERE fe1.md5 IS NULL AND fe2.md5 IS NULL;
)

func ignore_check(md5sum string) int {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	var result int

	ignore_check_stmt, err := tx.Prepare(ignore_exists)
	Err_check(err)
	ignore_check_stmt.QueryRow(md5sum).Scan(&result)

	return result
}

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
		fmt.Print("MOVED " + rpath + "TO " + path)
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
	update(counter)
}

func get_count() int {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	var result int

	conn.QueryRow(file_count).Scan(&result)

	return result
}

type tag struct {
	Name      string `json:"Name"`
	Freq      int    `json:"Freq"`
	Category  int    `json:"Category"`
	Remainder string `json:"Remainder"`
}

func get_suggestions(query string) []tag {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	rows, err := conn.Query(tag_query, query)
	Err_check(err)

	var result []tag

	for rows.Next() {
		var ctag tag
		err = rows.Scan(&ctag.Name, &ctag.Freq, &ctag.Category)

		rem := ctag.Name[len(query):]
		ctag.Remainder = rem

		result = append(result, ctag)
	}

	return result
}

func query(q_string string) []string {
	var nams []string

	tags := strings.Split(q_string, " ")

	fquery := query_head
	var exlude_where []string

	for i, tag := range tags {
		if len(tag) > 1 {
			var cq string
			if ctag, found := strings.CutPrefix(tag, "-"); found {
				cq = fmt.Sprintf(query_exclude, i, ctag)
				exlude_where = append(exlude_where,
					fmt.Sprintf(query_exclude_where, i))
			} else {
				cquery := query_include
				if strings.Contains(tag, "%") {
					cquery = query_fuzzy_include
				}
				cq = fmt.Sprintf(cquery, i, tag)
			}
			fquery += cq
		}
	}

	if len(exlude_where) > 0 {
		fquery += `WHERE `
		for i, clause := range exlude_where {
			if i > 0 {
				fquery += `AND `
			}
			fquery += clause
		}
	}

	fmt.Print(fquery)

	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	file_rows, err := conn.Query(fquery + query_tail)
	if err != sql.ErrNoRows {
		Err_check(err)
	}

	for file_rows.Next() {
		var cmirror MIRROR_FILE
		err = file_rows.Scan(&cmirror.md5, &cmirror.extension, &cmirror.file_path)
		Err_check(err)

		result_map[cmirror.md5+cmirror.extension] = cmirror.file_path

		nams = append(nams, cmirror.md5+cmirror.extension)
	}

	return nams
}

func query_recent() []string {
	var nams []string

	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	file_rows, err := conn.Query(query_recent_images)
	if err != sql.ErrNoRows {
		Err_check(err)
	}

	for file_rows.Next() {
		var cmirror MIRROR_FILE
		err = file_rows.Scan(&cmirror.md5, &cmirror.extension, &cmirror.file_path)
		Err_check(err)

		result_map[cmirror.md5+cmirror.extension] = cmirror.file_path

		nams = append(nams, cmirror.md5+cmirror.extension)
	}

	return nams
}

func insert_ignore(md5sum string) {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	ignore_stmt, err := tx.Prepare(ignore)
	Err_check(err)
	ignore_stmt.Exec(md5sum)

	tx.Commit()
}

func insert_metadata(md5sum, path, ext string, tags []string, ignore_result bool) {
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

	fmt.Printf("%s tag cats \n", path)

	for _, tag := range tags {
		row := new_tag_stmt.QueryRow(tag)

		var freq int
		var category int
		err := row.Scan(&freq, &category)
		Err_check(err)

		if freq == 1 {
			if category == 0 {
				fmt.Printf("new tag %s\n", tag)
				cat := get_tag_cat(tag)
				if cat != 0 {
					update_tag_stmt, err := tx.Prepare(update_tag_cat)
					Err_check(err)
					update_tag_stmt.Exec(cat, tag)
				}
			}
			if category == -1 {
				fmt.Printf("existing tag %s\n", tag)
				update_tag_stmt, err := tx.Prepare(update_tag_cat)
				Err_check(err)
				update_tag_stmt.Exec(0, tag)
			}
		} else {
			fmt.Printf("existing tag %s\n", tag)
		}
		new_relation_stmt.Exec(md5sum, tag)
	}

	fmt.Printf("%s tag cats finished \n", path)

	insert_counter += 1

	if insert_counter > 50 {
		optimize_stmt, err := tx.Prepare(optimize)
		Err_check(err)
		optimize_stmt.Exec()

		insert_counter = 0
	}

	if ignore_result {
		ignore_deletion_stmt, err := tx.Prepare(ignore_deletion)
		Err_check(err)
		ignore_deletion_stmt.Exec(md5sum)
	}

	tx.Commit()
	update(counter)
}

func new_db() {
	r, err := embedFS.ReadFile("booru.db.gz")
	Err_check(err)
	r2, err := gzip.NewReader(bytes.NewReader(r))
	defer r2.Close()
	empty_db, err := io.ReadAll(r2)

	err = os.WriteFile(db_path, empty_db, 0644)
	Err_check(err)
}
