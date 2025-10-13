package main

import (
	"bytes"
	"embed"
	"image"
	"image/png"
	"os"
	"strconv"

	"gioui.org/app"
	"gioui.org/f32"
	"gioui.org/layout"
	"gioui.org/op"
	"gioui.org/op/paint"
	"gioui.org/unit"
)

//go:embed counters/*
var counter_folder embed.FS

//go:embed favicon.ico
var icon []byte

var counter_map = make(map[string]image.Image)

func load_counters() {
	entries, err := counter_folder.ReadDir("counters")
	Err_check(err)

	for _, entry := range entries {
		name := entry.Name()
		file, err := counter_folder.ReadFile("counters/" + name)
		Err_check(err)

		img, err := png.Decode(bytes.NewReader(file))
		Err_check(err)

		counter_map[name] = img
	}
}

func drawImage(ops *op.Ops, img image.Image) {
	imageOp := paint.NewImageOp(img)
	imageOp.Filter = paint.FilterNearest
	imageOp.Add(ops)
	op.Affine(f32.Affine2D{}.Scale(f32.Pt(0, 0), f32.Pt(1.3, 1.3))).Add(ops)
	paint.PaintOp{}.Add(ops)
}

func ui(file_count int) {
	go func() {
		// create new window
		w := new(app.Window)
		w.Option(app.Title("Kaimen"))
		w.Option(app.Size(unit.Dp(400), unit.Dp(400)))

		var ops op.Ops
		//th := material.NewTheme()
		//var startButton widget.Clickable

		count_str := strconv.Itoa(file_count)

		for {
			evt := w.Event()

			switch typ := evt.(type) {
			case app.FrameEvent:
				gtx := app.NewContext(&ops, typ)

				var counters []layout.FlexChild

				for _, digit := range count_str {
					d := string(digit)

					img := counter_map[d+".png"]

					cfc := layout.Rigid(func(gtx layout.Context) layout.Dimensions {
						drawImage(gtx.Ops, img)
						return layout.Dimensions{Size: img.Bounds().Size().Mul(2)}
					})
					counters = append(counters, cfc)
				}

				counter_box := func(gtx layout.Context) layout.Dimensions {
					return layout.Flex{Axis: layout.Horizontal}.Layout(gtx,
						counters...,
					)
				}
				// Let's try out the flexbox layout:
				layout.Flex{
					// Vertical alignment, from top to bottom
					Axis: layout.Vertical,
				}.Layout(gtx,
					layout.Rigid(layout.Spacer{Height: unit.Dp(25)}.Layout),
					layout.Rigid(counter_box),
				)

				typ.Frame(gtx.Ops)

			case app.DestroyEvent:
				os.Exit(0)
			}
		}
	}()
	app.Main()
}
