#!/bin/bash
# shellcheck disable=SC2181

## The easiest way to get the script on your machine is:
## a) without specifying the password
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/awx.sh -o awx.sh 2>/dev/null && bash awx.sh && rm -f awx.sh
## wget -O awx.sh https://raw.githubusercontent.com/irjdekker/Katello/master/awx.sh 2>/dev/null && bash awx.sh && rm -f awx.sh
## b) with specifying the password
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/awx.sh 2>/dev/null | bash -s <password>
## wget -O - https://raw.githubusercontent.com/irjdekker/Katello/master/awx.sh 2>/dev/null | bash -s <password>

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

LOGFILE="$HOME/awx-install-$(date +%Y-%m-%d_%Hh%Mm).log"
IRed='\e[0;31m'
IGreen='\e[0;32m'
IYellow='\e[0;33m'
Reset='\e[0m'

## *************************************************************************************************** ##
##       _____   ____  _    _ _______ _____ _   _ ______  _____                                        ##
##      |  __ \ / __ \| |  | |__   __|_   _| \ | |  ____|/ ____|                                       ##
##      | |__) | |  | | |  | |  | |    | | |  \| | |__  | (___                                         ##
##      |  _  /| |  | | |  | |  | |    | | | . ` |  __|  \___ \                                        ##
##      | | \ \| |__| | |__| |  | |   _| |_| |\  | |____ ____) |                                       ##
##      |_|  \_\\____/ \____/   |_|  |_____|_| \_|______|_____/                                        ##
##                                                                                                     ##
## *************************************************************************************************** ##

do_setup_locale() {
    do_function_task "localectl set-locale LC_CTYPE=en_US.utf8"
    do_function_task "localectl status"
}

do_check_hostname() {
    do_function_task "hostnamectl status"
    do_function_task "dnsdomainname -f"
    do_function_task "hostname"
}

do_setup_chrony() {
    do_function_task "yum install chrony -y"
    do_function_task "systemctl enable chronyd"
    do_function_task "systemctl start chronyd"
    do_function_task "chronyc sources"
}

do_setup_ntp() {
    do_function_task "timedatectl set-ntp true"
    do_function_task "timedatectl status"
}

do_disable_firewall() {
    do_function_task "systemctl stop firewalld"
    do_function_task "systemctl disable firewalld"
}

do_disable_selinux() {
    do_function_task "sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config"
    do_function_task "setenforce 0"
    do_function_task "sestatus | grep mode"
}

do_add_repositories() {
    do_function_task "dnf install epel-release -y"
    do_function_task "dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo -y"
}

do_setup_docker() {
    do_function_task "dnf install docker-ce -y"
    do_function_task "systemctl start docker"
    do_function_task "systemctl enable docker"
    do_function_task "systemctl --no-pager status docker"
}

do_install_docker_compose() {
    do_function_task "pip3 install --upgrade pip"
    do_function_task "pip3 install docker-compose"
}

do_clone_awx() {
    do_function_task "git clone https://github.com/ansible/awx.git"
    do_function_task "cd awx"
    do_function_task "git clone https://github.com/ansible/awx-logos.git"
    do_function_task "cd installer"
}

do_update_inventory() {
    local PASSWORD
    PASSWORD="$1"
    local SECRET_KEY
    SECRET_KEY=$(openssl rand -base64 30 | sed 's/[\\&*./+!]/\\&/g')

    do_function_task "sed -i \"s/^\s*admin_password=password\s*$/admin_password=${PASSWORD}/g\" /root/awx/installer/inventory"
    do_function_task "sed -i 's/^.*create_preload_data.*$/create_preload_data=false/g' /root/awx/installer/inventory"
    do_function_task "sed -i \"s/^\s*secret_key=awxsecret\s*$/secret_key=${SECRET_KEY}/g\" /root/awx/installer/inventory"
    do_function_task "sed -i 's/^.*awx_official.*$/awx_official=true/g' /root/awx/installer/inventory"
    do_function_task "sed -i 's/^.*awx_alternate_dns_servers.*$/awx_alternate_dns_servers=\"10.10.5.1\"/g' /root/awx/installer/inventory"
    do_function_task "sed -i 's/^.*\(project_data_dir.*\)$/\1/g' /root/awx/installer/inventory"
}

do_install_playbook() {
    do_function_task "sed -i \"s|/usr/bin/awx-manage create_preload_data|sleep 600 \&\& exec /usr/bin/awx-manage create_preload_data'|g\" ./roles/local_docker/tasks/compose.yml"
    do_function_task "ansible-playbook -i inventory install.yml -vv"
}

do_configure_awx() {
    local PASSWORD
    PASSWORD="$1"

    export TOWER_HOST=http://localhost
    local EXPORT
    EXPORT=$(TOWER_USERNAME=admin TOWER_PASSWORD="$PASSWORD" awx login -f human)
    eval "${EXPORT}"
    awx config

    do_function_task "awx organizations create --name Tanix --description Tanix --max_hosts 100"

    local ORGANIZATION_ID
    if [ "$(awx organizations list --name Tanix -f human --filter id | tail -n +3 | wc -l | xargs echo )" == "1" ]; then
        ORGANIZATION_ID=$(awx organizations list --name Tanix -f human --filter id | tail -n +3)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx teams create --name Dekker --description Dekker --organization ${ORGANIZATION_ID}"

    local TEAM_ID
    if [ "$(awx teams list --name Dekker -f human --filter id | tail -n +3 | wc -l | xargs echo )" == "1" ]; then
        TEAM_ID=$(awx teams list --name Dekker -f human --filter id | tail -n +3)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx users create --username irjdekker --email ir.j.dekker@gmail.com --first_name Jeroen --last_name Dekker --password ${PASSWORD}"

    local USER_ID
    if [ "$(awx users list --username irjdekker -f human --filter id | tail -n +3 | wc -l | xargs echo )" == "1" ]; then
        USER_ID=$(awx users list --username irjdekker -f human --filter id | tail -n +3)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx users grant --organization ${ORGANIZATION_ID} --role admin ${USER_ID}"
    do_function_task "awx users grant --team ${TEAM_ID} --role member ${USER_ID}"

    local CRED_TYPE_ID
    if [ "$(awx credential_types get "Red Hat Satellite 6" -f human --filter id | tail -n +3 | wc -l | xargs echo )" == "1" ]; then
        CRED_TYPE_ID=$(awx credential_types get "Red Hat Satellite 6" -f human --filter id | tail -n +3)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx credentials create --name katello_inventory --organization ${ORGANIZATION_ID} --credential_type ${CRED_TYPE_ID} --inputs \"{host: 'https://katello.tanix.nl', username: 'sync_inventory', password: 'Hwbod6ZS27IAMj'}\""

    local CRED_ID
    if [ "$(awx credentials get Katello -f human --filter id | tail -n +3 | wc -l | xargs echo )" == "1" ]; then
        CRED_ID=$(awx credentials get Katello -f human --filter id | tail -n +3)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx inventory create --name \"Katello inventory\" --organization ${ORGANIZATION_ID}"

    local INV_ID
    if [ "$(awx inventory get \"Katello inventory\" -f human --filter id | tail -n +3 | wc -l | xargs echo )" == "1" ]; then
        INV_ID=$(awx inventory get \"Katello inventory\" -f human --filter id | tail -n +3)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx inventory_sources create --name Katello --source satellite6 --credential ${CRED_ID} --update_on_launch true --inventory ${INV_ID}"

    local INV_SRC_ID
    if [ "$(awx inventory_sources get Katello -f human --filter id | tail -n +3 | wc -l | xargs echo )" == "1" ]; then
        INV_SRC_ID=$(awx inventory_sources get Katello -f human --filter id | tail -n +3)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx inventory_sources update ${INV_SRC_ID}"
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
    local TIMEOUT
    if [[ -z "$3" ]]; then
        TIMEOUT="60"
    else
        TIMEOUT="$3"
    fi

    while :
    do
        if ! run_cmd "$1"; then
            COUNT=$(( COUNT + 1 ))
            print_task "${MESSAGE} (${COUNT})" -3 false
            sleep "${TIMEOUT}"
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

echo 'Welcome to AWX installer'

## Check if password is specified
if [[ $# -eq 0 ]]; then
    echo -n "Password: "
    read -rs PASSWORD
    echo

    ## Check if password is specified
    if [[ -z "${PASSWORD}" ]]; then
        echo "No password supplied"
        exit 1
    fi
else
    PASSWORD="$1"
fi

## Check if script run by user root
if [ "$(whoami)" != "root" ]; then
    echo "Script startup must be run as user: root"
    exit 1
fi

# Hide cursor
tput civis

do_task "Test123" "sleep 60"
exit 0

## Setup locale
do_function "Setup locale" "do_setup_locale"

## Check hostname
do_function "Check hostname" "do_check_hostname"

## Setup chrony
do_function "Setup chrony" "do_setup_chrony"

## Setup NTP
do_function "Setup NTP" "do_setup_ntp"

## Disable firewalld for AWX
do_function "Disable firewalld for AWX" "do_disable_firewall"

## Disable SELinux for AWX
do_function "Disable SELinux for AWX" "do_disable_selinux"

## Update system
do_task "Update system" "yum update -y"

## Add repositories for AWX
do_function "Add repositories for AWX" "do_add_repositories"

## Install required packages
do_task "Install required packages" "dnf install git gcc gcc-c++ ansible nodejs gettext device-mapper-persistent-data lvm2 bzip2 python3-pip wget vim curl -y"

## Install and enable docker service
do_function "Install and enable docker service" "do_setup_docker"

## Install docker-compose
do_function "Install docker-compose" "do_install_docker_compose"

## Correct Python version
do_task "Correct Python version" "alternatives --set python /usr/bin/python3"

## Clone AWX Git repository
do_function "Clone AWX Git repository" "do_clone_awx"

## Create required folders
do_task "Create required folders" "mkdir -p /var/lib/awx/projects && mkdir -p /var/lib/pgdocker"

## Update inventory file
do_function "Update inventory file" "do_update_inventory \"${PASSWORD}\""

## Install AWX
do_function "Install AWX" "do_install_playbook"

## Install AWX CLI
do_task "Install AWX CLI" "pip3 install awxkit"

## Configure AWX
do_function "Configure AWX" "do_configure_awx \"${PASSWORD}\""

## Install VMWare Tools
do_task "Install VMWare Tools" "yum install open-vm-tools -y"

## Install JQ
do_task "Install JQ" "yum install jq -y"

## Update system (again)
do_task "Update system" "yum update -y"

# Restore cursor
tput cvvis