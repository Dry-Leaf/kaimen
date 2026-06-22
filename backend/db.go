package main

import (
	"bytes"
	"compress/gzip"
	"database/sql"
	"fmt"
	"html"
	"io"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

var (
	db_uri         string
	db_path        string
	prev_md5sum    string
	prev_autosugg  string
	insert_counter = 0
)

type MIRROR_FILE struct {
	md5       string
	extension string
	file_path string
}

var meta_query_patterns = map[string]*regexp.Regexp{
	"name":     regexp.MustCompile(`name:(.+)`),
	"width":    regexp.MustCompile(`width:([<>])?(\d+)`),
	"height":   regexp.MustCompile(`height:([<>])?(\d+)`),
	"duration": regexp.MustCompile(`duration:([<>])?(\d+)([smh])`),
	"date":     regexp.MustCompile(`date:(\d+-\d\d-\d\d)(?:..(\d+-\d\d-\d\d))?`),
	"age":      regexp.MustCompile(`age:(\d+)(mo|[smhdwy])\.\.(\d+)(mo|[smhdwy])`),
}

var db_SQL = [...]string{
	`CREATE TABLE IF NOT EXISTS files (
		md5 TEXT PRIMARY KEY,
		extension TEXT NOT NULL,
		file_path TEXT NOT NULL,
		ignore INTEGER NOT NULL
	);`,
	// name, type, width, height, size(in bytes), mod time OR XMP Create Date, duration of videos(in seconds)
	// perception hash
	`CREATE TABLE IF NOT EXISTS metadata (
		md5 TEXT REFERENCES files(md5) ON DELETE CASCADE,
		property TEXT NOT NULL,
		numeric_value REAL,
		text_value TEXT,
		PRIMARY KEY (md5,property)
	);`,
	`CREATE TABLE IF NOT EXISTS tags (
		name TEXT PRIMARY KEY,
		freq INT NOT NULL,
		category INT NOT NULL
	);`,
	`CREATE TABLE IF NOT EXISTS file_tags (
		md5 TEXT REFERENCES files(md5) ON DELETE CASCADE,
		tag TEXT REFERENCES tags(name) ON DELETE CASCADE,
		inferred INTEGER,
		PRIMARY KEY (md5,tag)
	);`,
	`CREATE TRIGGER tag_increment
		AFTER INSERT ON file_tags
		BEGIN
			UPDATE tags
			SET freq = freq + 1
			WHERE name = NEW.tag;
		END;`,
	`CREATE TRIGGER tag_decrement
		AFTER DELETE ON file_tags
		BEGIN
			UPDATE tags
			SET freq = freq - 1
			WHERE name = OLD.tag;
		END;`,
}

// write statements & built queries
const (
	new_meta = `INSERT INTO metadata(md5,property,numeric_value,text_value) VALUES(?,?,?,?)
		ON CONFLICT(md5, property) DO NOTHING;`

	new_image = `INSERT INTO files(md5,extension,file_path,ignore) VALUES(?,?,?,?);`

	new_tag = `INSERT INTO tags(name, freq, category) VALUES(?, 0, 0)
		ON CONFLICT(name)
		DO UPDATE SET name = EXCLUDED.name
	 	RETURNING freq, category;`

	new_relation = `INSERT INTO file_tags(md5, tag, inferred) VALUES(?,?,?)
			ON CONFLICT(md5, tag) DO NOTHING;`

	edit_tag = `INSERT INTO tags(name, freq, category) VALUES(?1, 0, ?2)
		ON CONFLICT(name)
		DO UPDATE SET category = ?2;`

	delete_tag = `DELETE FROM tags WHERE name = ?;`

	update_path = `UPDATE files SET file_path = ? WHERE md5 = ?;`

	update_tag_cat = `UPDATE tags SET category = ? WHERE name = ?;`

	ignore_deletion = `UPDATE files SET ignore = FALSE WHERE md5 = ?;`

	deletion = `DELETE FROM files WHERE file_path = ?;`

	tag_clear = `DELETE FROM file_tags WHERE md5 = ?;`

	optimize = `PRAGMA optimize;`

	file_index = `CREATE INDEX idx_files_md5 ON files (md5);`

	file_tag_index = `CREATE INDEX idx_file_tags_md5_tag ON file_tags (md5, tag);`

	file_tag_rindex = `CREATE INDEX idx_file_tags_tag_md5 ON file_tags (tag, md5);`

	tag_index = `CREATE INDEX idx_tags_name_freq ON tags(name ASC, freq DESC);`

	query_head = `SELECT f.md5, f.extension, f.file_path FROM files f `

	exclude_inferred = `WITH confirmed_file_tags AS (SELECT * FROM file_tags WHERE inferred = 0) `

	ignored_query = `WHERE f.ignore = TRUE `

	query_include = `JOIN %s ft%[2]d ON ft%[2]d.md5 = f.md5 AND ft%[2]d.tag = "%s" `

	query_fuzzy_include = `JOIN %s ft%[2]d ON ft%[2]d.md5 = f.md5 AND ft%[2]d.tag LIKE "%s" `

	query_exclude = `LEFT JOIN %s fe%[2]d ON fe%[2]d.md5 = f.md5 AND fe%[2]d.tag = "%s" `

	query_exclude_where = `fe%d.md5 IS NULL `

	query_tail = `GROUP BY f.md5;`

	numeric_eq = `SELECT f.md5, f.extension, f.file_path FROM metadata RIGHT JOIN files f ON metadata.md5 = f.md5
		WHERE property == ? AND numeric_value == ?`

	numeric_gt = `SELECT f.md5, f.extension, f.file_path FROM metadata RIGHT JOIN files f ON metadata.md5 = f.md5
		WHERE property == ? AND numeric_value >= ?`

	numeric_lt = `SELECT f.md5, f.extension, f.file_path FROM metadata RIGHT JOIN files f ON metadata.md5 = f.md5
		WHERE property == ? AND numeric_value <= ?`

	text_like = `SELECT f.md5, f.extension, f.file_path FROM metadata RIGHT JOIN files f ON metadata.md5 = f.md5
		WHERE property == ? AND text_value LIKE '%' || ? ||'%'`

	specific_time_range = `SELECT f.md5, f.extension, f.file_path FROM metadata RIGHT JOIN files f ON metadata.md5 = f.md5
		WHERE property = "timestamp" AND
		numeric_value >= unixepoch(?)
		AND numeric_value <= unixepoch(?)`

	specific_day = `SELECT f.md5, f.extension, f.file_path FROM metadata RIGHT JOIN files f ON metadata.md5 = f.md5
		WHERE property = "timestamp" AND
		numeric_value >= unixepoch(?1)
		AND numeric_value < unixepoch(?1, '+1 day')`

	// weeks not built into sqlite, will need conversion logic
	modded_time_range = `SELECT f.md5, f.extension, f.file_path FROM metadata RIGHT JOIN files f ON metadata.md5 = f.md5
		WHERE property = "timestamp" AND
		numeric_value <= unixepoch('now', ?)
		AND numeric_value >= unixepoch('now', ?)`

	image_exists = `SELECT COUNT(md5), COALESCE(file_path, '') FROM files WHERE md5 = ?;`
)

type ReadSQL int

const (
	ignore_exists ReadSQL = iota
	query_recent_images
	file_count
	tag_query
	bg_query
	artist_query
	gather_query
	gather_artist
	gather_metadata
	path_query
)

// static queries
var readSQLStrs = [...]string{
	`SELECT COUNT(md5) FROM files WHERE md5 = ? AND ignore = TRUE;`,

	`SELECT md5, extension, file_path FROM files ORDER BY rowid DESC LIMIT 50;`,

	`SELECT COUNT(*) FROM files;`,

	`SELECT * FROM tags WHERE name LIKE ?1 || '%' AND freq >= ?2
		ORDER BY (name = ?1) DESC, freq DESC LIMIT ?3;`,

	`SELECT COUNT(*) FROM file_tags ft WHERE ft.md5 = ? AND ft.tag LIKE '%background'`,

	`SELECT COUNT(*) FROM file_tags ft JOIN tags t on ft.tag = t.name
		WHERE ft.md5 = ? AND t.category = '1'`,

	`SELECT tag FROM file_tags WHERE md5 = ?`,

	`SELECT tag FROM file_tags ft INNER JOIN tags t ON t.name = ft.tag WHERE md5 = ? AND t.category = 1`,

	`SELECT property, CAST(numeric_value AS INTEGER) as numeric_value, text_value FROM metadata WHERE md5 = ?`,

	`SELECT file_path FROM files WHERE md5 = ?`,
}

const Max_conns = 5

var readConns = make(chan []*sql.Stmt, Max_conns)

func Checkout() []*sql.Stmt {
	return <-readConns
}
func Checkin(c []*sql.Stmt) {
	readConns <- c
}

func Make_Conns() {
	prep := func(SQL string) *sql.Stmt {
		conn, err := sql.Open("sqlite3", db_uri)
		Err_check(err)
		stmt, err := conn.Prepare(SQL)
		Err_check(err)
		return stmt
	}

	for i := 0; i < Max_conns; i++ {
		var read_stmts []*sql.Stmt
		for _, str := range readSQLStrs {
			read_stmts = append(read_stmts, prep(str))
		}
		readConns <- read_stmts
	}
}

func gather_tags(md5sum string) map[string]string {
	stmts := Checkout()
	defer Checkin(stmts)

	gather_single_col := func(query ReadSQL, combiner string) string {
		var arr []string

		stmt := stmts[query]

		rows, err := stmt.Query(md5sum)
		if err != sql.ErrNoRows {
			Err_check(err)
		}
		defer rows.Close()

		for rows.Next() {
			var cval string
			err = rows.Scan(&cval)

			arr = append(arr, cval)
		}

		vals := strings.Join(arr, combiner)
		return vals
	}

	tags := gather_single_col(gather_query, " ")
	artists := gather_single_col(gather_artist, ", ")

	var path string

	path_query_stmt := stmts[path_query]

	err := path_query_stmt.QueryRow(md5sum).Scan(&path)
	if err != sql.ErrNoRows {
		Err_check(err)
	} else {
		return map[string]string{"path": "n/a", "tags": tags}
	}

	var timestamp string
	var filename string
	var width int64
	var height int64

	gather_metadata_stmt := stmts[gather_metadata]
	rows, err := gather_metadata_stmt.Query(md5sum)
	if err != sql.ErrNoRows {
		Err_check(err)
	}
	defer rows.Close()

	for rows.Next() {
		var (
			property      string
			numeric_value sql.NullInt64  // Wraps an int64 and a Valid bool
			text_value    sql.NullString // Wraps a string and a Valid bool
		)
		err = rows.Scan(&property, &numeric_value, &text_value)
		Err_check(err)

		switch property {
		case "timestamp":
			if numeric_value.Valid {
				unixTimeUTC := time.Unix(numeric_value.Int64, 0)
				timestamp = unixTimeUTC.Format(time.RFC1123)
			}
		case "name":
			if text_value.Valid {
				filename = text_value.String
			}
		case "width":
			if numeric_value.Valid {
				width = numeric_value.Int64
			}
		case "height":
			if numeric_value.Valid {
				height = numeric_value.Int64
			}
		}
	}

	dimensions := fmt.Sprintf("%d x %d", width, height)

	prev_md5sum = md5sum

	fmt.Println(map[string]string{"path": path, "tags": tags,
		"artists": artists, "timestamp": timestamp, "filename": filename, "dimension": dimensions})

	return map[string]string{"path": path, "tags": tags,
		"artists": artists, "timestamp": timestamp, "filename": filename, "dimension": dimensions}
}

func ignore_check(md5sum string) int {
	stmts := Checkout()
	defer Checkin(stmts)

	var result int

	ignore_check_stmt := stmts[ignore_exists]
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
		//fmt.Print("MOVED " + rpath + "TO " + path)
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

func get_count(query ReadSQL, params ...any) int {
	stmts := Checkout()
	defer Checkin(stmts)

	stmt := stmts[query]

	var result int

	stmt.QueryRow(params...).Scan(&result)

	return result
}

type tag struct {
	Name      string `json:"Name"`
	Freq      int    `json:"Freq"`
	Category  int    `json:"Category"`
	Remainder string `json:"Remainder"`
}

func get_suggestions(query string, min, limit float64) []tag {
	prev_autosugg = query

	stmts := Checkout()
	defer Checkin(stmts)

	tag_query_stmt := stmts[tag_query]

	rows, err := tag_query_stmt.Query(query, min, limit)
	Err_check(err)
	defer rows.Close()

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

func age_modifier_build(number, raw string) string {
	var val string
	switch raw {
	case "s":
		val = " seconds"
	case "m":
		val = " minutes"
	case "h":
		val = " hours"
	case "d":
		val = " days"
	case "mo":
		val = " months"
	case "y":
		val = " years"
	case "w":
		val = " days"

		n, err := strconv.Atoi(number)
		Err_check(err)
		n *= 7
		number = strconv.Itoa(n)
	}
	return "-" + number + val
}

func meta_query_build(pattern string, groups []string) (string, []any) {
	var fquery string
	var params []any

	switch pattern {
	case "name":
		fquery = text_like
		params = []any{pattern, groups[1]}
	case "duration":
		n, err := strconv.Atoi(groups[2])
		Err_check(err)

		if groups[3] == "m" {
			n *= 60
		}
		if groups[3] == "h" {
			n *= 3600
		}

		groups[2] = strconv.Itoa(n)
		fallthrough
	case "width", "height":
		params = []any{pattern, groups[2]}

		if groups[1] == "" {
			fquery = numeric_eq
		} else if groups[1] == ">" {
			fquery = numeric_gt
		} else {
			fquery = numeric_lt
		}
	case "date":
		if groups[2] != "" {
			fquery = specific_time_range
			params = []any{groups[1], groups[2]}
		} else {
			fquery = specific_day
			params = []any{groups[1]}
		}
	case "age":
		fquery = modded_time_range
		param1 := age_modifier_build(groups[1], groups[2])
		param2 := age_modifier_build(groups[3], groups[4])
		params = []any{param1, param2}
	}

	return fquery, params
}

func tag_query_build(q_string string) string {
	var fquery string
	var ft_table string
	tags := strings.Split(q_string, " ")

	if Inferred_enabled {
		fquery = query_head
		ft_table = "file_tags"
	} else {
		fquery = exclude_inferred + query_head
		ft_table = "confirmed_file_tags"
	}

	if len(tags) == 1 && strings.ToLower(tags[0]) == "ignored" {
		fquery += ignored_query
	} else {
		var exlude_where []string

		for i, tag := range tags {
			tag = strings.ToLower(tag)
			if len(tag) > 0 {
				var cq string
				if ctag, found := strings.CutPrefix(tag, "-"); found {
					cq = fmt.Sprintf(query_exclude, ft_table, i, ctag)
					exlude_where = append(exlude_where,
						fmt.Sprintf(query_exclude_where, ft_table, i))
				} else {
					cquery := query_include
					if strings.Contains(tag, "%") {
						cquery = query_fuzzy_include
					}
					cq = fmt.Sprintf(cquery, ft_table, i, tag)
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
	}
	return fquery + query_tail
}

func Edit_tag(name string, category float64) {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	edit_tag_stmt, err := tx.Prepare(edit_tag)
	Err_check(err)

	edit_tag_stmt.Exec(name, category)

	tx.Commit()
}

func Delete_tag(name string) {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	delete_tag_stmt, err := tx.Prepare(delete_tag)
	Err_check(err)

	delete_tag_stmt.Exec(name)

	tx.Commit()
}

func tag_iterate(md5sum string, tags []string, inferred bool, tx *sql.Tx) {
	new_relation_stmt, err := tx.Prepare(new_relation)
	Err_check(err)

	new_tag_stmt, err := tx.Prepare(new_tag)
	Err_check(err)

	update_tag_stmt, err := tx.Prepare(update_tag_cat)
	Err_check(err)

	for _, tag := range tags {
		tag := strings.ReplaceAll(html.UnescapeString(tag), `\/`, `/`)

		row := new_tag_stmt.QueryRow(tag)

		var freq int
		var category int
		err := row.Scan(&freq, &category)
		Err_check(err)

		if freq == 0 {
			if category == 0 {
				//fmt.Printf("new tag %s\n", tag)
				cat := get_tag_cat(tag)
				if cat != 0 {
					update_tag_stmt.Exec(cat, tag)
				}
			}
			if category == -1 {
				update_tag_stmt.Exec(0, tag)
			}
		}
		new_relation_stmt.Exec(md5sum, tag, inferred)
	}
}

func overwrite_tags(t_string string) {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	clear_stmt, err := tx.Prepare(tag_clear)
	Err_check(err)
	clear_stmt.Exec(prev_md5sum)

	tags := strings.Split(t_string, " ")

	tag_iterate(prev_md5sum, tags, false, tx)

	tx.Commit()
}

func query(q_string string) []string {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	var fquery string
	var params []any
	var nams []string

	meta_query := false
	var pattern string
	var groups []string

	for p, r := range meta_query_patterns {
		if g := r.FindStringSubmatch(q_string); g != nil {
			meta_query = true
			pattern = p
			groups = g
			break
		}
	}

	if meta_query {
		fquery, params = meta_query_build(pattern, groups)
	} else {
		fquery = tag_query_build(q_string)
	}

	fmt.Println("fquery")
	fmt.Println(fquery)

	file_rows, err := conn.Query(fquery, params...)
	if err != sql.ErrNoRows {
		Err_check(err)
	}
	defer file_rows.Close()

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

	stmts := Checkout()
	defer Checkin(stmts)

	query_ri_stmt := stmts[query_recent_images]

	file_rows, err := query_ri_stmt.Query()
	if err != sql.ErrNoRows {
		Err_check(err)
	}
	defer file_rows.Close()

	for file_rows.Next() {
		var cmirror MIRROR_FILE
		err = file_rows.Scan(&cmirror.md5, &cmirror.extension, &cmirror.file_path)
		Err_check(err)

		result_map[cmirror.md5+cmirror.extension] = cmirror.file_path

		nams = append(nams, cmirror.md5+cmirror.extension)
	}

	return nams
}

func insert_metadata(md5sum string, meta_data map[string]any) {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	new_meta_stmt, err := tx.Prepare(new_meta)
	Err_check(err)

	for property, value := range meta_data {
		var numeric bool
		switch property {
		case "name", "type", "phash":
			numeric = false
		case "duration":
			numeric = true
			if value.(float64) == 0 {
				continue
			}
		default:
			numeric = true
		}

		if numeric {
			new_meta_stmt.Exec(md5sum, property, value, nil)
		} else {
			new_meta_stmt.Exec(md5sum, property, nil, value)
		}
	}

	tx.Commit()
}

func insert_tags(md5sum, path, ext string, tags []string, to_ignore, prev_ignored, inferred bool) {
	conn, err := sql.Open("sqlite3", db_uri)
	Err_check(err)
	defer conn.Close()

	tx, err := conn.Begin()
	defer tx.Rollback()

	new_image_stmt, err := tx.Prepare(new_image)
	Err_check(err)
	new_image_stmt.Exec(md5sum, ext, path, to_ignore)

	if !to_ignore {
		tag_iterate(md5sum, tags, inferred, tx)
	}

	insert_counter += 1

	if insert_counter > 50 {
		optimize_stmt, err := tx.Prepare(optimize)
		Err_check(err)
		optimize_stmt.Exec()

		insert_counter = 0
	}

	if prev_ignored {
		ignore_deletion_stmt, err := tx.Prepare(ignore_deletion)
		Err_check(err)
		ignore_deletion_stmt.Exec(md5sum)
	}

	tx.Commit()
	update(counter)
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

	for _, stmt := range db_SQL {
		statement, err := tx.Prepare(stmt)
		Err_check(err)
		statement.Exec()
	}

	r, err := embedFS.ReadFile("insert_tags.sql.gz")
	Err_check(err)
	r2, err := gzip.NewReader(bytes.NewReader(r))
	defer r2.Close()
	tag_file, err := io.ReadAll(r2)

	_, err = tx.Exec(string(tag_file))
	Err_check(err)

	tx.Commit()
}
