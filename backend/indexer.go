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
	"sync/atomic"
	"time"

	"github.com/gabriel-vasile/mimetype"
	"github.com/opencontainers/selinux/pkg/pwalkdir"
)

const (
	md5sum_regex       = `\A[a-f0-9]{32}$`
	danbooru_tag_query = `https://danbooru.donmai.us/tags.json?search[name_matches]=`
)

var (
	supported = [...]string{"image/jpeg", "image/png", "image/gif", "image/jxl",
		"video/mp4", "video/webm"}
	writeMu  sync.Mutex
	indexMu  sync.Mutex
	indexing map[string]bool
)

func initial_crawl() {
	confMu.Lock()
	for _, dir := range Dirs {
		go crawl(dir)
	}
	confMu.Unlock()
}

var index_count atomic.Uint64
var tagdef_count atomic.Uint64

var meta_regex [4]*regexp.Regexp = [4]*regexp.Regexp{
	regexp.MustCompile(`"created_at":"([^"]*)?`),
	regexp.MustCompile(`width":([^,]*)?`),
	regexp.MustCompile(`height":([^,]*)?`),
	regexp.MustCompile(`"duration":([^,]*)?`),
}

func crawl(dir string) {
	_, err := os.Open(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return
		} else {
			Err_check(err)
		}
	}

	indexMu.Lock()
	indexing[dir] = true
	indexMu.Unlock()

	update(counter)

	pwalkdir.Walk(dir, index)

	indexMu.Lock()
	delete(indexing, dir)
	indexMu.Unlock()

	update(counter)

	dir_watch(dir)
}

func index(path string, d fs.DirEntry, err error) error {
	if err != nil {
		return err
	}

	if !d.IsDir() {
		mtype, err := mimetype.DetectFile(path)
		if err != nil {
			return nil
		}

		if slices.Contains(supported[:], mtype.String()) {
			info, err := os.Stat(path)
			if err != nil {
				return nil
			}
			process(path, mtype.Extension(), info)
		}
	}

	return nil
}

func process(path, ext string, info os.FileInfo) string {
	f, err := os.Open(path)
	if err != nil {
		if os.IsNotExist(err) {
			return ""
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
	// check db if file is ignored
	prev_ignored := ignore_check(md5sum) > 0
	if Ignore_enabled {
		if prev_ignored {
			//fmt.Println("ignoring: " + md5sum)
			return ""
		}
	}
	// check db if file already there
	result := dup_check(md5sum, path)
	if result > 0 {
		return ""
	}

	//fmt.Printf("process: %s, md5: %s \n", path, md5sum)

	if index_count.Load() > 9 {
		index_count.Store(0)
		time.Sleep(120 * time.Second)
	} else {
		index_count.Add(1)
		time.Sleep(7 * time.Second)
	}

	to_ignore := true
	tags, complete_meta, found_meta := get_tags(md5sum, ext)
	if tags != nil {
		//fmt.Printf("tags got for %s \n", path)
		to_ignore = false
	}
	insert_tags(md5sum, path, ext, tags, to_ignore, prev_ignored, false)

	meta := get_meta(path, ext, info, complete_meta, found_meta)
	insert_metadata(md5sum, meta)

	return md5sum

	//fmt.Printf("%s finished \n", path)
}

type cat struct {
	Category int `json:"category"`
}

func get_tag_cat(tag string) int {
	if tagdef_count.Load() > 9 {
		tagdef_count.Store(0)
		time.Sleep(120 * time.Second)
	} else {
		tagdef_count.Add(1)
		time.Sleep(7 * time.Second)
	}

	url := `https://danbooru.donmai.us/tags.json?search[name_matches]=` + tag

	resp, err := http.Get(url)
	Err_check(err)
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	Err_check(err)

	var dat []cat

	err = json.Unmarshal(body, &dat)
	counter := 2
	for err != nil {
		secs_to_wait := time.Duration(15 * counter)
		time.Sleep(secs_to_wait * time.Second)
		resp, err := http.Get(url)
		Err_check(err)

		body, err := io.ReadAll(resp.Body)
		Err_check(err)

		err = json.Unmarshal(body, &dat)
		resp.Body.Close()

		if counter > 16 {
			return 0
		}
		counter *= 2
	}

	if len(dat) > 0 {
		return dat[0].Category
	}

	return 0
}

func get_tags(md5sum, ext string) ([]string, bool, map[string]string) {
	confMu.Lock()
	defer confMu.Unlock()

	for _, booru := range Sources {
		url := booru.URL + md5sum
		if booru.API_QS != "" {
			url += booru.API_QS
		}

		//fmt.Println(url)
		resp, err := http.Get(url)
		if err != nil {
			continue
		}
		defer resp.Body.Close()

		body, err := io.ReadAll(resp.Body)
		Err_check(err)
		str_body := string(body)

		tag_block := booru.TAG_REGEX.FindStringSubmatch(str_body)
		if len(tag_block) > 0 {
			tags := strings.Split(tag_block[1], " ")

			meta_names := [4]string{"timestamp", "width", "height", "duration"}

			found_meta := make(map[string]string)

			complete_meta := true
			for i, rexp := range meta_regex {
				//duration irrelevant for non-videos
				if i == 3 && ext != ".mp4" && ext != ".webm" {
					continue
				}
				block := rexp.FindStringSubmatch(str_body)

				if block != nil && block[1] != "null" {
					found_meta[meta_names[i]] = block[1]
				} else {
					complete_meta = false
				}
			}

			return tags, complete_meta, found_meta
		}
	}
	return nil, false, nil
}
