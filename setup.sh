#!/bin/bash
# shellcheck disable=SC2024
# shellcheck source=/dev/null
##
##  This version of the script (December 2020) includes changes to start initial setup on Katello
##
##  This script is the product of many, many months of work and includes
##
## The easiest way to get the script on your machine is:
## wget -O - https://raw.githubusercontent.com/irjdekker/Katello/master/setup.sh 2>/dev/null | bash -s <password>
##
## 06/12/2020 Copied initial script from DomoPi repository
##
## Typically, sitting in your home directory (/root) as user root you might want to use NANO editor to install this script
## and after giving the script execute permission (sudo chmod 0744 /root/setup.sh)
## you could run the file as ./setup.sh
##
## Updates needed
## - Remove content from DomoPi
##
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
## Following variables are defined in sourced shell script
##      SYSTEM_IP
##      SYSTEM_USER
##      SYSTEM_PASSWORD
##      STRIP_IP
##      STRIP_URL
##      STRIP_USERNAME
##      NEFIT_SERIAL_NUMBER
##      NEFIT_ACCESS_KEY
##      NEFIT_PASSWORD
##      PUSHOVER_USER
##      PUSHOVER_TOKEN
##      CERT_API
##      CERT_EMAIL
##      CERT_PASSWORD
##      CHECK_URL
##      POSTFIX_PASSWORD
##      S3FS_PASSWORD
##
## The following variables are defined below

EXECUTIONSETUP=('1,true,true')
EXECUTIONFROM="Internet"
SCRIPTFILE="$HOME/setup.sh"
CONFIGFILE="$HOME/setup.conf"
SOURCEFILE="$HOME/source.sh"
ENCSOURCEFILE="$SOURCEFILE.enc"
IRed='\e[0;31m'
IGreen='\e[0;32m'
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

do_test_internet() {
    local COUNT=0

    while true; do
        run_cmd "ping -c 1 8.8.8.8 > /tmp/setup.err 2>&1 && ! grep -q '100%' /tmp/setup.err" && break
        sleep 10

        COUNT=$(( COUNT + 1 ))
        if (( COUNT == 3 )) ; then print_task "$MESSAGE" 1 true ; fi
    done
}

print_padded_text() {
    pad=$(printf '%0.1s' "*"{1..70})
    padlength=140
    updatetext=" $(date -u ) - $1 "
    padleft=$(( (padlength - ${#updatetext}) / 2 ))
    padright=$(( padlength - ${#updatetext} - padleft ))

    printf '%*.*s' 0 $padleft "$pad"
    printf '%s' "$updatetext"
    printf '%*.*s' 0 $padright "$pad"
    printf '\n'
}

print_task() {
    local TEXT="$1"
    local STATUS="$2"
    local NEWLINE="$3"

    if (( STATUS == -2 )); then
        PRINTTEXT="\r         "
    elif (( STATUS == -1 )); then
        if [[ "$EXECUTIONFROM" != "Internet" ]]; then
            print_padded_text "$TEXT" >> "$LOGFILE"
        fi
        PRINTTEXT="\r[      ] "
    elif (( STATUS == 0 )); then
        PRINTTEXT="\r[  ${IGreen}OK${Reset}  ] "
    elif (( STATUS >= 1 )); then
        PRINTTEXT="\r[ ${IRed}FAIL${Reset} ] "
    else
        PRINTTEXT="\r         "
    fi

    PRINTTEXT+="$TEXT"

    if [ "$NEWLINE" = "true" ] ; then
        PRINTTEXT+="\n"
    fi

    printf "%b" "$PRINTTEXT"

    if (( STATUS >= 1 )); then
        if [[ "$EXECUTIONFROM" != "Internet" ]]; then
            inform_user "Step $STEP has failed: $TEXT"
        else
            inform_user "Installation of setup script has failed"
            exit
        fi
    fi
}

run_cmd() {
    if [[ "$EXECUTIONFROM" != "Internet" ]]; then
        if eval "$@" >> "$LOGFILE" 2>&1; then
            return 0
        else
            return 1
        fi
    else
        if eval "$@" >> /dev/null 2>&1; then
            return 0
        else
            return 1
        fi
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
        print_task "$MESSAGE" 1 true
    fi
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

    print_task "$MESSAGE" -1 false
    eval "$2"
    print_task "$MESSAGE" 0 true
}

get_config() {
    CONFIG=$(cat "$CONFIGFILE" 2>/dev/null)

    LOGFILE=$(echo "$CONFIG" | cut -f1 -d " ")
    [[ -z "$LOGFILE" ]] && LOGFILE="$HOME/setup-$(date +%Y-%m-%d_%Hh%Mm).log"

    STEP=$(echo "$CONFIG" | cut -f2 -d " ")
    [[ -z "$STEP" ]] && STEP=1
    [[ $STEP != *[[:digit:]]* ]] && STEP=1
}

execute_step() {
    local EXECUTIONSTEP="$1"

    for item in "${EXECUTIONSETUP[@]}"
    do
        if [[ $item == *","* ]]
        then
            IFS=',' read -ra tmpArray <<< "$item"
            tmpStep=${tmpArray[0]}
            tmpExecute=${tmpArray[1]}

            if (( EXECUTIONSTEP == tmpStep )) ; then
                if [ "$tmpExecute" = "true" ] ; then
                    print_padded_text "STEP $STEP" >> "$LOGFILE"
                    return 0
                else
                    return 1
                fi
            fi
        fi
    done
}

inform_user() {
    local COMMAND="/usr/bin/curl -s --form-string 'token=$PUSHOVER_TOKEN' --form-string 'user=$PUSHOVER_USER' --form-string 'priority=0' --form-string 'title=Domoticz' --form-string 'message=$1' https://api.pushover.net/1/messages.json > /dev/null 2>&1"
    run_cmd "$COMMAND"
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

tput civis

# start script for beginning when just downloaded
if [[ "$EXECUTIONFROM" == "Internet" ]]; then
    # check if argument has been provided
    if [[ $# -eq 0 ]]
    then
        echo "No password supplied"
        exit
    fi

    # check if script run by user pi
    if [ "$(whoami)" != "root" ]; then
        echo "Script startup from Internet must be run as user: root"
        exit
    fi

    # save script in home directory
    do_task "Save script to home directory" "wget -O $SCRIPTFILE https://raw.githubusercontent.com/irjdekker/Katello/master/setup.sh"
    do_task "Change permissions on script" "chmod 700 $SCRIPTFILE"
    do_task "Change script content" "sed -i 's/^EXECUTIONFROM=\"Internet\"/EXECUTIONFROM=\"Local\"/' $SCRIPTFILE"
    do_task "Save source file to home directory" "wget -O $ENCSOURCEFILE  https://raw.githubusercontent.com/irjdekker/Katello/master/source/source.sh.enc"
    do_task "Decrypt source file" "/usr/bin/openssl enc -aes-256-cbc -d -in $ENCSOURCEFILE -out $SOURCEFILE -pass pass:$1"
    do_task "Remove encrypted source file from home directory" "[ -f $ENCSOURCEFILE ] && rm -f $ENCSOURCEFILE || sleep 0.1"
    do_task "Change permissions on source file" "chmod 700 $SOURCEFILE"

    # source all script parameters
    if [ -f "$SOURCEFILE" ]; then
        source "$SOURCEFILE"
    else
        exit
    fi

    # Restart system to continue install with system account
    inform_user "Installation of setup script has finished"
fi

# Retrieve logfile and step in process
get_config

# test internet connection
do_function "Test internet connection" "do_test_internet"

# source all script parameters
if [ -f "$SOURCEFILE" ]; then
    source "$SOURCEFILE"
else
    inform_user "Step $STEP has failed: no sourcefile"
fi

# check if script run by system user
if [ "$(whoami)" != "$SYSTEM_USER" ]; then
    echo "Script startup from local must be run as user: $SYSTEM_USER"
    inform_user "Step $STEP has failed: Script startup from local must be run as user $SYSTEM_USER"
    final_step
fi

if (( STEP == 1 )) ; then
    if execute_step "$STEP"; then
        # Set locale
        do_task "Set locale" "localectl set-locale LC_CTYPE=en_US.utf8"

        # Install Chrony
        do_task "Install Chrony" "yum install chrony -y"
        
        # Enable Chrony
        do_task "Enable Chrony" "systemctl enable chronyd"
        
        # Source Chrony
        do_task "Source Chrony" "chronyc sources"
        
        # Enable NTP
        do_task "Enable NTP" "timedatectl set-ntp true"


    fi
fi
