package main

import (
	"fmt"
	"image"
	"io"
	"os"
	"strconv"

	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"

	_ "github.com/kpfaulkner/jxl-go"
	_ "github.com/vegidio/avif-go"
	_ "golang.org/x/image/webp"

	"github.com/abema/go-mp4"
	"github.com/araddon/dateparse"
	"github.com/at-wat/ebml-go"
	"github.com/at-wat/ebml-go/webm"
	"github.com/evanoberholster/imagemeta"
	"github.com/evanoberholster/imagemeta/meta/xmp"
)

func get_video_meta(reader *os.File, ext string) float64 {
	_, err := reader.Seek(0, io.SeekStart)
	Err_check(err)

	switch ext {
	case ".mp4":
		info, err := mp4.Probe(reader)
		Err_check(err)

		return float64(info.Duration) / 1000
	case ".webm":
		var ret struct {
			Header  webm.EBMLHeader `ebml:"EBML"`
			Segment webm.Segment    `ebml:"Segment"`
		}
		err := ebml.Unmarshal(reader, &ret)
		Err_check(err)

		return ret.Segment.Info.Duration / 1000
	default:
		return 0
	}
}

func get_wh_from_decode(reader *os.File) (int, int) {
	_, err := reader.Seek(0, io.SeekStart)
	Err_check(err)
	config, _, err := image.DecodeConfig(reader)
	Err_check(err)

	width := config.Width
	height := config.Height

	return width, height
}

func get_meta(path, ext string, info os.FileInfo, complete_meta bool, found_meta map[string]any) map[string]any {
	name := info.Name()
	size := info.Size() //in bytes

	if complete_meta {
		ts, err := dateparse.ParseAny(found_meta["timestamp"].(string))
		Err_check(err)

		return map[string]any{"name": name, "size": size,
			"timestamp": ts.Unix(),
			"width":     found_meta["width"].(int), "height": found_meta["height"].(int),
			"duration": found_meta["duration"].(float64)}
	}

	var timestamp string
	if ts, ok := found_meta["timestamp"]; ok {
		timestamp = ts.(string)
	} else {
		timestamp = info.ModTime().String()
	}

	var width int
	var height int

	if w, ok := found_meta["width"]; ok {
		val, err := strconv.Atoi(w.(string))
		Err_check(err)
		width = val
	}
	if h, ok := found_meta["height"]; ok {
		val, err := strconv.Atoi(h.(string))
		Err_check(err)
		height = val
	}

	f, err := os.Open(path)
	Err_check(err)
	defer f.Close()

	if ext == ".jpg" || ext == ".png" || ext == ".gif" {
		meta, err := imagemeta.Decode(f)

		// exif metadata could be extracted
		// prefer it over from web
		if err == nil {
			width = int(meta.ExifIFD.PixelXDimension)
			height = int(meta.ExifIFD.PixelYDimension)

			_, err := f.Seek(0, io.SeekStart)
			Err_check(err)
			x, err := xmp.ParseXmp(f)
			if err == nil {
				fmt.Println("basic date")
				cd := x.Basic.CreateDate
				if !cd.IsZero() {
					timestamp = cd.String()
				}
			}
		} else {
			if (width == 0 || height == 0) && ext != ".mp4" && ext != ".webm" {
				width, height = get_wh_from_decode(f)
			}
		}
	} else {
		if (width == 0 || height == 0) && ext != ".mp4" && ext != ".webm" {
			width, height = get_wh_from_decode(f)
		}
	}

	var duration float64
	if d, ok := found_meta["duration"]; ok {
		val, err := strconv.ParseFloat(d.(string), 64)
		Err_check(err)
		duration = val
	}

	if (ext == ".mp4" || ext == ".webm") && duration == 0 {
		duration = get_video_meta(f, ext)
	}

	ts, err := dateparse.ParseAny(timestamp)
	Err_check(err)

	return map[string]any{"name": name, "size": size,
		"timestamp": ts.Unix(),
		"width":     width, "height": height,
		"duration": duration}
}
