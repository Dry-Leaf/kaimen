package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gofrs/flock"
)

var exe_dir string

var shutdownChan = make(chan struct{})

var front_open atomic.Bool
var db_creation atomic.Bool

func Err_check(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func open_front() {
	current := front_open.Load()

	if current {
		return
	} else {
		if front_open.CompareAndSwap(current, true) {
			binary_path := filepath.Join(exe_dir, "search")

			cmd := exec.Command(binary_path)
			err := cmd.Start()
			Err_check(err)
		}
	}
}

func onExit() {
	close(shutdownChan)
}

func init() {
	hydrus_conn = &Hydrus_conn{
		httpClient: &http.Client{
			Transport: &http.Transport{
				MaxIdleConns:        100,
				MaxIdleConnsPerHost: 100,
				IdleConnTimeout:     2 * time.Minute,
			},
		},
		fileCache: make(map[string][]byte),
	}

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
	exePath, err := os.Executable()
	Err_check(err)

	exe_dir = filepath.Dir(exePath)
	if appDir := os.Getenv("APPDIR"); appDir != "" {
		exe_dir = appDir
	}

	infer_tags = infer_tags_closure()

	lock_path := filepath.Join(os.TempDir(), "kaimen.lock")
	file_lock := lock_check(lock_path)

	base_log_dir, err := os.UserCacheDir()
	Err_check(err)

	appLogDir := filepath.Join(base_log_dir, "kaimen")
	err = os.MkdirAll(appLogDir, 0755) // Safely creates the folder if it doesn't exist
	Err_check(err)

	logPath := filepath.Join(appLogDir, "output.log")

	file, err := os.OpenFile(logPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0666)
	Err_check(err)
	defer file.Close()

	log.SetOutput(file)
	log.SetFlags(log.LstdFlags | log.Lmicroseconds)

	Read_conf()

	var wg sync.WaitGroup

	wg.Go(server)

	go open_front()

	if _, err := os.Stat(db_path); err != nil {
		fmt.Println("Creating NEW DB")
		new_db()
		Make_Conns()
		fmt.Println("DONE")
		update(counter)
	} else {
		Make_Conns()
	}

	indexing = make(map[string]bool)
	initial_crawl()

	wg.Go(inference_worker)
	wg.Go(dequeue)
	wg.Go(dequeue_inference)

	go mount()

	<-shutdownChan

	if httpServer != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Millisecond)
		defer cancel()

		if err := httpServer.Shutdown(ctx); err != nil {
			log.Printf("Server forced to shutdown: %v\n", err)
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
