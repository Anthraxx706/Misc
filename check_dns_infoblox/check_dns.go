package main 

import (
    "net/http"
    "io/ioutil"
	"strings"
    "errors"
    "crypto/tls"
    "log"
    "encoding/json"
	"fmt"
	"os"
	"strconv"
)

type infobloxResponse []struct {
	Ref      string `json:"_ref"`
	NodeInfo []struct {
		HaStatus            string `json:"ha_status"`
		Hwid                string `json:"hwid"`
		Hwmodel             string `json:"hwmodel"`
		Hwtype              string `json:"hwtype"`
		Lan2PhysicalSetting struct {
			AutoPortSettingEnabled bool `json:"auto_port_setting_enabled"`
		} `json:"lan2_physical_setting"`
		LanHaPortSetting struct {
			HaPortSetting struct {
				AutoPortSettingEnabled bool   `json:"auto_port_setting_enabled"`
				Speed                  string `json:"speed"`
			} `json:"ha_port_setting"`
			LanPortSetting struct {
				AutoPortSettingEnabled bool `json:"auto_port_setting_enabled"`
			} `json:"lan_port_setting"`
		} `json:"lan_ha_port_setting"`
		MgmtPhysicalSetting struct {
			AutoPortSettingEnabled bool `json:"auto_port_setting_enabled"`
		} `json:"mgmt_physical_setting"`
		PhysicalOid   string `json:"physical_oid"`
		ServiceStatus []struct {
			Description string `json:"description,omitempty"`
			Service     string `json:"service"`
			Status      string `json:"status"`
		} `json:"service_status"`
	} `json:"node_info"`
}

//GetJson
func getJson(url string, api_user string, api_pwd string) (infobloxResponse,error) {
	tr := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
    client := http.Client{Transport: tr}
	// Set Request
	req, err := http.NewRequest("GET",url,nil)
	req.SetBasicAuth(api_user, api_pwd)
	req.Header.Set("Content-Type", "application/json")

	if err != nil{
	        log.Fatalln(err.Error())
	}
	//Do Request
	resp, err := client.Do(req)
    defer resp.Body.Close()
    bodyBytes, err := ioutil.ReadAll(resp.Body)
    var res infobloxResponse
    err = json.Unmarshal(bodyBytes, &res)
    if err != nil {
        return nil, errors.New("Unable to decode response body\n")                                                                                                                
    }
    return res, nil
}

func checkHost(host string, resp infobloxResponse) (hostname string, err error) {
	for _, index := range resp {
		hostArray := strings.Split(index.Ref, ":")
		hostname := hostArray[1]
		if host == hostname {
			return hostname, nil
		}
	}
	return host, errors.New("Unknown Host")
}

func getMetric(service string) (metric int) {
	metricArray := strings.Split(service, "%")
	metric, _ = strconv.Atoi(metricArray[0])
	return metric
}

func getMetricCpu(service string) (metric int) {
        metricArray := strings.Split(service, "Usage: ")
	usage := strings.Split(metricArray[1], "%")
        metric, _ = strconv.Atoi(usage[0])
        return metric
}


func perfData(metric int, warn int, crit int, service string) () {
	switch{
	case metric > crit:
		fmt.Printf("CRITICAL: %v%% Used | %v=%v;%v;%v;\n", metric,service,metric,warn,crit)
		os.Exit(2)
	case metric > warn:
		fmt.Printf("WARNING: %v%% Used | %v=%v;%v;%v;\n", metric,service,metric,warn,crit)
		os.Exit(1)
	default:
		fmt.Printf("OK: %v%% Used | %v=%v;%v;%v;\n", metric,service,metric,warn,crit)
		os.Exit(0)
	}
}

func perfDataCpu (hostname string, resp infobloxResponse, warn int, crit int) () {
i:=0
status := ""
var perfData []string
	for _, index := range resp {
	    ref_host := strings.Split(index.Ref, ":")
	    if hostname == ref_host[1] {
	        for _, info := range index.NodeInfo {
	        	for _, metric := range info.ServiceStatus {
					if metric.Service == "CPU_USAGE" {
						metric := getMetricCpu(metric.Description)
						switch{
						case metric > crit:
							if status != "CRITICAL"{
							status = "CRITICAL"
							break
							}
						case metric > warn:
							if status != "CRITICAL"{
							status = "WARNING"
							}
							break
						default:
							status = "OK"
						}
					output := fmt.Sprintf("CPU_%v=%v;%v;%v;", i, metric,warn,crit)
					perfData = append(perfData, output)
					i++	
					}
				}
			}
		}
	}
	switch status {
		case "CRITICAL":
			fmt.Printf("CRITICAL: Cpu usage is over Threshold |%v\n", strings.Join(perfData, " "));
			os.Exit(2)
		case "WARNING":
			fmt.Printf("WARNING: Cpu usage is over Threshold |%v\n", strings.Join(perfData, " "));
			os.Exit(1)
		default:
			fmt.Printf("OK: Cpu usage is OK |%v\n", strings.Join(perfData, " "));
			os.Exit(0)
	}
}

func getStatus (service string, status string) () {
	if status != "WORKING" {
		fmt.Printf("Service : %v is in CRITICAL state\n", service)
		os.Exit(2)
	}else{
		fmt.Printf("Service: %v is OK\n", service)
		os.Exit(0)
	}
}
func getThreshold() (warn int, crit int) {
	warn, _ = strconv.Atoi(os.Args[6])
	crit, _ = strconv.Atoi(os.Args[7])
	return warn,crit
}

func main() {

	//GET ARGS
	api_url := os.Args[1]
	api_user :=os.Args[2]
	api_pwd := os.Args[3]
	host := os.Args[4]
 	service := os.Args[5]
	var warn int
	var crit int
	if service != "VPN_CERT"{
		warn, crit = getThreshold()
	}else{
		_ = warn
		_ = crit
	}	


	//GET Json
	resp, err := getJson(api_url, api_user, api_pwd)
	if err != nil {
	 panic(err)
	}

	//GET METRICS
	hostname, err := checkHost(host, resp)
	if err != nil {
		panic(err)
	}
	
	// Parsing Json and Get asked Values
	for _, index := range resp {
	ref_host := strings.Split(index.Ref, ":")
	if hostname == ref_host[1] {
		for _, info := range index.NodeInfo {
	  		for _, metric := range info.ServiceStatus {
				if metric.Service == service {
					switch metric.Service {
						case "DISK_USAGE", "DB_OBJECT" ,"MEMORY" ,"SWAP_USAGE":
							perfData(getMetric(metric.Description),warn,crit,service)
						case "VPN_CERT", "REPLICATION":
							getStatus(metric.Service,metric.Status)
						case "CPU_USAGE":
							perfDataCpu(hostname,resp,warn,crit)
						default:
							os.Exit(2)
					}
			}	
	  		}
		}
		fmt.Printf("\n")
	}	
	}
}
