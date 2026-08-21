package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"sync"
	"time"
)

const (
	search_files  = `/get_files/search_files?tags=%s`
	search_tags   = `/add_tags/search_tags?search=%s`
	get_file      = `/get_files/file?file_id=%d`
	get_meta_data = `/get_files/file_metadata?file_ids=%s`
	sort_type     = `&file_sort_type=%d`
	sort_order    = `&file_sort_asc=%t`
	hy_access     = `&Hydrus-Client-API-Access-Key=`
	client_info   = `/client_info?`
	database_info = `/manage_database/mr_bones?`
)

type SortOrder int64

const (
	file_size SortOrder = iota
	duration
	import_time
	filetype
	random
	width
	height
	ratio
	number_of_pixels
	number_of_tags
	number_of_media_views
	total_media_viewtime
	approximate_bitrate
	has_audio
	modified_time
	framerate
	number_of_frames
	number_of_collection_files
	last_viewed_time
	archive_timestamp
	hash_hex
	pixel_hash_hex
	blurhash
	average_colour_l
	average_colour_c
	average_colour_gr
	average_colour_by
	average_colour_h
)

var hydrus_order_type = import_time
var hydrus_sort_asc = false

type hydrus_db_results struct {
	Boned_stats hydrus_stats `JSON:"boned_stats"`
}

type hydrus_stats struct {
	Num_inbox   int `JSON:"num_inbox"`
	Num_archive int `JSON:"num_archive"`
}

type hydrus_id_results struct {
	File_ids []int `JSON:"file_ids"`
}

type hydrus_metadata struct {
	File_id       int    `JSON:"file_id"`
	Ext           string `JSON:"ext"`
	Size          int64  `JSON:"size"`
	Time_modified int64  `JSON:"time_modified"`
}

type hydrus_metadata_results struct {
	Metadata []hydrus_metadata `JSON:"metadata"`
}

type hydrus_tag struct {
	Value string `JSON:"value"`
	Count int    `JSON:"count"`
}

type hydrus_tag_results struct {
	Tags []hydrus_tag `JSON:"tags"`
}

var hy_meta = [3]string{"width", "height", "duration"}

type Hydrus_conn struct {
	httpClient *http.Client
	fileCache  map[string][]byte
	cacheMu    sync.RWMutex
}

var hydrus_conn *Hydrus_conn

var cat_regex = regexp.MustCompile(`(\S+?):(\S+)`)

// do this on startup and before opening directory
func (hyc *Hydrus_conn) validate(hydrus_edit HYDRUS_CONF) bool {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	request_url := hydrus_edit.URL + client_info + hy_access + hydrus_edit.ACCESS_KEY

	req, err := http.NewRequestWithContext(ctx, "GET", request_url, nil)
	if err != nil {
		return false
	}

	resp, err := hyc.httpClient.Do(req)
	if err != nil {
		return false
	}

	cleanup := func() {
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}

	if resp.StatusCode != http.StatusOK {
		log.Println("invalid credentials")
		cleanup()
		return false
	}

	return true
}

func (hyc *Hydrus_conn) do_get(ctx context.Context, url string) (*http.Response, func(), error) {
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return nil, nil, fmt.Errorf("invalid request: %w", err)
	}

	resp, err := hyc.httpClient.Do(req)
	if err != nil {
		Hydrus_conf.ENABLED = false
		usuccess = false
		ustatus = "Hydrus connection failed. Integration has been disabled."

		clear(hy_nams)
		hydrus_conn.cacheMu.Lock()
		clear(hydrus_conn.fileCache)
		hydrus_conn.cacheMu.Unlock()

		defer update(counter)
		defer update(updateconf)
		defer update(updatestatus)

		return nil, nil, fmt.Errorf("network error: %w", err)
	}

	cleanup := func() {
		io.Copy(io.Discard, resp.Body)
		resp.Body.Close()
	}

	if resp.StatusCode != http.StatusOK {
		cleanup()
		return nil, nil, fmt.Errorf("bad status: %d", resp.StatusCode)
	}

	return resp, cleanup, nil
}

func (hyc *Hydrus_conn) get_bytes(request_url string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
	defer cancel()

	resp, cleanup, err := hyc.do_get(ctx, request_url)
	if err != nil {
		log.Print("get_bytes failure")
		return nil, err
	}
	defer cleanup()

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read body: %w", err)
	}

	return data, nil
}

func (hyc *Hydrus_conn) get_json(request_url string, target interface{}) error {
	ctx, cancel := context.WithTimeout(context.Background(), 1*time.Minute)
	defer cancel()

	resp, cleanup, err := hyc.do_get(ctx, request_url)
	if err != nil {
		log.Print("get_json failure")
		return err
	}
	defer cleanup()

	if err := json.NewDecoder(resp.Body).Decode(target); err != nil {
		return fmt.Errorf("failed to decode json: %w", err)
	}

	return nil
}

func (hyc *Hydrus_conn) process_ids(file_ids []int) []string {
	if len(file_ids) == 0 {
		return []string{}
	}
	idjson, err := json.Marshal(file_ids)
	Err_check(err)

	params := url.QueryEscape(string(idjson))
	request_url := Hydrus_conf.URL + fmt.Sprintf(get_meta_data, params) + hy_access + Hydrus_conf.ACCESS_KEY

	var metadata_results hydrus_metadata_results

	if err := hyc.get_json(request_url, &metadata_results); err != nil {
		log.Printf("Failed to fetch metadata: %v", err)
		return []string{}
	}

	var file_names []string

	for idx, md := range metadata_results.Metadata {
		mirror_name := fmt.Sprintf("hydrus_%d_%d%s", idx, md.File_id, md.Ext)
		file_names = append(file_names, mirror_name)
		hd_result_map[mirror_name] = md.File_id
		hd_meta_map[mirror_name] = md
	}

	return file_names
}

func (hyc *Hydrus_conn) collect_ids(tags []string) []int {
	hydrus_conn.cacheMu.Lock()
	if len(hydrus_conn.fileCache) > 50 {
		log.Println("clearing hydrus file cache")
		clear(hydrus_conn.fileCache)
	}
	hydrus_conn.cacheMu.Unlock()

	tjson, err := json.Marshal(tags)
	Err_check(err)

	params := url.QueryEscape(string(tjson))

	current_sort_type := fmt.Sprintf(sort_type, hydrus_order_type)
	current_sort_order := fmt.Sprintf(sort_order, hydrus_sort_asc)

	request_url := Hydrus_conf.URL + fmt.Sprintf(search_files, params) + hy_access + Hydrus_conf.ACCESS_KEY +
		current_sort_order + current_sort_type

	var id_results hydrus_id_results

	if err := hyc.get_json(request_url, &id_results); err != nil {
		log.Printf("Failed to fetch ids: %v", err)
		return make([]int, 0)
	}

	return id_results.File_ids
}

func (hyc *Hydrus_conn) get_total() int {
	request_url := Hydrus_conf.URL + database_info + hy_access + Hydrus_conf.ACCESS_KEY

	var db_results hydrus_db_results

	if err := hyc.get_json(request_url, &db_results); err != nil {
		log.Printf("Failed to db info: %v", err)
		return 0
	}

	return db_results.Boned_stats.Num_archive + db_results.Boned_stats.Num_inbox
}

func (hyc *Hydrus_conn) query_recent() []string {
	file_ids := hyc.collect_ids([]string{"system:limit = 50"})
	return hyc.process_ids(file_ids)
}

func (hyc *Hydrus_conn) query(q_string string) []string {
	raw_tags := strings.Split(q_string, " ")

	var tags []string

OUTER_META:
	for _, tag := range raw_tags {
		if len(tag) > 0 {
			limit_match := limit_regex.FindStringSubmatch(tag)
			if limit_match != nil {
				limit := limit_match[1]
				tags = append(tags, fmt.Sprintf("system:limit = %s", limit))
				continue
			}
			for _, meta := range hy_meta {
				rexp := meta_query_patterns[meta]
				meta_match := rexp.FindStringSubmatch(tag)

				if meta_match != nil {
					meta_tag := fmt.Sprintf("system:%s", meta)
					switch meta {
					case "width", "height":
						comparison := meta_match[1]
						if comparison == "" {
							comparison = "="
						}
						meta_tag += comparison + meta_match[2]
					case "duration":
						tags = append(tags, "system:has duration")
						comparison := meta_match[1]
						if comparison == "" {
							comparison = "="
						}

						time_units := "seconds"

						if meta_match[3] == "m" {
							time_units = "minutes"
						}
						if meta_match[3] == "h" {
							time_units = "hours"
						}

						meta_tag += fmt.Sprintf("%s%s%s", comparison, meta_match[2], time_units)
					}
					tags = append(tags, meta_tag)
					continue OUTER_META
				}
			}

			tags = append(tags, tag)
		}
	}

	file_ids := hyc.collect_ids(tags)
	return hyc.process_ids(file_ids)
}

func (hyc *Hydrus_conn) get_tags(query string, limit int) []tag {
	param := url.QueryEscape(query)
	request_url := Hydrus_conf.URL + fmt.Sprintf(search_tags, param) + hy_access + Hydrus_conf.ACCESS_KEY

	var tag_results hydrus_tag_results

	if err := hyc.get_json(request_url, &tag_results); err != nil {
		log.Printf("Failed to fetch tags: %v", err)
		return nil
	}

	results := make([]tag, len(tag_results.Tags))

	for idx, match := range tag_results.Tags[:min(limit, len(tag_results.Tags))] {
		cat := 0

		namespace := cat_regex.FindStringSubmatch(match.Value)

		if namespace != nil {
			switch namespace[1] {
			case "creator":
				cat = 1
			case "character", "person":
				cat = 4
			case "series", "studio", "photoset":
				cat = 3
			case "meta":
				cat = 5
			default:
				cat = 0
			}
		}

		results[idx] = tag{
			Name: match.Value, Freq: match.Count, Category: cat, Remainder: match.Value[len(query):]}
	}

	return results
}
