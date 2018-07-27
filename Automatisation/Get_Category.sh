#!/bin/bash
# ARGS : HostName ServiceDesc
#
# Note: This script will return 1 if Can_Priority is H2 or Ticket_Auto is 1 
#
# V 1.0 12/07/2018 AGN -- Creation

## Set vars
# Nagios
ClapiCmd="/usr/share/centreon/www/modules/centreon-clapi/core/centreon -u clapi -p clapi_DKT_centreon -o service -a getmacro -v"
ExtractCategories="/home/admin/Automatisation/Scripts/Php/Categories.csv"

# Args
HostName="$1"
ServiceDesc="$2"


Service=$($ClapiCmd "$HostName;$ServiceDesc" | grep "_SERVICESERVICE" | cut -d ";" -f 2)
Category=$($ClapiCmd "$HostName;$ServiceDesc" | grep "_SERVICECATEGORY" | cut -d ";" -f 2)

if [[ $Service == "" ]];then
    CatId=$(grep -E ";NO_CATEGORY$" $ExtractCategories | cut -d ";" -f 1)    
elif [[ $Category == "" ]];then
    CatId=$(grep -E "$Service$" $ExtractCategories | cut -d ";" -f 1)
else
    CatId=$(grep -E "$Service / $Category$" $ExtractCategories | cut -d ";" -f 1)
fi 
echo $CatId
