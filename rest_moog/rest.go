package main

import (
	"bufio"
	"net/http"
	"bytes"
	"os"
	"errors"
	"fmt"
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

type Event struct {
                Signature   string `json:"signature"`
                SourceID    string `json:"source_id"`
                Source      string `json:"source"`
                Class       string `json:"class"`
                Type        string `json:"type"`
                Severity    int    `json:"severity"`
                Description string `json:"description"`

}


type Payload struct {
	Events	 []Event `json:"events"`
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
	severity := 5
	switch alert_json.Level {
		case "CRITICAL":
			severity = 5
			break
		case "WARNING":
			severity = 3
			break
		case "INFO":
			severity = 2
			break
		case "OK":
			severity = 0
			break
	}
	fmt.Println(severity)
	signature := fmt.Sprintf("%v:System:%v", alert_json.ID,alert_json.Details)
	event := Event{
		Signature:	signature,
		SourceID:	alert_json.ID,
		Source:		alert_json.ID,
		Class:		alert_json.Details,
		Type:		alert_json.Level,
		Severity:	severity,
		Description:	alert_json.Message,
	}

	data := Payload{Events: []Event{event}}
	payloadBytes, err := json.Marshal(data)
	if err != nil {
	errors.New("Unable to encode data\n")
	}
	body := bytes.NewReader(payloadBytes)

	req, err := http.NewRequest("POST", "https://scientificcrow.moogsoft.io/events/webhook_api", body)
	if err != nil {
		errors.New("Unable to Construct Request\n")
	}
	req.Header.Set("Content-Type", "application/json")
	req.SetBasicAuth("Webhook", "4EDuLU6mKdsW0FMU")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		errors.New("Unable to POST\n")
	}
	defer resp.Body.Close()
}
}

