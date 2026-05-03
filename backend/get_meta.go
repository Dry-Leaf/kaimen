package main

import (
	"image"
	"io"
	"os"

	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"

	_ "github.com/kpfaulkner/jxl-go"
	_ "github.com/vegidio/avif-go"
	_ "golang.org/x/image/webp"

	"github.com/abema/go-mp4"
	"github.com/at-wat/ebml-go"
	"github.com/at-wat/ebml-go/webm"
	"github.com/rwcarlsen/goexif/exif"
)

func get_video_ducation(reader *os.File, ext string) float64 {
	_, err := reader.Seek(0, io.SeekStart)
	Err_check(err)

	switch ext {
	case ".mp4":
		info, err := mp4.Probe(reader)
		Err_check(err)

		return float64(info.Duration)
	case ".webm":
		var ret struct {
			Header  webm.EBMLHeader `ebml:"EBML"`
			Segment webm.Segment    `ebml:"Segment"`
		}
		err := ebml.Unmarshal(reader, &ret)
		Err_check(err)

		return ret.Segment.Info.Duration
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

func get_meta(md5sum, path, ext string, info os.FileInfo) map[string]string {
	name := info.Name()
	size := info.Size()
	timestamp := info.ModTime()

	f, err := os.Open(path)
	Err_check(err)
	defer f.Close()
	x, err := exif.Decode(f)

	// exif data could be extracted
	if err == nil {
		tm, err := x.DateTime()
		if err == nil {
			timestamp = tm
		}

		widthTag, err := x.Get(exif.ImageWidth)
		heightTag, err := x.Get(exif.ImageLength)

		if err == nil {
			width, err := widthTag.Int(0)
			Err_check(err)
			height, err := heightTag.Int(0)
			Err_check(err)
		} else {
			width, height := get_wh_from_decode(f)
		}
	} else {
		width, height := get_wh_from_decode(f)
	}
	return nil
}
