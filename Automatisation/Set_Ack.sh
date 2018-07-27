#!/bin/bash
# ARGS : HostName ServiceDesc
#
# Note: This script will set Acknoledge on Service
#
# V 1.0 29/06/2018 AGN -- Creation

## Set vars
# Nagios
ExternalCommandFile="/var/spool/nagios/cmd/nagios.cmd"
Author="Automatic Creation"
Now=$(date +%s)

# Args
HostName="$1"
ServiceDesc="$2"
TicketId="$3"
SawUrl="https://support.decathlon.com/saw/Incident/$TicketId/general?TENANTID=157222659"
Comment="<a target=\"_blank\" href=\"$SawUrl\"> Incident $TicketId </a>"

#Set Acknowledge
printf "[%lu] ACKNOWLEDGE_SVC_PROBLEM;$HostName;$ServiceDesc;2;0;1;$Author;$Comment \n" $Now | tee -a $ExternalCommandFile

