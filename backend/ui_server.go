package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
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
	getconf
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

		switch req.Type {
		case counter:
			file_count := strconv.Itoa(get_count())
			resp := message{Type: counter, Value: file_count}
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
		case getconf:
			conf := gather_conf()
			resp := message{Type: getconf, Value: conf}
			wsjson.Write(ctx, c, resp)
		case createsource, editsource, reordersources:
			Edit_conf(req.Type, req.Value)
		default:
			fmt.Println(req.Value)
		}

	}
}

func server() {
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	Err_check(err)
	defer listener.Close()

	addr := listener.Addr().(*net.TCPAddr)
	actualPort := addr.Port

	port_path := filepath.Join(os.TempDir(), "kaimen_port")
	err = os.WriteFile(port_path, []byte(strconv.Itoa(actualPort)), 0644)
	Err_check(err)

	mux := http.NewServeMux()
	mux.HandleFunc("/", handle)
	err = http.Serve(listener, mux)
	log.Fatal(err)
}
