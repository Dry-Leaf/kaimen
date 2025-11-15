package main

import (
	"context"
	"fmt"
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

type MessageType int64

const (
	counter MessageType = iota
	autosuggest
	updateconf
	userquery
	qcomplete
	createsource
	editsource
	reordersources
)

var last_word_reg = regexp.MustCompile(`\b[\w-]+$`)

type message struct {
	Type  MessageType `json:"Type"`
	Value any         `json:"Value"`
}

var (
	activeConn *websocket.Conn
	connMu     sync.Mutex
)

func update(mode MessageType) {
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

	var resp message

	switch mode {
	case counter:
		file_count := strconv.Itoa(get_count())
		resp = message{Type: counter, Value: file_count}
	case updateconf:
		resp = message{Type: updateconf, Value: ""}
	}

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

		var req message
		err = wsjson.Read(ctx, c, &req)

		if err != nil {
			log.Println(err)
			log.Println("No active client connected")
			connMu.Lock()
			if activeConn == c {
				activeConn = nil
			}
			connMu.Unlock()
			break
		}

		fmt.Println("MESSAGE RECEIVED")
		fmt.Println(req)
		fmt.Println(req.Type)

		switch req.Type {
		case counter:
			file_count := strconv.Itoa(get_count())
			resp := message{Type: counter, Value: file_count}
			fmt.Println("SENDING RESPONSE")
			fmt.Println(resp)
			wsjson.Write(ctx, c, resp)
		case autosuggest:
			lw := strings.TrimLeft(last_word_reg.FindString(req.Value.(string)), "-")

			var results []tag
			if lw != "" {
				results = get_suggestions(lw)
			}
			resp := message{Type: autosuggest, Value: results}

			wsjson.Write(ctx, c, resp)
		case userquery:
			if len(req.Value.(string)) > 0 {
				nams = append([]string{".", ".."}, query(req.Value.(string))...)
				empty_query = false
			} else {
				empty_query = true
			}

			resp := message{Type: qcomplete, Value: len(nams) - 2}
			wsjson.Write(ctx, c, resp)
		case createsource, editsource, reordersources:
			fmt.Println(req.Type)
			Edit_conf(req.Type, req.Value)
		default:
			fmt.Println(req.Value)
		}

	}
}

func server() {
	http.HandleFunc("/", handle)
	err := http.ListenAndServe("localhost:"+Web_socket_port, nil)
	log.Fatal(err)
}
