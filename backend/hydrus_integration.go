package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

const (
	search_files  = `/get_files/search_files?tags=%s`
	get_file      = `/get_files/file?file_id=%d`
	get_meta_data = `/get_files/file_metadata?file_ids=%s`
	sort_order    = `&file_sort_asc=false`
	hy_access     = `&Hydrus-Client-API-Access-Key=`
	client_info   = `/client_info?`
)

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

var hy_meta = [3]string{"width", "height", "duration"}

type Hydrus_conn struct {
	httpClient *http.Client
	fileCache  map[string][]byte
	cacheMu    sync.RWMutex
}

var hydrus_conn *Hydrus_conn

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
		fmt.Println("invalid credentials")
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
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
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
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
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

	for _, md := range metadata_results.Metadata {
		mirror_name := fmt.Sprintf("hydrus_%d%s", md.File_id, md.Ext)
		file_names = append(file_names, mirror_name)
		hd_result_map[mirror_name] = md.File_id
		hd_meta_map[mirror_name] = md
	}

	fmt.Println(file_names)

	return file_names
}

func (hyc *Hydrus_conn) collect_ids(tags []string) []int {
	hydrus_conn.cacheMu.Lock()
	if len(hydrus_conn.fileCache) > 50 {
		fmt.Println("clearing hydrus file cache")
		clear(hydrus_conn.fileCache)
	}
	hydrus_conn.cacheMu.Unlock()

	tjson, err := json.Marshal(tags)
	Err_check(err)

	params := url.QueryEscape(string(tjson))
	request_url := Hydrus_conf.URL + fmt.Sprintf(search_files, params) + hy_access + Hydrus_conf.ACCESS_KEY + sort_order

	//fmt.Println(request_url)

	var id_results hydrus_id_results

	if err := hyc.get_json(request_url, &id_results); err != nil {
		log.Printf("Failed to fetch ids: %v", err)
		return make([]int, 0)
	}

	return id_results.File_ids
}

func (hyc *Hydrus_conn) get_count(tag string) int {
	return len(hyc.collect_ids([]string{tag}))
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
