<?php

//Vars
$FedUrl = "https://idpdecathlon.oxylane.com/as/token.oauth2";
$FedUser = "hypervision";
$FedPasswd = "";
$FedAuth = "ZGtzYXdhcGk6TmZ6RlRzeVJLWTJSOEM2VVJmQUI2WnBKdUx5c2lNNGZueEt2bUxv";

$DkSawUrl = "https://api-eu.subsidia.org/dksawapi/v1/incident";
$DkSawKey = "c4a10b37-27bc-4c31-baf3-b6fe4f049226";

$SuperviGroupId = "15305";

$RequestLog = "/home/admin/Automatisation/Logs/SawErrors.log";

// Logging Function
function SetToLogs($LogMessage){
    global $RequestLog;
    $LogFile= fopen($RequestLog, "w") or die("Unable to open file!");
    $Date = date('[d-m-Y h:i:s]');
    $Message = "\n".$Date." ".$LogMessage;
    fwrite($LogFile, $Message);
    fclose($LogFile);
}


function FedAuth(){
    global $FedUrl;
    global $FedUser;
    global $FedPasswd;
    global $FedAuth;
  $request = new HttpRequest();
  $request->setUrl($FedUrl);
  $request->setMethod(HTTP_METH_POST);

  $request->setHeaders(array(
  'content-type' => 'application/x-www-form-urlencoded',
  'authorization' => 'Basic '.$FedAuth.''
  ));

  $request->setContentType('application/x-www-form-urlencoded');
  $request->setPostFields(null);
  $request->setBody("grant_type=password&username=".$FedUser."&password=".$FedPasswd."&scope=openid profile");

  try {
    $response = $request->send();
    $json=json_decode(($response->getBody()), true);
    $code=$response->getResponseCode();
    if ( $code != "200"){
        SetToLogs($json['error_description']);
        exit(1);
    }
    $token=$json['access_token'];
    if (isset($token)){
      return $token;
    } else {
      exit;
    }
  } catch (HttpException $ex) {
    SetToLogs($ex);
    exit(1);
  }
}

function GetJsonAdd(){
  global $argv;
  global $SuperviGroupId;
  if (isset($argv[1],$argv[2],$argv[3],$argv[4],$argv[5])){
    $TicketInfo=array(
    "AssignedGroup" => "$argv[1]",
    "Description" => "$argv[2]",
    "DisplayLabel" => "$argv[3]",
    "RegisteredForActualService" => "$argv[4]",
    "ServiceDeskGroup" => "$argv[5]",
    "LogGroup_c" => "$SuperviGroupId",
    );
    return json_encode($TicketInfo);
  } else {
    exit;
  }
}

function GetJsonDel(){
  global $argv;
  if (isset($argv[1],$argv[2],$argv[3],$argv[4],$argv[5])){
    $TicketInfo=array(
    "AssignedGroup" => "$argv[1]",
    "CompletionCode" => "Resolvedbyfix",
    "Description" => "<br/><b>Ticket Closed By AutoReview -- Alert is no longer in Critical State.</b>",
    "DisplayLabel" => "$argv[3]",
    "PhaseId" => "Close",
    "RegisteredForActualService" => "$argv[4]",
    "ServiceDeskGroup" => "$argv[5]",
    "Solution" => "Auto Review",
    );
    return json_encode($TicketInfo);
  } else {
    exit;
  }
}

function CreateTicket($TicketPayload,$Token){
    global $DkSawUrl;
    global $DkSawKey;
  $request = new HttpRequest();
  $request->setUrl($DkSawUrl);
  $request->setMethod(HTTP_METH_POST);

  $request->setQueryData(array(
    'treat' => 'true'
  ));

  $request->setHeaders(array(
    'content-type' => 'application/json',
    'x-api-key' => $DkSawKey,
    'authorization' => 'Bearer '.$Token.''
  ));

  $request->setBody($TicketPayload);

  try {
    $response = $request->send();
    $SawResp = $response->getBody();
    if (strpos($SawResp, 'FAILED') !== false) {
            SetToLogs($SawResp);
            exit(1);
    }
    $TicketId = preg_replace("/[^0-9]/", '', $SawResp);
    echo $TicketId;
    exit(0); 
  } catch (HttpException $ex) {
      SetToLogs($ex);
      exit(1);
  }
}

function DelTicket($TicketPayload,$Token){
    global $DkSawUrl;
    global $DkSawKey;
  $request = new HttpRequest();
  $request->setUrl($DkSawUrl);
  $request->setMethod(HTTP_METH_DELETE);

  $request->setHeaders(array(
    'content-type' => 'application/json',
    'x-api-key' => $DkSawKey,
    'authorization' => 'Bearer '.$Token.'',
  ));

  $request->setBody($TicketPayload);

 try {
    $response = $request->send();
    $SawResp = $response->getBody();
    if (strpos($SawResp, 'FAILED') !== false) {
            SetToLogs($SawResp);
            exit(1);
    }
    $TicketId = preg_replace("/[^0-9]/", '', $SawResp);
    echo $TicketId;
    exit(0);
  } catch (HttpException $ex) {
      SetToLogs($ex);
      exit(1);
  }
}

//CORE 
$Method=$argv['6'];

switch ($Method) {
    case 'ADD':
        CreateTicket(GetJsonAdd(),FedAuth());
    break;
    
    case 'DEL':
        DelTicket(GetJsonDel(),FedAuth());
    break;

    default:
    exit(1);
}
?>

