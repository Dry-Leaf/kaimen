package main

import (
	"fmt"
	"os"
	"regexp"

	"github.com/BurntSushi/toml"
	"github.com/joho/godotenv"
)

type Source struct {
	NAME       string
	URL        string
	API_PARAMS string
	TAG_REGEX  *regexp.Regexp
}

var Sources []Source

func Read_conf() {
	tmp := make(map[string][]Source)

	_, err := toml.DecodeFile("config.toml", &tmp)
	Err_check(err)

	Sources = tmp["boards"]

	err = godotenv.Load()
	Err_check(err)

	for _, booru := range Sources {
		if booru.API_PARAMS != "" {
			login := os.Getenv(booru.NAME + "_LOGIN")
			api_key := os.Getenv(booru.NAME + "_API_KEY")
			booru.API_PARAMS = fmt.Sprintf(booru.API_PARAMS, login, api_key)
		}
	}

}
