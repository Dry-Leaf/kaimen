package main

import (
	"bytes"
	"embed"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"sync"

	"github.com/BurntSushi/toml"
	"github.com/joho/godotenv"
)

type Config struct {
	Boards []SOURCE `toml:"boards"`
	Dirs   []string `toml:"DIRS"`
}

type SOURCE struct {
	NAME       string
	URL        string
	API_PARAMS string
	TAG_KEY    string
	TAG_REGEX  *regexp.Regexp
	LOGIN      string
	API_KEY    string
}

//go:embed config.toml
var embedFS embed.FS

var (
	Sources []SOURCE
	Dirs    []string
	confMu  sync.Mutex
)

func gather_conf() Config {
	return Config{Boards: Sources, Dirs: Dirs}
}

func Source_process(conf Config) {
	Dirs = conf.Dirs
	Sources = conf.Boards

	err := godotenv.Load(".env")
	Err_check(err)

	for i := range Sources {
		booru := &Sources[i]

		booru.TAG_REGEX = regexp.MustCompile(`"` + booru.TAG_KEY + `":"([^"]*)?`)
		if booru.API_PARAMS != "" {
			login := os.Getenv(booru.NAME + "_LOGIN")
			api_key := os.Getenv(booru.NAME + "_API_KEY")

			if login == "" || api_key == "" {
				booru.API_PARAMS = ""
			} else {
				booru.API_PARAMS = fmt.Sprintf(booru.API_PARAMS, login, api_key)
			}
		}
	}
}

func Edit_conf(mode MessageType, data any) {
	var conf Config

	conf_dir, err := os.UserConfigDir()
	Err_check(err)
	conf_path := filepath.Join(conf_dir, "kaimen", "config.toml")

	confMu.Lock()
	f, err := os.OpenFile(conf_path, os.O_WRONLY, 0666)
	Err_check(err)
	defer f.Close()

	_, err = toml.DecodeFile(conf_path, &conf)
	Err_check(err)

	update_front := false

	switch mode {
	case createsource:
		update_front = true
		cast_data := data.(map[string]interface{})
		new_source := SOURCE{NAME: cast_data["NAME"].(string), URL: cast_data["URL"].(string),
			API_PARAMS: cast_data["API_PARAMS"].(string), TAG_KEY: cast_data["TAG_KEY"].(string),
			LOGIN: cast_data["LOGIN"].(string), API_KEY: cast_data["API_KEY"].(string),
		}
		conf.Boards = append(conf.Boards, new_source)
	case editsource:
		update_front = true
		cast_data := data.(map[string]interface{})
		new_source := SOURCE{NAME: cast_data["NAME"].(string), URL: cast_data["URL"].(string),
			API_PARAMS: cast_data["API_PARAMS"].(string), TAG_KEY: cast_data["TAG_KEY"].(string),
			LOGIN: cast_data["LOGIN"].(string), API_KEY: cast_data["API_KEY"].(string),
		}
		for i, b := range conf.Boards {
			if b.NAME == cast_data["ORIGINAL_NAME"] {
				conf.Boards[i] = new_source
				break
			}
		}
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
	case newdirectory:
		update_front = true
		dir := data.(string)
		conf.Dirs = append(conf.Dirs, dir)
		Dirs = conf.Dirs

		go crawl(dir)
	}

	buf := new(bytes.Buffer)
	err = toml.NewEncoder(buf).Encode(conf)
	Err_check(err)
	err = os.WriteFile(conf_path, buf.Bytes(), 0644)
	Err_check(err)

	Source_process(conf)

	confMu.Unlock()

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
