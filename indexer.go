package main

import (
	"crypto/md5"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

func process(path string) {
	time.Sleep(7 * time.Second)

	f, err := os.Open(path)
	Err_check(err)
	defer f.Close()

	h := md5.New()
	_, err = io.Copy(h, f)
	Err_check(err)

	md5sum := fmt.Sprintf("%x", h.Sum(nil))
	fmt.Println(md5sum)

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
