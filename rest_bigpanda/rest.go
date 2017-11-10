package main

import (
	"bufio"
	"net/http"
	"bytes"
	"os"
	"errors"
	"encoding/json"
)

func main() {
type Kapacitor_json struct {
	ID       string    `json:"id"`
	Message  string    `json:"message"`
	Details  string    `json:"details"`
	Time     string `json:"time"`
	Duration int64     `json:"duration"`
	Level    string    `json:"level"`
	Data     struct {
		Series []struct {
			Name string `json:"name"`
			Tags struct {
				Device string `json:"device"`
				Fstype string `json:"fstype"`
				Host   string `json:"host"`
				Path   string `json:"path"`
				Team   string `json:"team"`
			} `json:"tags"`
			Columns []string        `json:"columns"`
			Values  [][]interface{} `json:"values"`
		} `json:"series"`
	} `json:"data"`
}

type Payload struct {
	AppKey string `json:"app_key"`
	Status string `json:"status"`
	Host   string `json:"host"`
	Team   string `json:"team`
	Check  string `json:"check"`
}

var err error
stream := bufio.NewScanner(os.Stdin)
for stream.Scan(){
	var alert_json Kapacitor_json
	alert_string := stream.Text()
	alert_string += "\n"
	err = json.Unmarshal([]byte(alert_string), &alert_json)
	if err != nil {
		errors.New("Unable to decode Alert Json\n")
	}

	data := Payload{
		AppKey:		"ac3bf44cbc2bf2db9df0cba78d8b14f5",
		Status:		alert_json.Level,
		Host:		alert_json.ID,
		Team:		alert_json.Details,
		Check:		alert_json.Message,
	}

	payloadBytes, err := json.Marshal(data)
	if err != nil {
	errors.New("Unable to encode data\n")
	}
	body := bytes.NewReader(payloadBytes)

	req, err := http.NewRequest("POST", "https://api.bigpanda.io/data/v2/alerts", body)
	if err != nil {
		errors.New("Unable to Construct Request\n")
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer 6173b75510c1487ee50555d342b87412")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		errors.New("Unable to POST\n")
	}
	defer resp.Body.Close()
}
}
