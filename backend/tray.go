package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sync/atomic"

	"fyne.io/systray"
	"github.com/pkg/browser"
)

var front_open atomic.Bool

func Open_search_result() {
	err := browser.OpenFile("search/results")
	Err_check(err)
}

func init() {
	home, err := os.UserHomeDir()
	Err_check(err)
	db_path = filepath.Join(home, ".booru.db")

	db_uri = fmt.Sprintf(`file:///%s?_foreign_keys=on&cache=private&_synchronous=NORMAL&_journal_mode=WAL`, filepath.ToSlash(db_path))
}

func onReady() {
	icon, err := embedFS.ReadFile("kaimen.ico")
	Err_check(err)

	systray.SetIcon(icon)
	systray.SetTitle("Kaimen")
	systray.SetTooltip("Kaimen")
	systray.SetOnTapped(open_front)

	open_mi := systray.AddMenuItem("Open Search Results", "Open Search Results")
	exit_mi := systray.AddMenuItem("Exit", "Exit")

	go func() {
		for {
			select {
			case <-open_mi.ClickedCh:
				Open_search_result()
			case <-exit_mi.ClickedCh:
				systray.Quit()
			}
		}
	}()
}

func open_front() {
	current := front_open.Load()

	if current {
		return
	} else {
		if front_open.CompareAndSwap(current, true) {
			cmd := exec.Command("./search.exe")
			err := cmd.Start()
			Err_check(err)
		}
	}
}

func onExit() {
	os.Exit(0)
}
