package main

import (
	"context"
	"log"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

var last_word_reg = regexp.MustCompile(`\b[\w-]+$`)

type request struct {
	Type  string `json:"Type"`
	Value string `json:"Value"`
}

type response struct {
	Type  string `json:"Type"`
	Value any    `json:"Value"`
}

var (
	activeConn *websocket.Conn
	connMu     sync.Mutex
)

func update() {
	connMu.Lock()
	if activeConn == nil {
		log.Println("No active client connected")
		connMu.Unlock()
		return
	}
	c := activeConn
	connMu.Unlock()

	ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
	defer cancel()

	file_count := strconv.Itoa(get_count())

	resp := response{Type: "counter", Value: file_count}

	err := wsjson.Write(ctx, c, resp)
	Err_check(err)
}

func handle(w http.ResponseWriter, r *http.Request) {
	c, err := websocket.Accept(w, r, nil)
	Err_check(err)
	defer c.CloseNow()

	connMu.Lock()
	activeConn = c
	connMu.Unlock()

	for {
		ctx := context.Background()

		var req request
		err = wsjson.Read(ctx, c, &req)
		if err != nil {
			log.Println("No active client connected")
			connMu.Lock()
			if activeConn == c {
				activeConn = nil
			}
			connMu.Unlock()
			break
		}

		switch req.Type {
		case "counter":
			file_count := strconv.Itoa(get_count())
			resp := response{Type: "counter", Value: file_count}
			wsjson.Write(ctx, c, resp)
		case "auto_suggest":
			lw := strings.TrimLeft(last_word_reg.FindString(req.Value), "-")

			var results []tag
			if lw != "" {
				results = get_suggestions(lw)
			}
			resp := response{Type: "autosuggest", Value: results}

			wsjson.Write(ctx, c, resp)
		case "query":
			if len(req.Value) > 0 {
				nams = append([]string{".", ".."}, query(req.Value)...)
				empty_query = false
			} else {
				empty_query = true
			}

			resp := response{Type: "qcomplete", Value: len(nams) - 2}
			wsjson.Write(ctx, c, resp)
		}

	}
}

func server() {
	http.HandleFunc("/", handle)
	err := http.ListenAndServe("localhost:"+Web_socket_port, nil)
	log.Fatal(err)
}
