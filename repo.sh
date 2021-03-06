#!/bin/bash
# shellcheck disable=SC2181
# shellcheck disable=SC1090

## The easiest way to get the script on your machine is:
## a) without specifying the version
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/repo.sh -o repo.sh 2>/dev/null && bash repo.sh && rm -f repo.sh
## b) with specifying the version
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/repo.sh 2>/dev/null | bash -s <org_id> <version>

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

SCRIPT_NAME="repo"
COMMAND_DEBUG=true
OSSETUP=('8.x,8.3,5,http://mirror.1000mbps.com/centos/8/,BaseOS,BaseOS/x86_64/os/,AppStream,AppStream/x86_64/os/,PowerTools,PowerTools/x86_64/os/,Extras,extras/x86_64/os/,Ansible,configmanagement/x86_64/ansible-29/' \
'8.2,8.2,5,http://mirror.1000mbps.com/centos-vault/8.2.2004/,BaseOS,BaseOS/x86_64/os/,AppStream,AppStream/x86_64/os/,PowerTools,PowerTools/x86_64/os/,Extras,extras/x86_64/os/,Ansible,configmanagement/x86_64/ansible-29/' \
'8.1,8.1,5,http://mirror.1000mbps.com/centos-vault/8.1.1911/,BaseOS,BaseOS/x86_64/os/,AppStream,AppStream/x86_64/os/,PowerTools,PowerTools/x86_64/os/,Extras,extras/x86_64/os/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.x,7.9,4,http://mirror.1000mbps.com/centos/7/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.9,7.9,4,http://mirror.1000mbps.com/centos-vault/7.9.2009/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.8,7.8,4,http://mirror.1000mbps.com/centos-vault/7.8.2003/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.7,7.7,4,http://mirror.1000mbps.com/centos-vault/7.7.1908/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible-29/' \
'7.6,7.6,4,http://mirror.1000mbps.com/centos-vault/7.6.1810/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible27/' \
'7.5,7.5,4,http://mirror.1000mbps.com/centos-vault/7.5.1804/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/,Ansible,configmanagement/x86_64/ansible26/' \
'7.4,7.4,3,http://mirror.1000mbps.com/centos-vault/7.4.1708/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/' \
'7.3,7.3,3,http://mirror.1000mbps.com/centos-vault/7.3.1611/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/' \
'7.2,7.2,3,http://mirror.1000mbps.com/centos-vault/7.2.1511/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/' \
'7.1,7.1,3,http://mirror.1000mbps.com/centos-vault/7.1.1503/,OS,os/x86_64/,Extras,extras/x86_64/,Updates,updates/x86_64/')

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
    local ORG_ID
    ORG_ID="$1"
    local OS_VERSION
    OS_VERSION="$2"
    local OS_NICE
    OS_NICE=${OS_VERSION//[^[:alnum:]-]/_}
    local SYNC_TIME
    SYNC_TIME=$(date --date "1970-01-01 02:00:00 $(shuf -n1 -i0-10800) sec" '+%T')
    local SSH_KEY
    SSH_KEY=$(cat ~foreman-proxy/.ssh/id_rsa_foreman_proxy.pub)
    
    ## Create Katello product
    do_function_task "hammer product create --organization-id \"${ORG_ID}\" --name \"CentOS ${OS_VERSION} Linux x86_64\""

    ## Create Katello synchronization plan
    do_function_task "hammer sync-plan create --organization-id \"${ORG_ID}\" --name \"Daily Sync CentOS ${OS_VERSION}\" --interval daily --enabled true --sync-date \"2020-01-01 ${SYNC_TIME}\""
    do_function_task "hammer product set-sync-plan --organization-id \"${ORG_ID}\" --name \"CentOS ${OS_VERSION} Linux x86_64\" --sync-plan \"Daily Sync CentOS ${OS_VERSION}\""

    ## Create Katello content view
    do_function_task "hammer content-view create --organization-id \"${ORG_ID}\" --name \"CentOS ${OS_VERSION}\" --label \"CentOS_${OS_NICE}\""

    ## Create Katello repositories
    for item in "${OSSETUP[@]}"
    do
        if [[ "${item}" == *","* ]]
        then
            IFS=',' read -ra tmpArray <<< "${item}"
            tmpOS=${tmpArray[0]}
            tmpVersion=${tmpArray[1]}
            tmpItems=${tmpArray[2]}
            tmpBaseUrl=${tmpArray[3]}

            if [[ "${OS_VERSION}" == "${tmpOS}" ]] ; then
                if [[ ${tmpOS:0:1} == "7" ]] ; then
                    tmpGPGKey="RPM-GPG-KEY-CentOS-7"
                elif [[ ${tmpOS:0:1} == "8" ]] ; then
                    tmpGPGKey="RPM-GPG-KEY-CentOS-8"
                else
                    print_task "${MESSAGE}" 1 true
                fi

                for ((i=0; i<tmpItems; i++))
                do
                    tmpName=${tmpArray[4+2*i]}
                    tmpLocation=${tmpArray[5+2*i]}

                    ## Create Katello repository
                    do_function_task "hammer repository create --organization-id \"${ORG_ID}\" --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} ${tmpName} x86_64\" --label \"CentOS_${OS_NICE}_${tmpName}_x86_64\" --content-type \"yum\" --download-policy \"immediate\" --gpg-key \"${tmpGPGKey}\" --url \"${tmpBaseUrl}${tmpLocation}\" --mirror-on-sync \"no\""

                    ## Synchronize Katello repository
                    do_function_task_retry "hammer repository synchronize --organization-id \"${ORG_ID}\" --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} ${tmpName} x86_64\"" "5"

                    ## Add repository to content view
                    do_function_task "hammer content-view add-repository --organization-id \"${ORG_ID}\" --name \"CentOS ${OS_VERSION}\" --product \"CentOS ${OS_VERSION} Linux x86_64\" --repository \"CentOS ${OS_VERSION} ${tmpName} x86_64\""
                done

                break
            fi
        fi
    done

    ## Add Katello repositories to content view
    do_function_task "hammer content-view add-repository --organization-id \"${ORG_ID}\" --name \"CentOS ${OS_VERSION}\" --product \"Katello Client\" --repository \"Katello Client\""

    ## Publish and promote content view
    do_function_task "hammer content-view publish --organization-id \"${ORG_ID}\" --name \"CentOS ${OS_VERSION}\" --description \"Initial publishing\""
    while read -r lcm;
    do
        do_function_task "hammer content-view version promote --organization-id \"${ORG_ID}\" --content-view \"CentOS ${OS_VERSION}\" --version \"1.0\" --to-lifecycle-environment \"${lcm}\""
    done < <(hammer --no-headers lifecycle-environment list --order "id asc" --fields Name | grep -v "Library")

    ## Create Katello activation keys
    while read -r lcm;
    do
        do_function_task "hammer activation-key create --organization-id \"${ORG_ID}\" --name \"CentOS_${OS_NICE}_${lcm}_Key\" --lifecycle-environment \"${lcm}\" --content-view \"CentOS ${OS_VERSION}\" --unlimited-hosts"
    done < <(hammer --no-headers lifecycle-environment list --order "id asc" --fields Name | grep -v "Library")

    ## Assign activation keys to Katello subscription (current view)
    local sub_centos_id
    sub_centos_id=$(hammer --no-headers subscription list --fields Id --search "CentOS ${OS_VERSION} Linux x86_64" | awk '{$1=$1};1')
    local sub_katello_id
    sub_katello_id=$(hammer --no-headers subscription list --fields Id --search "Katello Client" | awk '{$1=$1};1')
    while read -r lcm;
    do
        do_function_task "hammer activation-key add-subscription --organization-id \"${ORG_ID}\" --name \"CentOS_${OS_NICE}_${lcm}_Key\" --quantity \"1\" --subscription-id \"${sub_centos_id}\""
        do_function_task "hammer activation-key add-subscription --organization-id \"${ORG_ID}\" --name \"CentOS_${OS_NICE}_${lcm}_Key\" --quantity \"1\" --subscription-id \"${sub_katello_id}\""
    done < <(hammer --no-headers lifecycle-environment list --order "id asc" --fields Name | grep -v "Library")

    ## Check Operating System
    if [[ ${tmpOS:0:1} == "8" ]] ; then
        os_new_id=$(hammer --no-headers os list --fields Id --search "CentOS-8" | awk '{$1=$1};1')
        if [ -z "${os_new_id}" ]; then
            os_old_id=$(hammer --no-headers os list --fields Id --search "CentOS_Linux-8" | awk '{$1=$1};1')
            if [ -n "${os_old_id}" ]; then
                do_function_task "hammer os update --id ${os_old_id} --description \"CentOS-8\""
            else
                exit 1
            fi
        fi
    fi

    ## Create Katello hostgroup
    while read -r location;
    do
        domain_id=$(hammer --no-headers domain list --organization-id "${ORG_ID}" --location "$location" --fields Id | awk '{$1=$1};1')
        while read -r lcm;
        do
            lcm_lower=$(echo "$lcm" | tr "[:upper:]" "[:lower:]")
            location_lower=$(echo "$location" | tr "[:upper:]" "[:lower:]")
            hostgroup_name="hg_${lcm_lower}_${location_lower}_${OS_NICE}"

            do_function_task "hammer hostgroup create --organization-id \"${ORG_ID}\" --location \"${location}\" --name \"${hostgroup_name}\" --lifecycle-environment \"${lcm}\" --content-view \"CentOS ${OS_VERSION}\" --content-source \"katello.tanix.nl\" --compute-resource \"${VLT_KAT_VMWARE_NAME}\" --compute-profile \"1-Small\" --domain-id \"${domain_id}\" --subnet \"tanix-5\" --architecture \"x86_64\" --operatingsystem \"CentOS-${tmpOS:0:1}\" --partition-table \"Kickstart default\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"centos-version\" --parameter-type string --value \"${tmpVersion}\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"yum-config-manager-disable-repo\" --parameter-type boolean --value \"true\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"host_registration_remote_execution\" --parameter-type boolean --value \"true\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"remote_execution_ssh_keys\" --parameter-type string --value \"${SSH_KEY}\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"enable-epel\" --parameter-type boolean --value \"false\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"kt_activation_keys\" --value \"CentOS_${OS_NICE}_${lcm}_Key\""
        done < <(hammer --no-headers lifecycle-environment list --fields Name | grep -v "Library")
    done < <(hammer --no-headers location list --fields Name)
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

echo 'Welcome to Repo installer'

## Check if version is specified
if [[ $# -eq 3 ]]; then
    PASSWORD="$1"
    ORG_ID="$2"
    VERSION="$3"
else
    echo -n "Password: "
    read -rs PASSWORD
    echo

    ## Check if password is specified
    if [[ -z "${PASSWORD}" ]]; then
        echo "No password supplied"
        exit 1
    fi
    
    echo -n "Organization ID: "
    read -rs ORG_ID
    echo

    ## Check if organization id is specified
    if [[ -z "${ORG_ID}" ]]; then
        echo "No organization ID supplied"
        exit 1
    fi

    echo -n "Version: "
    read -rs VERSION
    echo

    ## Check if version is specified
    if [[ -z "${VERSION}" ]]; then
        echo "No version supplied"
        exit 1
    fi
fi

## Check if script run by user root
if [ "$(whoami)" != "root" ]; then
    echo "Script startup must be run as user: root"
    exit 1
fi

# Hide cursor
tput civis

# Download functions file
curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/functions/functions.sh -o "/tmp/functions.sh"

# Source functions file
if [ -f "/tmp/functions.sh" ]; then
    source "/tmp/functions.sh"
else
    echo "Functions file not available"
    exit 1
fi

# Download vault file
do_function "Download vault file" "do_download_vaultfile"

# Source vault file
if [ -f "/tmp/$VAULTFILE" ]; then
    source "/tmp/$VAULTFILE"
else
    echo "Vault file not available"
    exit 1
fi

## Create Katello setup for CentOS specific version
do_function "Create Katello setup for CentOS ${VERSION}" "do_populate_katello \"${ORG_ID}\" \"${VERSION}\""

# Restore cursor
tput cvvis
