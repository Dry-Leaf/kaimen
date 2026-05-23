package main

import (
	"context"
	"fmt"
	"log"
	"maps"
	"math/rand/v2"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"github.com/pkg/browser"
)

type MessageType int64

const (
	counter MessageType = iota
	autosuggest
	updateconf
	updatestatus
	userquery
	qcomplete
	createsource
	editsource
	deletesource
	reordersources
	editignore
	newdirectory
	deletedirectory
	editdirectory
	getconf
	gettags
	sendtags
	openresults
	kill
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

func Open_search_result() {
	err := browser.OpenFile("search/results")
	Err_check(err)
}

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
		//fmt.Println("sending counter")
		file_count := strconv.Itoa(get_count())
		indexMu.Lock()
		keys := slices.Sorted(maps.Keys(indexing))
		indexMu.Unlock()
		resp = message{Type: counter, Value: []interface{}{file_count, keys, len(Dirs) > 0, pending_create.count.Load()}}
	case updateconf:
		conf := gather_conf()
		resp = message{Type: getconf, Value: conf}
	case updatestatus:
		resp = message{Type: updatestatus, Value: []interface{}{ustatus, rand.IntN(10000)}}
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
			front_open.CompareAndSwap(true, false)
			connMu.Unlock()
			break
		}

		fmt.Println("MESSAGE RECEIVED")
		fmt.Println(req)

		switch req.Type {
		case counter:
			file_count := strconv.Itoa(get_count())
			//fmt.Println(file_count)
			indexMu.Lock()
			keys := slices.Sorted(maps.Keys(indexing))
			indexMu.Unlock()
			//fmt.Println(keys)
			resp := message{Type: counter, Value: []interface{}{file_count, keys, len(Dirs) > 0, pending_create.count.Load()}}
			err := wsjson.Write(ctx, c, resp)
			Err_check(err)
		case autosuggest:
			lw := strings.TrimLeft(last_word_reg.FindString(req.Value.([]interface{})[0].(string)), "-")

			var results []tag
			if lw != "" {
				results = get_suggestions(lw, req.Value.([]interface{})[1].(float64))
			}
			resp := message{Type: autosuggest, Value: results}

			err := wsjson.Write(ctx, c, resp)
			Err_check(err)
		case userquery:
			value := req.Value.(string)
			if len(value) > 0 {
				nams = append([]string{".", ".."}, query(value)...)
				initial_query = false
			} else {
				nams = append([]string{".", ".."}, query_recent()...)
			}

			resp := message{Type: qcomplete, Value: []int{len(nams) - 2, rand.IntN(10000)}}
			wsjson.Write(ctx, c, resp)
		case getconf:
			conf := gather_conf()
			resp := message{Type: getconf, Value: conf}
			wsjson.Write(ctx, c, resp)
		case gettags:
			info := gather_tags(req.Value.(string))
			fmt.Println("gathered info")
			fmt.Println(info)
			resp := message{Type: gettags, Value: info}
			wsjson.Write(ctx, c, resp)
		case sendtags:
			value := req.Value.(string)
			if len(value) > 0 {
				overwrite_tags(value)
			}
		case createsource, editsource, deletesource, reordersources, editignore, newdirectory, deletedirectory:
			Edit_conf(req.Type, req.Value)
		case openresults:
			Open_search_result()
		case kill:
			onExit()
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
