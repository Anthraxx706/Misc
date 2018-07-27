#!/bin/bash
# ARGS : HostName ServiceDesc
#
# Note: This script will get the last Nagios status for Host/Service
#
# V 1.0 30/05/2018 AGN -- Creation

## Set vars
# Nagios
NagiosStatusFile="/var/log/nagios/status.dat"

# Args
HostName="$1"
ServiceDesc="$2"

GetStatus(){
case "$ExitCode" in
    0)
        Status="OK"
        ;;
    1)
        Status="WARNING"
        ;;
    2)
        Status="CRITICAL"
        ;;
    3)
        Status="UNKNOWN"
        ;;
    *)
        Status="CRITICAL"
        ;;
esac
echo $Status
}

#Get State of $HostName $ServiceDesc
ExitCode=`awk '/servicestatus/,/}/{print}' /var/log/nagios/status.dat | awk '{FS="=";} /host_name=/{host=$2;}/service_description=/{service=$2;}/current_state=/{current_state=$2;if (host=="'$HostName'" && service=="'$ServiceDesc'") print current_state;}'`

GetStatus
