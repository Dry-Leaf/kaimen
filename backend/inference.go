package main

import (
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"math"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/disintegration/imaging"
	ort "github.com/yalue/onnxruntime_go"
)

type tag_to_index struct {
	TagToIDX []string `json:"tag_to_idx"`
	TagToCAT []string `json:"tag_to_category"`
}

func (s *tag_to_index) UnmarshalJSON(data []byte) error {
	var wrapper struct {
		ActualMap    map[string]int    `json:"tag_to_idx"`
		ActualCatMap map[string]string `json:"tag_to_category"`
	}

	if err := json.Unmarshal(data, &wrapper); err != nil {
		return err
	}

	raw_len := len(wrapper.ActualMap)
	tag_slice := make([]string, raw_len)
	cat_slice := make([]string, raw_len)

	for key, val := range wrapper.ActualMap {
		tag_slice[val] = key
		cat_slice[val] = wrapper.ActualCatMap[key]
	}

	s.TagToIDX = tag_slice
	s.TagToCAT = cat_slice
	return nil
}

type Camie2MD struct {
	ModelInfo struct {
		ImgSize int `json:"img_size"`
	} `json:"model_info"`
	OutputSpec struct {
		InitialPredictions struct {
			Shape [2]any `json:"shape"`
		} `json:"initial_predictions"`

		RefinedPredictions struct {
			Shape [2]any `json:"shape"`
		} `json:"refined_predictions"`

		SelectedCandidates struct {
			Shape [2]any `json:"shape"`
		} `json:"selected_candidates"`
	} `json:"output_spec"`

	DatasetInfo struct {
		TagMapping tag_to_index `json:"tag_mapping"`
	} `json:"dataset_info"`
}

func preprocess_image(imagePath string, imageSize int) ([]float32, error) {
	if _, err := os.Stat(imagePath); os.IsNotExist(err) {
		Err_check(err)
	}

	file, err := os.Open(imagePath)
	Err_check(err)
	defer file.Close()

	srcImg, _, err := image.Decode(file)
	if err == image.ErrFormat {
		return nil, err
	}
	Err_check(err)

	// Resize and Pad (Letterbox) maintaining aspect ratio
	// ImageNet mean values for color
	padColor := color.RGBA{R: 124, G: 116, B: 104, A: 255}

	resizedImg := imaging.Fit(srcImg, imageSize, imageSize, imaging.Lanczos)

	canvas := imaging.New(imageSize, imageSize, padColor)
	canvas = imaging.PasteCenter(canvas, resizedImg)

	// ImageNet Normalization
	mean := [3]float32{0.485, 0.456, 0.406}
	std := [3]float32{0.229, 0.224, 0.225}

	channelSize := imageSize * imageSize
	tensorData := make([]float32, 3*channelSize)

	for y := range imageSize {
		for x := range imageSize {
			r, g, b, _ := canvas.At(x, y).RGBA()

			// Scale to [0.0, 1.0]
			fr := float32(r>>8) / 255.0
			fg := float32(g>>8) / 255.0
			fb := float32(b>>8) / 255.0

			fr = (fr - mean[0]) / std[0]
			fg = (fg - mean[1]) / std[1]
			fb = (fb - mean[2]) / std[2]

			pixelIndex := (y * imageSize) + x
			tensorData[0*channelSize+pixelIndex] = fr // Red
			tensorData[1*channelSize+pixelIndex] = fg // Green
			tensorData[2*channelSize+pixelIndex] = fb // Blue
		}
	}

	return tensorData, nil
}

func infer_tags_closure() func(string, string) []string {
	dat, err := os.ReadFile("camie-tagger-v2-metadata.json")
	Err_check(err)

	var metadata Camie2MD
	err = json.Unmarshal(dat, &metadata)
	Err_check(err)

	img_size := metadata.ModelInfo.ImgSize

	channel_size := img_size * img_size

	local_DLL := filepath.Join(exe_dir, "onnxruntime.dll")
	abs_path, _ := filepath.Abs(local_DLL)

	fmt.Println("Forcing DLL from:", abs_path)
	ort.SetSharedLibraryPath(abs_path)

	err = ort.InitializeEnvironment()
	Err_check(err)

	var imgInput []float32
	imgInput = make([]float32, 3*channel_size)
	inputShape := ort.NewShape(1, 3, int64(img_size), int64(img_size))

	initialShape := ort.NewShape(1, int64(metadata.OutputSpec.InitialPredictions.Shape[1].(float64)))
	refinedShape := ort.NewShape(1, int64(metadata.OutputSpec.RefinedPredictions.Shape[1].(float64)))
	candidateShape := ort.NewShape(1, int64(metadata.OutputSpec.SelectedCandidates.Shape[1].(float64)))

	inputNames := []string{"input"}
	outputNames := []string{"initial_predictions", "refined_predictions", "selected_candidates"}

	session, err := ort.NewDynamicAdvancedSession(`.\camie-tagger-v2_quantized.onnx`,
		inputNames, outputNames, nil)
	Err_check(err)

	return func(md5sum, path string) []string {
		imgFlatSlice, err := preprocess_image(path, img_size)
		if err == image.ErrFormat {
			return nil
		}
		Err_check(err)

		copy(imgInput, imgFlatSlice)

		inputTensor, err := ort.NewTensor(inputShape, imgInput)
		Err_check(err)
		defer inputTensor.Destroy()

		initialTensor, err := ort.NewEmptyTensor[float32](initialShape)
		Err_check(err)
		defer initialTensor.Destroy()

		refinedTensor, err := ort.NewEmptyTensor[float32](refinedShape)
		Err_check(err)
		defer refinedTensor.Destroy()

		candidateTensor, err := ort.NewEmptyTensor[int64](candidateShape)
		Err_check(err)
		defer candidateTensor.Destroy()

		inputs := []ort.Value{inputTensor}
		outputs := []ort.Value{initialTensor, refinedTensor, candidateTensor}

		err = session.Run(inputs, outputs)
		Err_check(err)

		var results []string

		refined_logits := refinedTensor.GetData()

		for idx, logit := range refined_logits {
			prob := float32(1.0 / (1.0 + math.Exp(float64(-logit))))

			if prob >= .70 {
				tag_cat := metadata.DatasetInfo.TagMapping.TagToCAT[idx]
				tag_name := metadata.DatasetInfo.TagMapping.TagToIDX[idx]

				switch tag_cat {
				case "rating", "year", "meta":
					continue
				case "artist":
					//check if artist already applied
					artist_count := get_count(artist_query, md5sum)
					if artist_count == 0 {
						results = append(results, tag_name)
					} else {
						fmt.Println("dropped artist")
						fmt.Println(tag_name)
					}
				case "copyright", "character":
					if prob >= .95 {
						results = append(results, tag_name)
					}
				case "general":
					//check for other backgrounds if tag_name includes background
					if strings.Contains(tag_name, "background") {
						bg_count := get_count(bg_query, md5sum)
						if bg_count != 0 {
							fmt.Println("dropped bg")
							fmt.Println(tag_name)
							continue
						}
					}
					results = append(results, tag_name)
				default:
					continue
				}
			}
		}

		return results
	}
}

var infer_tags = infer_tags_closure()

var inferQueue = make(chan [3]string, 100)

func inference_worker() {
	for triplet := range inferQueue {
		md5sum, path, ext := triplet[0], triplet[1], triplet[2]
		if _, err := os.Stat(path); err != nil {
			pending_infer.Delete(triplet)
			continue
		}

		results := infer_tags(md5sum, path)
		if results == nil {
			pending_infer.Delete(triplet)
			fmt.Println("Invalid format:", path)
			if is_video(ext) {
				results = []string{"animated"}
			}
		}
		fmt.Println("INFERRED:", path)
		fmt.Println(results)
		insert_tags(md5sum, path, ext, results, false, false, true)

		pending_infer.Delete(triplet)
	}
}

func dequeue_inference() {
	interval := time.Minute
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-shutdownChan:
			return

		case <-ticker.C:
			pending_infer.Range(func(key, _ any) bool {
				path := key.([3]string)
				select {
				case inferQueue <- path:
				default:
					fmt.Println("Inference queue is full!")
				}
				return true
			})
		}
	}
}
