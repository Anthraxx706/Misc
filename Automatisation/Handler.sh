# ARGS : "$HOSTNAME$" "$SERVICEDESC$" "$SERVICESTATE$" "$SERVICESTATETYPE$" "$SERVICEOUTPUT$" "$LASTSERVICESTATE$" "$HOSTGROUPNAME$" $SERVICEDOWNTIME$
#
# Note: This script will send a Ticket File to the main poller on Critical Hard State status
#
# V 1.0 23/05/2018 AGN -- Creation

## Set vars
# Nagios
ExternalCommandFile="/var/spool/nagios/cmd/nagios.cmd"
NagiosStatusFile="/var/log/nagios/status.dat"
Author="AutoDowntimeCritical"

# Automatisation
AutomationLogFile="/home/admin/Automatisation/test_LogAutomation.log"
AutomationRetentionDir="/home/admin/Automatisation/Ticket_Retention_Files/"
RemoteDir="/home/admin/Automatisation/IN"
MainPoller=""


# Args
HostName="$1"
ServiceDesc="$2"
ServiceState="$3"
ServiceStateType="$4"
ServiceOutput="$5"
LastServiceState="$6"
Hostgroup="$7"
DowntimeStatus="$8"

#Time
Now=$(date +%s)
duration=900
date_end=$((${Now}+$duration))
date_start=$((${Now}-240))


## Funcs

SetDowntime()
{
    printf "[%lu] SCHEDULE_SVC_DOWNTIME;$HostName;$ServiceDesc;$date_start;$date_end;1;0;$duration;$Author;Scheduled Downtime for Automatic Ticket Creation \n" $Now | tee -a $ExternalCommandFile $AutomationLogFile
}
DelDowntime()
{
    for DowntimeID in $DowntimeIDs; do
        printf "[%lu] DEL_SVC_DOWNTIME;$DowntimeID \n" $Now | tee -a $ExternalCommandFile
        echo "[$Now];REMOVE_DOWNTIME;$HostName;$ServiceDesc;$ServiceStateType;$ServiceOutput;$Hostgroup" | tee -a $AutomationLogFile
    done
}
GetDowntimeID()
{
    DowntimeIDs=`awk '/servicedowntime/,/}/{print}' $NagiosStatusFile | awk '{FS="=";} /host_name=/{host=$2;}/service_description=/{service=$2;}/downtime_id=/{downtimeid=$2;}/author=/{author=$2;if (host=="'$HostName'" && service=="'$ServiceDesc'" && author=="'$Author'") print downtimeid;}'`
    if [ -z "$DowntimeIDs"];then
        exit
    fi
}
CreateTicket()
{
    #Check if Alerts has been Acknoledged before creating Ticket File
    isAck=`awk '/servicestatus/,/}/{print}' /var/log/nagios/status.dat | awk '{FS="=";} /host_name=/{host=$2;}/service_description=/{service=$2;}/problem_has_been_acknowledged=/{isAck=$2;if (host=="'$HostName'" && service=="'$ServiceDesc'") print isAck;}'`
    if [[ $isAck -eq 0 ]];then
        # Create Ticket File
        Ticket_File="${HostName}_${ServiceDesc}_$Now"
        echo -e "Date=${Now}\nHostName=${HostName}\nService=${ServiceDesc}\nHostgroup=${Hostgroup}" >> $AutomationRetentionDir$Ticket_File
        printf "[%lu] ACKNOWLEDGE_SVC_PROBLEM;$HostName;$ServiceDesc;2;0;1;AutomaticTicketCreation;$Hostgroup Service $ServiceDesc was CRITICAL \n" $Now | tee -a $ExternalCommandFile $AutomationLogFile
        # Sending Ticket File to Main Poller
        if `scp $AutomationRetentionDir$Ticket_File $MainPoller:$RemoteDir`;then
            rm $AutomationRetentionDir$Ticket_File
            echo "[$Now];TICKET_CREATION;$HostName;$ServiceDesc;$ServiceStateType;$Hostgroup - Success" | tee -a $AutomationLogFile
        fi
    else
        echo "[$Now];TICKET_CREATION;$HostName;$ServiceDesc;$ServiceStateType;$Hostgroup - Failed" | tee -a $AutomationLogFile
        exit
    fi
}

#Core

case $ServiceState in
    "CRITICAL")
        if [ "$ServiceStateType" = "HARD" ] && ( [ "$LastServiceState" == "WARNING" ]  || [ "$LastServiceState" == "UNKNOWN" ] ) && [ $DowntimeStatus -eq 0 ];then
            CreateTicket
        elif [ "$ServiceStateType" = "SOFT" ] && [ "$LastServiceState" != "CRITICAL" ] && [ $DowntimeStatus -eq 0 ];then
            SetDowntime
        elif [ "$ServiceStateType" == "HARD" ];then
            GetDowntimeID
            CreateTicket
            DelDowntime
        fi        
    ;;
    *)
        if [ "$ServiceState" != "UNKNOWN" ] && [ "$LastServiceState" == "CRITICAL" ];then
            GetDowntimeID
            DelDowntime
        fi
    ;;
esac
