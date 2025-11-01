package main

import (
	"embed"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"regexp"

	"github.com/BurntSushi/toml"
	"github.com/joho/godotenv"
)

type Config struct {
	Boards        []*SOURCE `toml:"boards"`
	Dirs          []string  `toml:"DIRS"`
	WebSocketPort string    `toml:"WEB_SOCKET_PORT"`
}

type SOURCE struct {
	NAME       string
	URL        string
	API_PARAMS string
	TAG_KEY    string
	TAG_REGEX  *regexp.Regexp
}

//go:embed config.toml
var embedFS embed.FS

var Sources []*SOURCE
var Web_socket_port string

func Read_conf() []string {
	var conf Config

	conf_dir, err := os.UserConfigDir()
	Err_check(err)
	conf_path := filepath.Join(conf_dir, "kaimen", "config.toml")

	os.MkdirAll(filepath.Join(conf_dir, "kaimen"), 0755)
	f, err := os.OpenFile(conf_path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0666)

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

	Sources = conf.Boards
	Web_socket_port = conf.WebSocketPort

	err = godotenv.Load(".env")
	Err_check(err)

	for _, booru := range Sources {
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

	home_dir, err := os.UserHomeDir()
	Err_check(err)

	var dirs []string

	for _, dir := range conf.Dirs {
		dirs = append(dirs, filepath.Join(home_dir, dir))
	}

	return dirs

	// for _, booru := range Sources {
	// 	fmt.Println(*booru)
	// }
}
