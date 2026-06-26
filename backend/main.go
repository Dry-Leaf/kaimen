package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gofrs/flock"
)

var shutdownChan = make(chan struct{})

var front_open atomic.Bool

var exe_dir string

func Err_check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func open_front() {
	current := front_open.Load()

	search_exe := filepath.Join(exe_dir, SEARCH_NAME)

	if current {
		return
	} else {
		if front_open.CompareAndSwap(current, true) {
			cmd := exec.Command(search_exe)
			err := cmd.Start()
			Err_check(err)
		}
	}
}

func onExit() {
	close(shutdownChan)
}

func init() {
	home, err := os.UserHomeDir()
	Err_check(err)
	db_path = filepath.Join(home, ".booru.db")

	db_uri = fmt.Sprintf(`file:///%s?_foreign_keys=on&cache=private&_synchronous=NORMAL&_journal_mode=WAL`, filepath.ToSlash(db_path))
}

func lock_check(lock_path string) *flock.Flock {
	file_lock := flock.New(lock_path)

	locked, err := file_lock.TryLock()
	if err != nil {
		log.Fatalf("Error trying to acquire lock: %v", err)
	}
	if !locked {
		// Single-instance violation! Another instance holds the lock.
		log.Fatalf("Kaimen is already running.")
		return nil
	}

	return file_lock
}

func main() {
	lock_path := filepath.Join(os.TempDir(), "kaimen.lock")
	file_lock := lock_check(lock_path)

	exePath, err := os.Executable()
	Err_check(err)
	exe_dir = filepath.Dir(exePath)

	file, err := os.OpenFile("error.log", os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0666)
	Err_check(err)
	defer file.Close()

	log.SetOutput(file)
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	if _, err := os.Stat(db_path); err != nil {
		new_db()
	}

	Read_conf()
	Make_Conns()

	indexing = make(map[string]bool)
	initial_crawl()

	var wg sync.WaitGroup

	wg.Go(server)

	wg.Go(inference_worker)
	wg.Go(dequeue)
	wg.Go(dequeue_inference)

	go open_front()
	go mount()

	<-shutdownChan

	if httpServer != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Millisecond)
		defer cancel()

		if err := httpServer.Shutdown(ctx); err != nil {
			fmt.Printf("Server forced to shutdown: %v\n", err)
		}
	}

	if host != nil {
		un := host.Unmount()
		log.Print("Unmounted ", un)
	}
	close(inferQueue)

	wg.Wait()

	defer func() {
		file_lock.Unlock()
		os.Remove(lock_path)
	}()
}
