#!/bin/bash
# shellcheck disable=SC2181

## The easiest way to get the script on your machine is:
## a) without specifying the version
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/repo.sh -o repo.sh 2>/dev/null && bash repo.sh && rm -f repo.sh
## wget -O repo.sh https://raw.githubusercontent.com/irjdekker/Katello/master/repo.sh 2>/dev/null && bash repo.sh && rm -f repo.sh
## b) with specifying the version
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/repo.sh 2>/dev/null | bash -s <version>
## wget -O - https://raw.githubusercontent.com/irjdekker/Katello/master/repo.sh 2>/dev/null | bash -s <version>

## *************************************************************************************************** ##
##      __      __     _____  _____          ____  _      ______  _____                                ##
##      \ \    / /\   |  __ \|_   _|   /\   |  _ \| |    |  ____|/ ____|                               ##
##       \ \  / /  \  | |__) | | |    /  \  | |_) | |    | |__  | (___                                 ##
##        \ \/ / /\ \ |  _  /  | |   / /\ \ |  _ <| |    |  __|  \___ \                                ##
##         \  / ____ \| | \ \ _| |_ / ____ \| |_) | |____| |____ ____) |                               ##
##          \/_/    \_\_|  \_\_____/_/    \_\____/|______|______|_____/                                ##
##                                                                                                     ##
## *************************************************************************************************** ##
##
## The following variables are defined below

OSSETUP=('8.x,5,http://mirror.1000mbps.com/centos/8/,BaseOS,BaseOS/x86_64/os/,AppStream,AppStream/x86_64/os/,PowerTools,PowerTools/x86_64/os/,Extras,extras/x86_64/os/,Ansible,configmanagement/x86_64/ansible-29/' \
'8.2,5,http://mirror.1000mbps.com/centos-vault/8.2.2004/,BaseOS,BaseOS/x86_64/os/,AppStream,AppStream/x86_64/os/,PowerTools,PowerTools/x86_64/os/,Extras,extras/x86_64/os/,Ansible,configmanagement/x86_64/ansible-29/' \
'8.1,5,http://mirror.1000mbps.com/centos-vault/8.1.1911/,BaseOS,BaseOS/x86_64/os/,AppStream,AppStream/x86_64/os/,PowerTools,PowerTools/x86_64/os/,Extras,extras/x86_64/os/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.x,4,http://mirror.1000mbps.com/centos/7/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.9,4,http://mirror.1000mbps.com/centos-vault/7.9.2009/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.8,4,http://mirror.1000mbps.com/centos-vault/7.8.2003/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.7,4,http://mirror.1000mbps.com/centos-vault/7.7.1908/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.6,4,http://mirror.1000mbps.com/centos-vault/7.6.1810/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible27/' \
'7.5,4,http://mirror.1000mbps.com/centos-vault/7.5.1804/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible26/' \
'7.4,3,http://mirror.1000mbps.com/centos-vault/7.4.1708/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/' \
'7.3,3,http://mirror.1000mbps.com/centos-vault/7.3.1611/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/' \
'7.2,3,http://mirror.1000mbps.com/centos-vault/7.2.1511/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/' \
'7.1,3,http://mirror.1000mbps.com/centos-vault/7.1.1503/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/')
LOGFILE="$HOME/repo-install-$(date +%Y-%m-%d_%Hh%Mm).log"
IRed='\e[0;31m'
IGreen='\e[0;32m'
IYellow='\e[0;33m'
Reset='\e[0m'
VMWARE="vmware_home"

## *************************************************************************************************** ##
##       _____   ____  _    _ _______ _____ _   _ ______  _____                                        ##
##      |  __ \ / __ \| |  | |__   __|_   _| \ | |  ____|/ ____|                                       ##
##      | |__) | |  | | |  | |  | |    | | |  \| | |__  | (___                                         ##
##      |  _  /| |  | | |  | |  | |    | | | . ` |  __|  \___ \                                        ##
##      | | \ \| |__| | |__| |  | |   _| |_| |\  | |____ ____) |                                       ##
##      |_|  \_\\____/ \____/   |_|  |_____|_| \_|______|_____/                                        ##
##                                                                                                     ##
## *************************************************************************************************** ##

do_populate_katello() {
    local OS_VERSION
    OS_VERSION="$1"
    local OS_NICE
    OS_NICE=${OS_VERSION//[^[:alnum:]-]/_}
    local SYNC_TIME
    SYNC_TIME=$(date --date "1970-01-01 02:00:00 $(shuf -n1 -i0-10800) sec" '+%T')

    ## Create Katello product
    do_function_task "hammer product create --organization-id 1 --name \"CentOS ${OS_VERSION} Linux x86_64\""
    
    ## Create Katello synchronization plan
    do_function_task "hammer sync-plan create --organization-id 1 --name \"Daily Sync CentOS ${OS_VERSION}\" --interval daily --enabled true --sync-date \"2020-01-01 ${SYNC_TIME}\""
    do_function_task "hammer product set-sync-plan --organization-id 1 --name \"CentOS ${OS_VERSION} Linux x86_64\" --sync-plan \"Daily Sync CentOS ${OS_VERSION}\""

    ## Create Katello content view
    do_function_task "hammer content-view create --organization-id 1 --name \"CentOS ${OS_VERSION}\" --label \"CentOS_${OS_NICE}\""    

    ## Create Katello repositories
    for item in "${OSSETUP[@]}"
    do
        if [[ "${item}" == *","* ]]
        then
            IFS=',' read -ra tmpArray <<< "${item}"
            tmpOS=${tmpArray[0]}
            tmpItems=${tmpArray[1]}
            tmpBaseUrl=${tmpArray[2]}

            if [[ "${OS_VERSION}" == "${tmpOS}" ]] ; then
                if [[ ${tmpOS:0:1} == "7" ]] ; then 
                    tmpGPGKey = "RPM-GPG-KEY-CentOS-7"
                elif [[ ${tmpOS:0:1} == "8" ]] ; then
                    tmpGPGKey = "RPM-GPG-KEY-CentOS-8"
                else 
                    print_task "${MESSAGE}" 1 true 
                fi
                
                for ((i=0; i<tmpItems; i++))
                do
                    tmpName=${tmpArray[3+2*i]}
                    tmpLocation=${tmpArray[4+2*i]}
                    
                    ## Create Katello repository
                    do_function_task "hammer repository create --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} ${tmpName} x86_64\" --label \"CentOS_${OS_NICE}_${tmpName}_x86_64\" --content-type \"yum\" --download-policy \"immediate\" --gpg-key \"${tmpGPGKey}\" --url \"${tmpBaseUrl}${tmpLocation}\" --mirror-on-sync \"no\""
                    
                    ## Synchronize Katello repository
                    do_function_task_retry "hammer repository synchronize --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} ${tmpName} x86_64\"" "5"
                    
                    ## Add repository to content view
                    do_function_task "hammer content-view add-repository --organization-id 1 --name \"CentOS ${OS_VERSION}\" --product \"CentOS ${OS_VERSION} Linux x86_64\" --repository \"CentOS ${OS_VERSION} ${tmpName} x86_64\""                        
                done
            fi
        fi
    done

    ## Add Katello repositories to content view
    do_function_task "hammer content-view add-repository --organization-id 1 --name \"CentOS ${OS_VERSION}\" --product \"Katello Client 7\" --repository \"Katello Client 7\""

    ## Publish and promote content view
    do_function_task "hammer content-view publish --organization-id 1 --name \"CentOS ${OS_VERSION}\" --description \"Initial publishing\""
    hammer --no-headers lifecycle-environment list --order "id asc" --fields Name | grep -v "Library" | while read -r lcm;
    do
        do_function_task "hammer content-view version promote --organization-id 1 --content-view \"CentOS ${OS_VERSION}\" --version \"1.0\" --to-lifecycle-environment \"${lcm}\""
    done
    if [ $? -ne 0 ]; then exit 1; fi

    ## Create Katello activation keys
    hammer --no-headers lifecycle-environment list --order "id asc" --fields Name | grep -v "Library" | while read -r lcm;
    do
        do_function_task "hammer activation-key create --organization-id 1 --name \"CentOS_${OS_NICE}_${lcm}_Key\" --lifecycle-environment \"${lcm}\" --content-view \"CentOS ${OS_VERSION}\" --unlimited-hosts"
    done
    if [ $? -ne 0 ]; then exit 1; fi    

    ## Assign activation keys to Katello subscription (current view)
    local sub_centos_id
    sub_centos_id=$(hammer --no-headers subscription list --fields Id --search "CentOS ${OS_VERSION} Linux x86_64" | awk '{$1=$1};1')
    local sub_katello_id
    sub_katello_id=$(hammer --no-headers subscription list --fields Id --search "Katello Client 7" | awk '{$1=$1};1')
    hammer --no-headers lifecycle-environment list --order "id asc" --fields Name | grep -v "Library" | while read -r lcm;
    do
        do_function_task "hammer activation-key add-subscription --organization-id 1 --name \"CentOS_${OS_NICE}_${lcm}_Key\" --quantity \"1\" --subscription-id \"${sub_centos_id}\""
        do_function_task "hammer activation-key add-subscription --organization-id 1 --name \"CentOS_${OS_NICE}_${lcm}_Key\" --quantity \"1\" --subscription-id \"${sub_katello_id}\""        
    done  
    if [ $? -ne 0 ]; then exit 1; fi
    
    ## Create Katello hostgroup
    hammer --no-headers location list --fields Name | while read -r location; 
    do
        domain_id=$(hammer --no-headers domain list --organization-id 1 --location "$location" --fields Id | awk '{$1=$1};1')
        hammer --no-headers lifecycle-environment list --fields Name | grep -v "Library" | while read -r lcm;
        do
            lcm_lower=$(echo "$lcm" | tr "[:upper:]" "[:lower:]")
            location_lower=$(echo "$location" | tr "[:upper:]" "[:lower:]")
            hostgroup_name="hg_${lcm_lower}_${location_lower}_${OS_NICE}"
            
            do_function_task "hammer hostgroup create --organization-id 1 --location \"${location}\" --name \"${hostgroup_name}\" --lifecycle-environment \"${lcm}\" --content-view \"CentOS ${OS_VERSION}\" --content-source \"katello.tanix.nl\" --compute-resource \"${VMWARE}\" --compute-profile \"1-Small\" --domain-id \"${domain_id}\" --subnet \"tanix-5\" --architecture \"x86_64\" --operatingsystem \"CentOS-7\" --partition-table \"Kickstart default\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"yum-config-manager-disable-repo\" --parameter-type boolean --value \"true\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"enable-epel\" --parameter-type boolean --value \"false\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"kt_activation_keys\" --value \"CentOS_${OS_NICE}_${lcm}_Key\""            
        done
        if [ $? -ne 0 ]; then exit 1; fi
    done
    if [ $? -ne 0 ]; then exit 1; fi    
}

print_padded_text() {
    pad=$(printf '%0.1s' "*"{1..70})
    padlength=140
    updatetext=" $(date -u ) - $1 "
    padleft=$(( (padlength - ${#updatetext}) / 2 ))
    padright=$(( padlength - ${#updatetext} - padleft ))

    printf '%*.*s' 0 $padleft "${pad}"
    printf '%s' "$updatetext"
    printf '%*.*s' 0 $padright "${pad}"
    printf '\n'
}

print_task() {
    local TEXT
    TEXT="$1"
    local STATUS
    STATUS="$2"
    local NEWLINE
    NEWLINE="$3"

    if (( STATUS == -3 )); then
        PRINTTEXT="\r[ ${IYellow}WARN${Reset} ] "
    elif (( STATUS == -2 )); then
        PRINTTEXT="\r         "
    elif (( STATUS == -1 )); then
        print_padded_text "${TEXT}" >> "${LOGFILE}"
        PRINTTEXT="\r[      ] "
    elif (( STATUS == 0 )); then
        PRINTTEXT="\r[  ${IGreen}OK${Reset}  ] "
    elif (( STATUS >= 1 )); then
        PRINTTEXT="\r[ ${IRed}FAIL${Reset} ] "
    else
        PRINTTEXT="\r         "
    fi

    PRINTTEXT+="${TEXT}"

    if [ "${NEWLINE}" = "true" ] ; then
        PRINTTEXT+="\n"
    fi

    printf "%b" "${PRINTTEXT}"

    if (( STATUS >= 1 )); then
        tput cvvis
        exit 1
    fi
}

run_cmd() {
    if eval "$@" >> "${LOGFILE}" 2>&1; then
        return 0
    else
        return 1
    fi
}

do_task() {
    print_task "$1" -1 false
    if run_cmd "$2"; then
        print_task "$1" 0 true
    else
        print_task "$1" 1 true
    fi
}

do_function_task() {
    if ! run_cmd "$1"; then
        print_task "${MESSAGE}" 1 true
    fi
}

do_function_task_retry() {
    local COUNT=0
    local RETRY
    RETRY="$2"

    while :
    do
        if ! run_cmd "$1"; then
            COUNT=$(( COUNT + 1 ))
            print_task "${MESSAGE} (${COUNT})" -3 false
            sleep 60
            if (( COUNT == RETRY )); then
                print_task "${MESSAGE}" 1 true
            fi
        else
            print_task "${MESSAGE}     " -1 false
            break
        fi
    done
}

do_function_task_if() {
    if ! run_cmd "$1"; then
        do_function_task "$2"
    else
        do_function_task "$3"
    fi
}

do_function() {
    MESSAGE="$1"

    print_task "${MESSAGE}" -1 false
    eval "$2"
    print_task "${MESSAGE}" 0 true
}

## *************************************************************************************************** ##
##        __  __          _____ _   _                                                                  ##
##       |  \/  |   /\   |_   _| \ | |                                                                 ##
##       | \  / |  /  \    | | |  \| |                                                                 ##
##       | |\/| | / /\ \   | | | . ` |                                                                 ##
##       | |  | |/ ____ \ _| |_| |\  |                                                                 ##
##       |_|  |_/_/    \_\_____|_| \_|                                                                 ##
##                                                                                                     ##
## *************************************************************************************************** ##

echo 'Welcome to Katello installer'

## Check if password is specified
if [[ $# -eq 0 ]]; then
    echo -n "Version: " 
    read -rs VERSION
    echo

    ## Check if password is specified
    if [[ -z "${VERSION}" ]]; then
        echo "No version supplied"
        exit 1
    fi
else
    VERSION="$1"
fi

## Check if script run by user root
if [ "$(whoami)" != "root" ]; then
    echo "Script startup must be run as user: root"
    exit 1
fi

# Hide cursor
tput civis

## Create Katello setup for CentOS specific version
do_function "Create Katello setup for CentOS ${VERSION}" "do_populate_katello \"${VERSION}\""

# Restore cursor
tput cvvis