package main

import (
	"bytes"
	"embed"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"sync"

	"github.com/BurntSushi/toml"
)

type Config struct {
	Boards         []SOURCE `toml:"boards"`
	Ignore_enabled bool     `toml:"IGNORE_ENABLED"`
	Dirs           []string `toml:"DIRS"`
}

type SOURCE struct {
	NAME       string
	URL        string
	API_PARAMS string
	API_QS     string
	TAG_KEY    string
	TAG_REGEX  *regexp.Regexp
	LOGIN      string
	API_KEY    string
}

//go:embed config.toml
//go:embed booru.db.gz
//go:embed kaimen.ico
var embedFS embed.FS

var (
	Sources        []SOURCE
	Dirs           []string
	confMu         sync.Mutex
	ustatus        bool
	Ignore_enabled bool
)

func gather_conf() Config {
	return Config{Boards: Sources, Dirs: Dirs, Ignore_enabled: Ignore_enabled}
}

func validate_source(booru SOURCE) bool {
	url := booru.URL
	if booru.API_PARAMS != "" {
		url += booru.API_QS
	}

	fmt.Println(url)
	_, err := http.Get(url)
	if err != nil {
		return false
	}
	return true
}

func api_qs_form(booru *SOURCE) {
	if booru.API_PARAMS != "" {
		login := booru.LOGIN
		api_key := booru.API_KEY

		if login == "" || api_key == "" {
			booru.API_QS = ""
		} else {
			booru.API_QS = fmt.Sprintf(booru.API_PARAMS, login, api_key)
		}
	}
}

func Source_process(conf Config) {
	Dirs = conf.Dirs
	Sources = conf.Boards
	Ignore_enabled = conf.Ignore_enabled

	for i := range Sources {
		booru := &Sources[i]

		booru.TAG_REGEX = regexp.MustCompile(`"` + booru.TAG_KEY + `":"([^"]*)?`)
		api_qs_form(booru)
	}
}

func Edit_conf(mode MessageType, data any) {
	var conf Config

	conf_dir, err := os.UserConfigDir()
	Err_check(err)
	conf_path := filepath.Join(conf_dir, "kaimen", "config.toml")

	confMu.Lock()
	defer confMu.Unlock()

	f, err := os.OpenFile(conf_path, os.O_WRONLY, 0666)
	Err_check(err)
	defer f.Close()

	_, err = toml.DecodeFile(conf_path, &conf)
	Err_check(err)

	update_front := false

	switch mode {
	case createsource:
		defer update(updatestatus)

		update_front = true
		cast_data := data.(map[string]interface{})

		new_source := SOURCE{NAME: cast_data["NAME"].(string), URL: cast_data["URL"].(string),
			API_PARAMS: cast_data["API_PARAMS"].(string), TAG_KEY: cast_data["TAG_KEY"].(string),
			LOGIN: cast_data["LOGIN"].(string), API_KEY: cast_data["API_KEY"].(string),
		}
		api_qs_form(&new_source)

		result := validate_source(new_source)
		if result {
			ustatus = true
			conf.Boards = append(conf.Boards, new_source)
		} else {
			ustatus = false
			return
		}
	case editsource:
		defer update(updatestatus)

		update_front = true
		cast_data := data.(map[string]interface{})

		new_source := SOURCE{NAME: cast_data["NAME"].(string), URL: cast_data["URL"].(string),
			API_PARAMS: cast_data["API_PARAMS"].(string), TAG_KEY: cast_data["TAG_KEY"].(string),
			LOGIN: cast_data["LOGIN"].(string), API_KEY: cast_data["API_KEY"].(string),
		}
		api_qs_form(&new_source)

		result := validate_source(new_source)
		if result {
			ustatus = true
			conf.Boards[int(cast_data["INDEX"].(float64))] = new_source
		} else {
			ustatus = false
			return
		}
	case deletesource:
		defer update(updatestatus)
		ustatus = true
		update_front = true

		index := int(data.(float64))
		conf.Boards = append(conf.Boards[:index], conf.Boards[index+1:]...)

	case reordersources:
		cast_data := data.([]interface{})
		for x, n := range cast_data {
			for y, o := range conf.Boards[x:] {
				if n == o.NAME {
					temp_source := conf.Boards[x]
					conf.Boards[x] = o
					conf.Boards[x+y] = temp_source
					break
				}
			}
		}
		fmt.Println(conf.Boards)
	case editignore:
		update_front = true
		Ignore_enabled = data.(bool)
		conf.Ignore_enabled = Ignore_enabled
	case newdirectory:
		update_front = true
		dir := data.(string)
		conf.Dirs = append(conf.Dirs, dir)
		Dirs = conf.Dirs

		go crawl(dir)
	case deletedirectory:
		update_front = true
		inputs := data.([]interface{})
		dir := inputs[0].(string)
		i := int(inputs[1].(float64))

		conf.Dirs[i] = conf.Dirs[len(conf.Dirs)-1]
		conf.Dirs = conf.Dirs[:len(conf.Dirs)-1]

		Dirs = conf.Dirs

		watch_kill.Store(dir, struct{}{})
		update(counter)
	}

	buf := new(bytes.Buffer)
	err = toml.NewEncoder(buf).Encode(conf)
	Err_check(err)
	err = os.WriteFile(conf_path, buf.Bytes(), 0644)
	Err_check(err)

	Source_process(conf)

	if update_front {
		update(updateconf)
	}
}

func Read_conf() {
	var conf Config

	conf_dir, err := os.UserConfigDir()
	Err_check(err)
	conf_path := filepath.Join(conf_dir, "kaimen", "config.toml")

	confMu.Lock()
	os.MkdirAll(filepath.Join(conf_dir, "kaimen"), 0755)
	f, err := os.OpenFile(conf_path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0644)

	if err == nil {
		default_conf, err := embedFS.ReadFile("config.toml")
		Err_check(err)

		_, err = f.Write(default_conf)
	} else {
		if !os.IsExist(err) {
			log.Fatal(err)
		}
	}
	f.Close()

	_, err = toml.DecodeFile(conf_path, &conf)
	Err_check(err)

	Source_process(conf)

	Dirs = conf.Dirs

	confMu.Unlock()
	for _, booru := range Sources {
		fmt.Println(booru)
	}
}
