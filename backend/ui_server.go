package main

import (
	"context"
	"log"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

// Message struct for JSON
type Message struct {
	Counter int    `json:"counter"`
	User    string `json:"user"`
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

	resp := map[string]string{"count": file_count}

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

		var v any
		err = wsjson.Read(ctx, c, &v)
		if err != nil {
			log.Println("No active client connected")
			connMu.Lock()
			if activeConn == c {
				activeConn = nil
			}
			connMu.Unlock()
			break
		}

		file_count := strconv.Itoa(get_count())

		resp := map[string]string{"count": file_count}

		log.Printf("received: %v", v)

		wsjson.Write(ctx, c, resp)
	}
}

func server() {
	http.HandleFunc("/", handle)
	err := http.ListenAndServe("localhost:8080", nil)
	log.Fatal(err)
}
