package main

import (
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/gabriel-vasile/mimetype"
)

const (
	md5sum_regex       = `\A[a-f0-9]{32}$`
	danbooru_tag_query = `https://danbooru.donmai.us/tags.json?search[name_matches]=`
)

var (
	supported = [...]string{"image/jpeg", "image/png", "image/gif", "image/jxl",
		"video/mp4", "video/webm"}
	writeMu sync.Mutex
)

func initial_crawl(path string, d fs.DirEntry, err error) error {
	if err != nil {
		return err
	}

	if !d.IsDir() {
		mtype, err := mimetype.DetectFile(path)
		if err != nil {
			return nil
		}

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
			md5sum = fnstem
		}
	}

	if md5sum == "" {
		h := md5.New()
		_, err = io.Copy(h, f)
		Err_check(err)

		md5sum = fmt.Sprintf("%x", h.Sum(nil))
	}

	writeMu.Lock()
	defer writeMu.Unlock()
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

type cat struct {
	Category int `json:"category"`
}

func get_tag_cat(tag string) int {
	time.Sleep(3 * time.Second)
	url := `https://danbooru.donmai.us/tags.json?search[name_matches]=` + tag

	resp, err := http.Get(url)
	Err_check(err)
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	Err_check(err)

	var dat []cat

	err = json.Unmarshal(body, &dat)
	Err_check(err)

	if len(dat) > 0 {
		return dat[0].Category
	}

	return 0
}

func get_tags(md5sum string) []string {
	for _, booru := range Sources {
		url := booru.URL + md5sum
		if booru.API_PARAMS != "" {
			url += booru.API_PARAMS
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
