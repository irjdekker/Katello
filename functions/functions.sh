#!/bin/bash
# shellcheck disable=SC2181
# shellcheck disable=SC1090

## *************************************************************************************************** ##
##      __      __     _____  _____          ____  _      ______  _____                                ##
##      \ \    / /\   |  __ \|_   _|   /\   |  _ \| |    |  ____|/ ____|                               ##
##       \ \  / /  \  | |__) | | |    /  \  | |_) | |    | |__  | (___                                 ##
##        \ \/ / /\ \ |  _  /  | |   / /\ \ |  _ <| |    |  __|  \___ \                                ##
##         \  / ____ \| | \ \ _| |_ / ____ \| |_) | |____| |____ ____) |                               ##
##          \/_/    \_\_|  \_\_____/_/    \_\____/|______|______|_____/                                ##
##                                                                                                     ##
## *************************************************************************************************** ##
## Following variables are defined in sourced shell script
##      ADMIN_USER
##      ADMIN_PASSWORD
##      ORG_NAME
##      ORG_LOCATION
##      ORG_USER
##      ORG_PASSWORD
##      ORG_MAIL
##      INV_USER
##      INV_PASSWORD
##      INV_MAIL
##      VMWARE_NAME
##      VCENTER
##      VCENTER_USER
##      VCENTER_PASSWORD
##      VMWARE_DC
##      VMWARE_CL
##      VMWARE_NETWORK
##
## The following variables are defined below

IRed='\e[0;31m'
IGreen='\e[0;32m'
IYellow='\e[0;33m'
Reset='\e[0m'
LOGFILE="$HOME/$SCRIPT_NAME-install-$(date +%Y-%m-%d_%Hh%Mm).log"
VAULTFILE="vault.sh"

## *************************************************************************************************** ##
##       _____   ____  _    _ _______ _____ _   _ ______  _____                                        ##
##      |  __ \ / __ \| |  | |__   __|_   _| \ | |  ____|/ ____|                                       ##
##      | |__) | |  | | |  | |  | |    | | |  \| | |__  | (___                                         ##
##      |  _  /| |  | | |  | |  | |    | | | . ` |  __|  \___ \                                        ##
##      | | \ \| |__| | |__| |  | |   _| |_| |\  | |____ ____) |                                       ##
##      |_|  \_\\____/ \____/   |_|  |_____|_| \_|______|_____/                                        ##
##                                                                                                     ##
## *************************************************************************************************** ##

do_download_vaultfile() {
    do_function_task "curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/vault/${VAULTFILE}.enc -o \"/tmp/${VAULTFILE}.enc\""
    do_function_task "/usr/bin/openssl enc -aes-256-cbc -md md5 -d -in \"/tmp/${VAULTFILE}.enc\" -out \"/tmp/${VAULTFILE}\" -pass pass:\"${PASSWORD}\""
    do_function_task "[ -f \"/tmp/${VAULTFILE}.enc\" ] && rm -f \"/tmp/${VAULTFILE}.enc\" || sleep 0.1"
    do_function_task "chmod 700 \"/tmp/${VAULTFILE}\""
}

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

    if [ "${NEWLINE}" = "true" ]; then
        PRINTTEXT+="\n"
    fi

    printf "%b" "${PRINTTEXT}"

    if (( STATUS >= 1 )); then
        tput cvvis
        exit 1
    fi
}

run_cmd() {
    if [ "${COMMAND_DEBUG}" = true ] ; then
        echo "[COMMAND] $*" >> "${LOGFILE}"
    fi
    if eval "$@" >> "${LOGFILE}" 2>&1; then
        return 0
    else
        return 1
    fi
}

do_task() {
    print_task "$1 ($(date +%H:%M))" -1 false
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
    MESSAGE="$1 ($(date +%H:%M))"

    print_task "${MESSAGE}" -1 false
    eval "$2"
    print_task "${MESSAGE}" 0 true
}