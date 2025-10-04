package main

import (
	"crypto/md5"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"slices"
	"strings"
	"time"

	"github.com/gabriel-vasile/mimetype"
)

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
			process(path)
		}
	}

	return nil
}

func process(path string) {
	fmt.Println(path)

	f, err := os.Open(path)
	Err_check(err)
	defer f.Close()

	h := md5.New()
	_, err = io.Copy(h, f)
	Err_check(err)

	md5sum := fmt.Sprintf("%x", h.Sum(nil))

	// check db if file already there
	result := dup_check(md5sum)
	if result > 0 {
		return
	}

	fmt.Println(md5sum)

	time.Sleep(7 * time.Second)

	tags := get_tags(md5sum)
	if tags != nil {
		insert_metadata(md5sum, path, tags)
	}
}

func get_tags(md5sum string) []string {
	for _, booru := range Sources {
		resp, err := http.Get(booru.URL + md5sum)
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
