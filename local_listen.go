package main

import (
	"fmt"
	"os"
	"sync"
	"time"

	"github.com/gabriel-vasile/mimetype"
	"github.com/rjeczalik/notify"
)

var pending sync.Map

func dequeue() {
	interval := 30 * time.Second
	for range time.Tick(interval) {
		func() {
			now := time.Now()
			pending.Range(func(key, _ any) bool {
				path := key.(string)

				mtype, err := mimetype.DetectFile(path)
				Err_check(err)

				info, err := os.Stat(path)
				if err != nil {
					pending.Delete(path)
					fmt.Println("deleted", path)
					return true
				}

				fmt.Println(path)

				if now.Sub(info.ModTime()) >= interval {
					go func(p string) {
						process(p, mtype.Extension())
						pending.Delete(p)
					}(path)
				}
				return true
			})
		}()
	}
}

func dir_watch() {
	c := make(chan notify.EventInfo, 200)

	err := notify.Watch("test_images/...", c, notify.Create, notify.Remove)
	Err_check(err)

	defer notify.Stop(c)

	for {
		ei := <-c

		pending.LoadOrStore(ei.Path(), nil)
	}
}
