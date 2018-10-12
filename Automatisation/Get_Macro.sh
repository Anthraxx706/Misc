#!/bin/bash
# ARGS : HostName ServiceDesc
#
# Note: This script will return 1 if Can_Priority is H2 or Ticket_Auto is 1 
#
# V 1.0 12/07/2018 AGN -- Creation

## Set vars
# Nagios
ClapiCmd="/usr/share/centreon/www/modules/centreon-clapi/core/centreon -u clapi -p clapi_DKT_centreon -o service -a getmacro -v"

# Args
HostName="$1"
ServiceDesc="$2"



GROS PD


CanPriority=$($ClapiCmd "$HostName;$ServiceDesc" | grep "CAN_PRIORITY" | cut -d ";" -f 2)
TicketAuto=$($ClapiCmd "$HostName;$ServiceDesc" | grep "TICKET_AUTO" | cut -d ";" -f 2)

if [[ "$CanPriority" == "H2" || $TicketAuto -eq 1 ]];then
    exit 1
else
    exit 0
fi

