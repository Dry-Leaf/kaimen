package main

import (
	"fmt"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gabriel-vasile/mimetype"
	"github.com/rjeczalik/notify"
)

type SafeMap struct {
	data  sync.Map
	count atomic.Int64
}

type response struct {
	Type  string `json:"category"`
	Value string `json:"value"`
}

func (s *SafeMap) Store(key any) {
	if _, loaded := s.data.LoadOrStore(key, struct{}{}); !loaded {
		s.count.Add(1)
	}
}

func (s *SafeMap) Delete(key any) {
	if _, loaded := s.data.LoadAndDelete(key); loaded {
		s.count.Add(-1)
	}
}

func (s *SafeMap) Range(f func(key, value any) bool) {
	s.data.Range(f)
}

func (s *SafeMap) IsEmpty() bool {
	return s.count.Load() == 0
}

var pending_create SafeMap
var pending_remove SafeMap

func dequeue() {
	interval := time.Minute
	for range time.Tick(interval) {
		now := time.Now()
		pending_create.Range(func(key, _ any) bool {
			path := key.(string)

			info, err := os.Stat(path)
			if err != nil {
				pending_create.Delete(path)
				fmt.Println("deleted", path)
				return true
			}

			mtype, err := mimetype.DetectFile(path)
			Err_check(err)

			if now.Sub(info.ModTime()) >= interval {
				fmt.Println("About to process", path)
				go func(p string) {
					process(p, mtype.Extension())
					pending_create.Delete(p)
				}(path)
			}
			return true
		})

		if pending_create.IsEmpty() {
			pending_remove.Range(func(key, _ any) bool {
				path := key.(string)
				fmt.Println("from remove queue")
				fmt.Println(path)
				writeMu.Lock()
				delete_file(path)
				pending_remove.Delete(path)
				writeMu.Unlock()
				return true
			})
		}
	}
}

func dir_watch() {
	c := make(chan notify.EventInfo, 200)

	//maybe delete events could be recorded, if they were kept at the bottom of the queue somehow
	err := notify.Watch("test_images/...", c, notify.Create, notify.Remove)
	Err_check(err)

	defer notify.Stop(c)

	for {
		ei := <-c

		switch ei.Event() {
		case notify.Create:
			pending_create.Store(ei.Path())
		case notify.Remove:
			pending_remove.Store(ei.Path())
		}
	}
}
