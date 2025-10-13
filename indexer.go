package main

import (
	"crypto/md5"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/gabriel-vasile/mimetype"
)

const md5sum_regex = `\A[a-f0-9]{32}$`

var supported = [...]string{"image/jpeg", "image/png", "image/gif", "image/jxl",
	"video/mp4", "video/webm"}

func initial_crawl(path string, d fs.DirEntry, err error) error {
	if err != nil {
		return err
	}

	if !d.IsDir() {
		mtype, err := mimetype.DetectFile(path)
		Err_check(err)

		if slices.Contains(supported[:], mtype.String()) {
			process(path, mtype.Extension())
		}
	}

	return nil
}

func process(path, ext string) {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return
		} else {
			Err_check(err)
		}
	}
	defer f.Close()

	fmt.Println("Process", path)

	_, filename := filepath.Split(path)
	last_dot := strings.LastIndex(filename, ".")

	fnstem := func(fn string, ld int) string {
		if ld == -1 {
			return fn
		} else {
			return fn[:ld]
		}
	}(filename, last_dot)

	var md5sum string

	if lfn := len(fnstem); lfn >= 32 {
		fnstem = fnstem[lfn-32:]

		match, err := regexp.MatchString(md5sum_regex, fnstem)
		Err_check(err)

		if match {
			fmt.Println("MATCH")
			md5sum = fnstem
		}
	}

	if md5sum == "" {
		h := md5.New()
		_, err = io.Copy(h, f)
		Err_check(err)

		md5sum = fmt.Sprintf("%x", h.Sum(nil))
	}

	// check db if file already there
	result := dup_check(md5sum, path)
	if result > 0 {
		return
	}

	fmt.Println(md5sum)

	time.Sleep(7 * time.Second)

	tags := get_tags(md5sum)
	if tags != nil {
		insert_metadata(md5sum, path, ext, tags)
	}
}

func get_tags(md5sum string) []string {
	for _, booru := range Sources {
		url := booru.URL + md5sum
		if booru.API_PARAMS != "" {
			url += booru.API_PARAMS
		} else {
			fmt.Println(*booru)
		}

		fmt.Println(url)
		resp, err := http.Get(url)
		Err_check(err)
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		Err_check(err)

		tag_block := booru.TAG_REGEX.FindStringSubmatch(string(body))
		if len(tag_block) > 0 {
			tags := strings.Split(tag_block[1], " ")
			return tags
		}
	}
	return nil
}
