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
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
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
	editinferred
	newdirectory
	deletedirectory
	editdirectory
	edittag
	deletetag
	getconf
	gettags
	sendtags
	openresults
	kill
)

var last_word_reg = regexp.MustCompile(`(?:\s|\b|^)[\S]+$`)

type message struct {
	Type  MessageType `json:"Type"`
	Value any         `json:"Value"`
}

var (
	activeConn *websocket.Conn
	connMu     sync.Mutex
	httpServer *http.Server
)

func Open_and_select(path string) error {
	var cmd *exec.Cmd

	switch runtime.GOOS {
	case "windows":
		winPath := filepath.Clean(path)
		cmd = exec.Command("explorer.exe", "/select,", winPath)

	case "darwin":
		cmd = exec.Command("open", "-R", path)

	case "linux":
		dbusDest := "org.freedesktop.FileManager1"
		dbusPath := "/org/freedesktop/FileManager1"
		dbusFunc := "org.freedesktop.FileManager1.ShowItems"

		fileURI := fmt.Sprintf("file://%s", path)
		cmd = exec.Command("dbus-send", "--session",
			"--dest="+dbusDest, dbusPath, dbusFunc,
			"array:string:"+fileURI, "string:")

	default:
		return fmt.Errorf("unsupported platform: %s", runtime.GOOS)
	}

	if cmd == nil {
		return fmt.Errorf("command was not initialized properly")
	}

	err := cmd.Start()
	if err != nil {
		return err
	}

	return cmd.Process.Release()
}

func Open_search_result(path string) {
	if path == "" {
		err := browser.OpenFile("shrine/results")
		Err_check(err)
	} else {
		err := Open_and_select(path)
		fmt.Println("ERROR")
		fmt.Println(err)
		Err_check(err)
	}
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
		file_count := get_count(file_count)
		indexMu.Lock()
		keys := slices.Sorted(maps.Keys(indexing))
		indexMu.Unlock()
		pending_count := pending_create.count.Load() + pending_infer.count.Load()
		resp = message{Type: counter, Value: []interface{}{file_count, keys, len(Dirs) > 0, pending_count}}
		fmt.Println(resp)
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
			current := db_creation.Load()

			if current {
				resp := message{Type: counter, Value: []interface{}{-1, []string{}, true, 0}}
				err := wsjson.Write(ctx, c, resp)
				Err_check(err)
			} else {
				file_count := get_count(file_count)

				indexMu.Lock()
				keys := slices.Sorted(maps.Keys(indexing))
				indexMu.Unlock()

				resp := message{Type: counter, Value: []interface{}{file_count, keys, len(Dirs) > 0, pending_create.count.Load()}}
				err := wsjson.Write(ctx, c, resp)
				Err_check(err)
			}
		case autosuggest:
			full_body := req.Value.([]interface{})[0].(string)
			cursor_position := int(req.Value.([]interface{})[1].(float64))
			to_cursor_body := full_body[:cursor_position]

			lw := strings.Trim(last_word_reg.FindString(to_cursor_body), "- ")

			var results []tag
			if lw != "" {
				results = get_suggestions(lw, req.Value.([]interface{})[2].(float64), req.Value.([]interface{})[3].(float64))
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
		case createsource, editsource, deletesource, reordersources,
			editignore, editinferred, newdirectory, deletedirectory:
			Edit_conf(req.Type, req.Value)
		case openresults:
			value := req.Value.(string)
			Open_search_result(value)
		case edittag:
			Edit_tag(req.Value.([]interface{})[0].(string), req.Value.([]interface{})[1].(float64))

			var results []tag
			results = get_suggestions(prev_autosugg, float64(0), float64(7))
			resp := message{Type: autosuggest, Value: results}

			err := wsjson.Write(ctx, c, resp)
			Err_check(err)
		case deletetag:
			Delete_tag(req.Value.(string))

			var results []tag
			results = get_suggestions(prev_autosugg, float64(0), float64(7))
			resp := message{Type: autosuggest, Value: results}

			err := wsjson.Write(ctx, c, resp)
			Err_check(err)
		case kill:
			onExit()
		default:
			fmt.Println(req.Value)
		}

	}
}

func server() {
	port_path := filepath.Join(os.TempDir(), "kaimen_port")

	defer os.Remove(port_path)

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	Err_check(err)
	defer listener.Close()

	addr := listener.Addr().(*net.TCPAddr)
	actualPort := addr.Port

	err = os.WriteFile(port_path, []byte(strconv.Itoa(actualPort)), 0644)
	Err_check(err)

	mux := http.NewServeMux()
	mux.HandleFunc("/", handle)

	httpServer = &http.Server{
		Handler: mux,
	}

	httpServer.Serve(listener)
}
