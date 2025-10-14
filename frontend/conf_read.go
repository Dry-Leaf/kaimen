package main

import (
	"fmt"
	"os"
	"regexp"

	"github.com/BurntSushi/toml"
	"github.com/joho/godotenv"
)

type SOURCE struct {
	NAME       string
	URL        string
	API_PARAMS string
	TAG_REGEX  *regexp.Regexp
}

var Sources []*SOURCE

func Read_conf() {
	tmp := make(map[string][]*SOURCE)

	_, err := toml.DecodeFile("config.toml", &tmp)
	Err_check(err)

	Sources = tmp["boards"]

	err = godotenv.Load()
	Err_check(err)

	for _, booru := range Sources {
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

	for _, booru := range Sources {
		fmt.Println(*booru)
	}
}
