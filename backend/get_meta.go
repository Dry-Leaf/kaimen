package main

import (
	"bytes"
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
	gih "github.com/corona10/goimagehash"
	"github.com/evanoberholster/imagemeta"
	"github.com/evanoberholster/imagemeta/meta/xmp"
)

func is_video(ext string) bool {
	result := (ext == ".mp4" || ext == ".webm")
	return result
}

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

func get_meta(path, ext string, info os.FileInfo, complete_meta bool, found_meta map[string]string) map[string]any {
	name := info.Name()
	size := info.Size() //in bytes

	var width int
	var height int

	if w, ok := found_meta["width"]; ok {
		val, err := strconv.Atoi(w)
		Err_check(err)
		width = val
	}
	if h, ok := found_meta["height"]; ok {
		val, err := strconv.Atoi(h)
		Err_check(err)
		height = val
	}

	var duration float64

	if d, ok := found_meta["duration"]; ok {
		fmt.Println("test")
		val, err := strconv.ParseFloat(d, 64)
		Err_check(err)
		duration = val
	}

	f, err := os.Open(path)
	Err_check(err)
	defer f.Close()

	var hash string

	if !is_video(ext) {

		file_buffer := bytes.NewBuffer(nil)
		io.Copy(file_buffer, f)

		img, _, err := image.Decode(file_buffer)
		Err_check(err)

		phash, err := gih.PerceptionHash(img)
		Err_check(err)
		hash = phash.ToString()
	}

	// none of the below will work. everything in found_meta is actually string
	if complete_meta {
		fmt.Println("complete")
		ts, err := dateparse.ParseAny(found_meta["timestamp"])
		Err_check(err)

		return map[string]any{"name": name, "size": size,
			"timestamp": ts.Unix(),
			"width":     width, "height": height,
			"duration": duration,
			"type":     ext,
			"phash":    hash}

	}

	var timestamp string
	if ts, ok := found_meta["timestamp"]; ok {
		timestamp = ts
	} else {
		timestamp = info.ModTime().String()
	}

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
			if (width == 0 || height == 0) && !is_video(ext) {
				width, height = get_wh_from_decode(f)
			}
		}
	} else {
		if (width == 0 || height == 0) && !is_video(ext) {
			width, height = get_wh_from_decode(f)
		}
	}

	if is_video(ext) && duration == 0 {
		duration = get_video_meta(f, ext)
	}

	ts, err := dateparse.ParseAny(timestamp)
	Err_check(err)

	return map[string]any{"name": name, "size": size,
		"timestamp": ts.Unix(),
		"width":     width, "height": height,
		"duration": duration,
		"type":     ext,
		"phash":    hash}
}
