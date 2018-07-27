<?php
/*  API REST Providing Terraform
 *
 *  31/10/2017 => V1.0 agammelin
 *  31/10/2017 => V.1.1 Modify Alias on PUT
 *  03/11/2017 => V 1.2 Modify Poller Assignment
 */

function Auth (){
        $headers = apache_request_headers();
        if ($headers['Auth-Token']!=""){
                header("HTTP/1.1 403 Forbidden");
                exit;
        }
}

function Add_Host($host){
        //Set Vars
        global $clapi_cmd;
        $required = array('hostname', 'location', 'address', 'template', 'hostgroup', 'assetid');
        if (count(array_intersect_key(array_flip($required), $host)) === count($required)){
                $htpl_list= preg_split('/\s+/', trim(shell_exec(''.$clapi_cmd.' -o HTPL -a SHOW | cut -d ";" -f 2')));
                $hgrp_list= preg_split('/\s+/', trim(shell_exec(''.$clapi_cmd.' -o HG -a SHOW | cut -d ";" -f 2')));
                $location_list= array("USPAWS","EUPAWS","SGPAWS","CNPAWS","CNPLAY","CNPHIM","FRPLAG","FRPEUR");
                //Checking Vars
                if (isset($host['hostname'],$host['location'],$host['address'],$host['template'],$host['hostgroup'],$host['assetid'])){
                    //Hostname Check
                    $prefix=substr($host['hostname'], 0, 3);
                    $identifier=substr($host['hostname'], 9, 1);
                    switch ($prefix) {
                        case 'WIN':
                            if($identifier!="0"){
                                header("HTTP/1.1 500 Bad Name");
                                exit;
                            }
                            break;
                        case 'LIN':
                            if($identifier!="1"){
                                header("HTTP/1.1 500 Bad Name");
                                exit;
                            }
                            break;
                        case 'APP':
                            if($identifier!="9"){
                                header("HTTP/1.1 500 Bad Name");
                                exit;
                            }
                            break;
                        default:
                            if($prefix!="AMZ"){
                                header("HTTP/1.1 500 Bad Name");
                                exit;
                            }
                    }

                    //Address Check
                    /*
                    $resolv=dns_get_record($host['address']);
                    if (empty($resolv)){
                         header("HTTP/1.1 500 Unknown Host");
                         exit;
                    }
                     */

                    //Templates check
                    $templates = preg_split('/\|/',$host['template']);
                    foreach ($templates as $template){
                        if (in_array($template, $htpl_list) == false) {
                            header("HTTP/1.1 500 Unknown Template");
                            exit;
                        }
                    }
                    if (in_array($host['hostgroup'], $hgrp_list) == false) {
                            header("HTTP/1.1 500 Unknown Hostgroup");
                            exit;
                    }
                    if (in_array($host['location'], $location_list) == false) {
                            header("HTTP/1.1 500 Unknown Location");
                            exit;
                    }
                    //Construct alias
                    $alias= substr($host['location'], 0, -4)." - ".$host['location']." - ".$host['hostgroup'];
                        //Find Poller
                    $poller_id= trim(shell_exec("mysql -u root -pplokij -h infra1dsx01.hosting.eu centreon_status -e \"SELECT instance_id FROM nagios_hosts WHERE alias LIKE '%".$host['location']."%".$host['hostgroup']."' LIMIT 1\" | sed -n '1!p' | sed 's/\\n//g'"));
                    if (empty($poller_id)){
                        $poller_id= trim(shell_exec("mysql -u root -pplokij -h infra1dsx01.hosting.eu centreon_status -e \"SELECT instances.instance_id FROM (SELECT COUNT(*) AS COUNT, instance_id FROM nagios_hosts WHERE alias LIKE '%".$host['location']."%' GROUP BY instance_id ORDER BY COUNT DESC LIMIT 1) AS instances\" | sed -n '1!p' | sed 's/\\n//g'"));
                    }
                    $poller= trim(shell_exec("mysql -u root -pplokij -h infra1dsx01.hosting.eu centreon_status -e \"SELECT instance_name FROM nagios_instances WHERE instance_id = '$poller_id'\" | sed -n '1!p' | sed 's/\\n//g'"));
                    if (empty($poller)){
                        header("HTTP/1.1 500 Unknown Poller");
                        exit;
                    }
                        //Adding Host
                        shell_exec ("$clapi_cmd -o HOST -a ADD -v \"".$host['hostname'].";$alias;".$host['address'].";".$host['template'].";$poller;".$host['hostgroup']."\"");
                        shell_exec ("$clapi_cmd -o HOST -a applytpl -v \"".$host['hostname']."\"");
                        shell_exec ("$clapi_cmd -o HOST -a setmacro -v \"".$host['hostname'].";ASSETDEVICEID;".$host['assetid']."\"");
                        //Added Host
                                $hosts=shell_exec("$clapi_cmd -o HOST -a show | grep -i ".$host['hostname']."");
                                return To_Array ($hosts);
                }else{
                    header("HTTP/1.1 500 Invalid Json");
                exit;
                }
        }
}

function To_Array($host){
        list($id,$hostname,$alias,$address,$activated) = explode (';', trim($host));
        $host=array(
                "id" => "$id",
                "hostname" => "$hostname",
        "alias" => "$alias",
                "address" => "$address",
                "activated" => "$activated",
        );
        return ($host);
}

function Get_Host ($host) {
    global $clapi_cmd;
    $item=shell_exec("$clapi_cmd -o HOST -a show | grep -i $host");
    if (empty($item)){
        header("HTTP/1.1 404 Unknown Host");
        exit;
    }else{
        return To_Array ($item);
    }
}

Function Get_All_Hosts (){
    global $clapi_cmd;
    $hosts_list=shell_exec("$clapi_cmd -o HOST -a show |tail -n +2");
    $items = array();
    foreach(preg_split("/((\r?\n)|(\r\n?))/", $hosts_list) as $item){
            $host= To_Array ($item);
        array_push ($items, $host);
    }
    array_pop ($items);
    echo json_encode ($items);
}

function Update_Host($host){
    //Set Vars
    global $clapi_cmd;
    //Update
    $required = array('hostname', 'location', 'address', 'template', 'hostgroup', 'assetid');
    if (count(array_intersect_key(array_flip($required), $host)) === count($required)){
    //Checking Vars
        if (isset($host['hostname'],$host['location'],$host['address'],$host['template'],$host['hostgroup'],$host['assetid'])){
            /*
            $resolv=dns_get_record($host['address']);
            if (empty($resolv)){
                 header("HTTP/1.1 500 Unknown Host");
                 exit;
            }
             */
            // Contruct Alias
            $alias= substr($host['location'], 0, -4)." - ".$host['location']." - ".$host['hostgroup'];
            $htpl_list= preg_split('/\s+/', trim(shell_exec(''.$clapi_cmd.' -o HTPL -a SHOW | cut -d ";" -f 2')));
            $hgrp_list= preg_split('/\s+/', trim(shell_exec(''.$clapi_cmd.' -o HG -a SHOW | cut -d ";" -f 2')));
            $templates = preg_split('/\|/',$host['template']);
            foreach ($templates as $template){
                if (in_array($template, $htpl_list) == false) {
                    header("HTTP/1.1 500 Unknown Template");
                    exit;
                }
            }
            if (in_array($host['hostgroup'], $hgrp_list) == false) {
                header("HTTP/1.1 500 Unknown Hostgroup");
                exit;
            }
            shell_exec ("$clapi_cmd -o HOST -a setmacro -v \"".$host['hostname'].";ASSETDEVICEID;".$host['assetid']."\"");
            shell_exec ("$clapi_cmd -o HOST -a sethostgroup -v \"".$host['hostname'].";".$host['hostgroup']."\"");
            shell_exec ("$clapi_cmd -o HOST -a setparam -v \"".$host['hostname'].";address;".$host['address']."\"");
            shell_exec ("$clapi_cmd -o HOST -a setparam -v \"".$host['hostname'].";alias;".$alias."\"");

            echo json_encode (Get_Host ($host['hostname']));
        }
    }else{
        header("HTTP/1.1 500 Invalid Json");
        exit;
    }
}

//Verify Auth-Token & Inputs
Auth ();
$method = $_SERVER['REQUEST_METHOD'];
$request = substr($_SERVER['PATH_INFO'],1);
list($endpoint,$id) = explode ("/",$request);

//Clapi Var
$clapi_cmd = "/usr/share/centreon/www/modules/centreon-clapi/core/centreon -u <user> -p <password>";

// Core
if ($endpoint == 'hosts'){
        switch ($method) {
          case 'GET':
            if (!empty($id)){
                echo json_encode (Get_Host($id));
                break;
            }else{
                Get_All_Hosts();
                break;
            }

          case 'POST':
            $request_body = file_get_contents('php://input');
            $hosts = json_decode($request_body, true);
            $items = array();
            foreach($hosts as $item){
                $host= Add_Host ($item);
                array_push ($items, $host);
            }
            echo json_encode ($items);
            break;

          case 'DELETE':
                if (isset($id)){
                    Get_Host($id);
                    shell_exec("$clapi_cmd -o HOST -a DEL -v \"$id\"");
                    break;
                }else{
                    header("HTTP/1.1 500 Missing Hostname");
                    break;
                }

          case 'PUT':
                if (isset($id)){
                    Get_Host($id);
                    $request_body = file_get_contents('php://input');
                    $host = json_decode($request_body, true);
                    Update_Host ($host);
                }else{
                    header("HTTP/1.1 500 Missing Hostname");
                }

                break;

          default:
            header("HTTP/1.1 500 Unknown Method");
            break;
        }
}else{
    header("HTTP/1.1 404 Unknown Method");
}
?>

