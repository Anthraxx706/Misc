package main

import (
    "net/http"
    "io/ioutil"
    "strings"
    "errors"
    "crypto/tls"
    "log"
    "fmt"
    "os"
)

//Get ELS Status
func getApi(url string) (string,error) {
        tr := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
    client := http.Client{Transport: tr}
        // Set Request
        req, err := http.NewRequest("GET",url,nil)
                if err != nil{
                log.Fatalln(err.Error())
        }
        //Do Request
        resp, err := client.Do(req)
    defer resp.Body.Close()
    bodyBytes, err := ioutil.ReadAll(resp.Body)
    els_response := string(bodyBytes)
    if err != nil {
	els_response = ""
        return els_response, errors.New("Unable to get response body\n")
    }
    return els_response, nil
}

func checkStatus (els_response string) () {
        switch {
                        case strings.Contains(els_response, "red"):
                                fmt.Printf("CRITICAL: Some nodes are unreachable")
                                os.Exit(2)
                        case strings.Contains(els_response, "yellow"):
                                fmt.Printf("WARNING: A node is unreachable")
                                os.Exit(1)
                        case strings.Contains(els_response, "green"):
                                fmt.Printf("OK: Everything is OK")
                                os.Exit(0)
                        default:
                                os.Exit(2)
        }
}

func main() {

        //GET ARGS
        api_url := os.Args[1]

        //GET response
        els_response, err := getApi(api_url)
        if err != nil {
         panic(err)
        }

        //Check Response
        checkStatus(els_response)

}

