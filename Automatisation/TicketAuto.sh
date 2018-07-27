# Note: This script will create Ticket Automatically
# V 1.0 23/05/2018 AGN -- Creation


#############################################################################################

##### Vars
## Nagios Files
NagiosStatusFile="/var/log/nagios/status.dat"
ExtractConfig="/home/admin/EXTRACT/export_configuration_$(date -d 'yesterday' +%Y-%m-%d).csv"

## Automation Paths 
TicketAutoLogFile="/home/admin/Automatisation/TicketAuto.log"
InDir="/home/admin/Automatisation/Queues/IN"
OkDir="/home/admin/Automatisation/Queues/OK"
PcaDir="/home/admin/Automatisation/Queues/PCA"
MassiveDir="/home/admin/Automatisation/Queues/Massive"

## HP SAW variables & Scripts
SawRequest="/home/admin/Automatisation/Scripts/Php/SawRequest.php"
GroupIdList="/home/admin/Automatisation/Scripts/Php/Groups.list"
RegisteredForActualService="181374"

##Tools
SetAckCommand="/home/admin/Automatisation/Scripts/Set_Ack.sh"
GetStatusCommand="/home/admin/Automatisation/Scripts/Get_Status.sh"

## Logs
SawLog="/home/admin/Automatisation/Logs/SawRequest.log"
TicketAutoLogFile="/home/admin/Automatisation/Logs/TicketAuto.log"
#Colors
RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
BLUE='\033[0;36m'
YELLOW='\033[0;33m'

#### Service Configuration
Now=$(date +%s)
Tempo=600
TempoAutoReview=14400
Frequency=300
MassiveWavesThreshold=5

Stamp=$((${Now}-${Tempo}))
AutoReviewStamp=$((${Now}-${TempoAutoReview}))

#############################################################################################

##### Functions 
## Logging

SetToLogs(){
    LogDate=$(date "+%d-%m-%Y %H:%M:%S")
    Message="$1"
    echo -e "[$LogDate] $Message" >> $TicketAutoLogFile
}

SawLogs(){
    Message="$1"
    echo $Message >> $SawLog
}

## Tools
SetTime(){
    #Reset Time Vars after each occurency
    Now=$(date +%s)
    Stamp=$((${Now}-$Tempo))
    AutoReviewStamp=$((${Now}-${TempoAutoReview}))
}

GetTicketFiles(){
#Get the Files which have a Creation Timestamp greater than 10min 
Files=()
for TicketFile in `ls $InDir`;
    do
        AlertDate=$(grep 'Date=' $InDir/$TicketFile | cut -d '=' -f2)
        if [[ $AlertDate -lt $Stamp ]]; then
            Files+=($TicketFile)
        fi
done
if [ ${#Files[@]} -eq 0 ];then
    SetToLogs "[${GREEN}Service${NC}] There is no Alert to process"
fi
}

GetTicketFilesAutoReview(){
#Get the Files which have a Creation Timestamp greater than 4h 
Files=()
for TicketFile in `ls $OkDir`;
    do
        AlertDate=$(grep 'Date=' $OkDir/$TicketFile | cut -d '=' -f2)
        if [[ $AlertDate -lt $AutoReviewStamp ]]; then
            Files+=($TicketFile)
        fi
done
if [ ${#Files[@]} -eq 0 ];then
    SetToLogs "[${GREEN}Service${NC}] There is no Ticket to review"
fi

}

CheckStatus(){
    CurrentState=$(ssh nagios@$Poller "$GetStatusCommand $HostName $ServiceDesc" 2>/dev/null)
    if [[ "$CurrentState" == "OK" ]];then
        rm $InDir/$TicketFile
        SetToLogs "[${BLUE}CheckStatus${NC}] $HostName;$ServiceDesc;$CurrentState - Is not in Alert State anymore"
        return 1
    else
        if [[ -z $CurrentState ]];then
            CurrentState="CRITICAL"
        fi
        SetToLogs "[${BLUE}CheckStatus${NC}] $HostName;$ServiceDesc;$CurrentState - Is still in Alert State"
        return 0
    fi
}

SetAck(){
    if ssh nagios@$Poller "$SetAckCommand $HostName $ServiceDesc $TicketId" 2>/dev/null; then
        SetToLogs "[${YELLOW}TicketCreation${NC}] $HostName;$ServiceDesc;$CurrentState - Acknowledge was set"       
    else
        SetToLogs "[${RED}TicketCreation${NC}] $HostName;$ServiceDesc;$CurrentState - Unable to set Ack"
    fi
}

SetAlertVars(){
    AlertDate=$(grep 'Date=' $InDir/$TicketFile | cut -d '=' -f 2)
    HostName=$(grep 'HostName=' $InDir/$TicketFile |cut -d '=' -f 2)
    ServiceDesc=$(grep 'ServiceDesc=' $InDir/$TicketFile |cut -d '=' -f 2)
    Poller=$(grep 'Poller=' $InDir/$TicketFile | cut -d '=' -f 2)
    Hostgroup=$(grep "$HostName;$ServiceDesc" $ExtractConfig | cut -d ';' -f 3 |cut -d ',' -f 1)
    ServiceCategory=$(grep "$HostName;$ServiceDesc" $ExtractConfig | cut -d ';' -f 4)
    Output=$(grep 'Output=' $InDir/$TicketFile| sed 's/Output=//g')
    # If we found ServiceCategory -> Hostgroup = ServiceCategory
    if [[ -n $ServiceCategory ]];then
        Hostgroup=$ServiceCategory
    fi
}

SetAutoReviewVars(){
    AlertDate=$(grep 'Date=' $OkDir/$TicketFile | cut -d '=' -f 2)
    HostName=$(grep 'HostName=' $OkDir/$TicketFile |cut -d '=' -f 2)
    ServiceDesc=$(grep 'ServiceDesc=' $OkDir/$TicketFile |cut -d '=' -f 2)
    Poller=$(grep 'Poller=' $OkDir/$TicketFile | cut -d '=' -f 2)
    Hostgroup=$(grep "$HostName;$ServiceDesc" $ExtractConfig | cut -d ';' -f 3 |cut -d ',' -f 1)
    ServiceCategory=$(grep "$HostName;$ServiceDesc" $ExtractConfig | cut -d ';' -f 4)
    Output=$(grep 'Output=' $OkDir/$TicketFile| sed 's/Output=//g')
    DisplayLabel=$(grep 'DisplayLabel=' $OkDir/$TicketFile | cut -d '=' -f 2)
    AssignedGroup=$(grep 'AssignedGroup=' $OkDir/$TicketFile | cut -d '=' -f 2)
    TicketId=$(grep 'TicketId=' $OkDir/$TicketFile | cut -d '=' -f 2)
    # If we found ServiceCategory -> Hostgroup = ServiceCategory
    if [[ -n $ServiceCategory ]];then
        Hostgroup=$ServiceCategory
    fi

}

CheckMassiveWaves(){
    ServiceCount=$(grep -h -e 'ServiceDesc=' -e 'Hostgroup=' $InDir/* | sed 'N;s/\n/;/; s/ServiceDesc=//g; s/Hostgroup=//g' | cut -d '=' -f 2 | sort | uniq -c | sort -nr | awk '{print $1.";"$2}' | head -1)
    Count=$(echo $ServiceCount | cut -d ';' -f 1)
    if [[ $Count -gt $MassiveWavesThreshold ]];
    then    
        ServiceDesc=$(echo $ServiceCount | cut -d ';' -f 2)
        Hostgroup=$(echo $ServiceCount | cut -d ';' -f 3)
        MassiveWaveFiles=$(grep -l $Hostgroup $InDir/*$ServiceDesc* | sed "s|$InDir/||")
        MassiveWaveHosts=""
        for TicketFile in ${MassiveWaveFiles};do
            MassiveWaveHosts+="$(grep 'HostName=' $InDir/$TicketFile |cut -d '=' -f 2);"
            rm $InDir/$TicketFile
        done
        MassiveWaveName="MassiveWave_${ServiceDesc}_${Hostgroup}"
        echo -e "Date=${Now}\nServiceDesc=${ServiceDesc}\nHosts=${MassiveWaveHosts}\nHostgroup=${Hostgroup}" >> $MassiveDir/$MassiveWaveName
        SetToLogs "[${YELLOW}MassiveWave${NC}] Massive Wave on $ServiceDesc for $Hostgroup - Creating Ticket"
        # Creating Ticket for Massive Wave
        CreateTicket Massive
        return 1
    else
        SetToLogs "[${GREEN}Service${NC}] There is no MassiveWaves"
        return 0
    fi
}

## HP SAW Requests

CreateTicket(){
    # Set Global Ticket Vars
    AssignedGroup=$(grep "${Hostgroup};" $GroupIdList | cut -d ";" -f 2)
    HumanDate=$(date -d @$Now "+%d-%m-%Y: %H:%M")
    # Set Vars for MassiveWave or Single Ticket
    if [[ $1 == "Massive" ]];then
        DisplayLabel="$HumanDate - $MassiveWaveName"
        Description="<br/>The Monitoring Platform detected a Massive Alerts Wave for Service <b>$ServiceDesc</b><br/><b>Impacted Hosts:</b><br/>$MassiveWaveHosts<br/><br/><b>The Monitoring Team<b/>"
        File="$MassiveDir/$MassiveWaveName"
        HostName="Massive Wave"
        CurrentState="CRITICAL"
    else
        #Check If a ticket was previously created
        File="$InDir/$TicketFile"
        if ls $OkDir/${HostName}_${ServiceDesc}*;then
            SetToLogs "[${YELLOW}TicketCreation${NC}] $HostName;$ServiceDesc;$CurrentState - Ticket was already Created"
            rm $File
            return 1
        fi
       DisplayLabel="$HumanDate - $HostName -> $ServiceDesc is $CurrentState"
       echo $DisplayLabel
       Description="<br/>The Monitoring Platform detected a $CurrentState state for:<br/><br/>Host:<b> $HostName</b><br/>Service:<b> $ServiceDesc </b><br/>Nagios Output: $Output<br/><br/><b>The Monitoring Team<b/>" 
    fi
    # Creating Ticket
    TicketId=$(/usr/bin/php "$SawRequest" "$AssignedGroup" "$Description" "$DisplayLabel" "$RegisteredForActualService" "$AssignedGroup" ADD)
    Regex='^[a-Z]+$'
    if [[ -z $TicketId || $TicketId -eq 200500 || $TicketId =~ $Regex ]];then
        SetToLogs "[${RED}TicketCreation${NC}] $HostName;$ServiceDesc;$CurrentState - Ticket creation failed, Moved to PCA"
        mv $File $PcaDir
        return 1
    else
        SetToLogs "[${YELLOW}TicketCreation${NC}] $HostName;$ServiceDesc;$CurrentState - Ticket Created Id=$TicketId"
        SawLogs "$Now;$Hostgroup;$HostName;$ServiceDesc;$CurrentState;$TicketId"
        SetAck
        # Adding Ticket Information to TicketFile before Moving
        echo -e "TicketId=$TicketId\nDisplayLabel=$DisplayLabel\nAssignedGroup=$AssignedGroup" | tee -a $File
        # If Massive Waves we not copy To OK dir because Massive Waves can't handle AutoReview
        if [[ $1 != "Massive" ]];then
            mv $File $OkDir
        fi
        return 0
    fi
}

DelTicket(){
    Description="Closed By AutoReview"
    if /usr/bin/php "$SawRequest" "$AssignedGroup" "$Description" "$DisplayLabel" "$RegisteredForActualService" "$AssignedGroup" DEL; then
        SetToLogs "[${YELLOW}AutoReview${NC}] $HostName;$ServiceDesc;$CurrentState - Ticket Closed By AutoReview Id=$TicketId"
        rm $OkDir/$TicketFile
    else
        SetToLogs "[${RED}AutoReview${NC}] $HostName;$ServiceDesc;$CurrentState - Unable to Close Ticket Id=$TicketId"
    fi
}

#############################################################################################

#### Service Workflow

Automation_Process(){
    SetTime
    SetToLogs "[${GREEN}Service${NC}] We Begin MassiveWave Check Process"
    until CheckMassiveWaves
    do
        CheckMassiveWaves
    done
    SetToLogs "[${GREEN}Service${NC}] We Begin Ticket Creation Process"
    GetTicketFiles
    for TicketFile in "${Files[@]}";do
        SetAlertVars
        if CheckStatus ;then
            CreateTicket
        fi
    done
    # AutoReview
    SetToLogs "[${GREEN}Service${NC}] We Begin AutoReview Process"
    GetTicketFilesAutoReview
    for TicketFile in "${Files[@]}";do
        SetAutoReviewVars
        if ! CheckStatus ;then
            DelTicket
        fi
    done
    SetToLogs "[${GREEN}Service${NC}] AutoReview Process Done - Wait $Tempo Sec"
}

#############################################################################################

## Core
# Firt Pass
Automation_Process

while sleep $Frequency;
do
    Automation_Process
done
