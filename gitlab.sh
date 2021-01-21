#!/bin/bash
# shellcheck disable=SC2181
# shellcheck disable=SC1090

## The easiest way to get the script on your machine is:
## a) without specifying the password
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/gitlab.sh -o gitlab.sh 2>/dev/null && bash gitlab.sh && rm -f gitlab.sh
## wget -O gitlab.sh https://raw.githubusercontent.com/irjdekker/Katello/master/gitlab.sh 2>/dev/null && bash gitlab.sh && rm -f gitlab.sh
## b) with specifying the password
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/gitlab.sh 2>/dev/null | bash -s <password>
## wget -O - https://raw.githubusercontent.com/irjdekker/Katello/master/gitlab.sh 2>/dev/null | bash -s <password>

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

LOGFILE="$HOME/awx-install-$(date +%Y-%m-%d_%Hh%Mm).log"
IRed='\e[0;31m'
IGreen='\e[0;32m'
IYellow='\e[0;33m'
Reset='\e[0m'
COMMAND_DEBUG=true
SOURCEFILE="$HOME/source.sh"
ENCSOURCEFILE="$SOURCEFILE.enc"

## *************************************************************************************************** ##
##       _____   ____  _    _ _______ _____ _   _ ______  _____                                        ##
##      |  __ \ / __ \| |  | |__   __|_   _| \ | |  ____|/ ____|                                       ##
##      | |__) | |  | | |  | |  | |    | | |  \| | |__  | (___                                         ##
##      |  _  /| |  | | |  | |  | |    | | | . ` |  __|  \___ \                                        ##
##      | | \ \| |__| | |__| |  | |   _| |_| |\  | |____ ____) |                                       ##
##      |_|  \_\\____/ \____/   |_|  |_____|_| \_|______|_____/                                        ##
##                                                                                                     ##
## *************************************************************************************************** ##

do_download_configfile() {
    do_function_task "curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/source.sh.enc -o \"${ENCSOURCEFILE}\""
    do_function_task "/usr/bin/openssl enc -aes-256-cbc -md md5 -d -in \"${ENCSOURCEFILE}\" -out \"${SOURCEFILE}\" -pass pass:\"${PASSWORD}\""
    do_function_task "[ -f \"${ENCSOURCEFILE}\" ] && rm -f \"${ENCSOURCEFILE}\" || sleep 0.1"
    do_function_task "chmod 700 \"${SOURCEFILE}\""
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

do_install_gitlab() {
    do_function_task "mkdir -p /srv/gitlab"
    do_function_task "docker run --detach --hostname gitlab.tanix.nl --publish 8080:80 --name gitlab --restart always --env GITLAB_OMNIBUS_CONFIG=\"gitlab_rails['initial_root_password'] = '1234567890'\" --volume /srv/gitlab/config:/etc/gitlab --volume /srv/gitlab/logs:/var/log/gitlab --volume /srv/gitlab/data:/var/opt/gitlab gitlab/gitlab-ee:latest"
    # do_function_task "docker run --detach --hostname gitlab.tanix.nl --publish 8080:80 --name gitlab --restart always --volume /srv/gitlab/config:/etc/gitlab --volume /srv/gitlab/logs:/var/log/gitlab --volume /srv/gitlab/data:/var/opt/gitlab gitlab/gitlab-ee:latest"    
}

do_setup_letsencrypt() {
    do_function_task "mkdir -p /root/certificate"
    do_function_task "curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/certificate/cf-auth.sh -o /root/certificate/cf-auth.sh"
    do_function_task "curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/certificate/cf-clean.sh -o /root/certificate/cf-clean.sh"
    do_function_task "sed -i \"s/<CERT_API>/${CERT_API}/\" /root/certificate/cf-auth.sh"
    do_function_task "sed -i \"s/<CERT_EMAIL>/${CERT_EMAIL}/\" /root/certificate/cf-auth.sh"
    do_function_task "sed -i \"s/<CERT_API>/${CERT_API}/\" /root/certificate/cf-clean.sh"
    do_function_task "sed -i \"s/<CERT_EMAIL>/${CERT_EMAIL}/\" /root/certificate/cf-clean.sh"
    do_function_task "chmod 700 /root/certificate/*.sh"
    do_function_task "dnf install certbot python3-certbot-nginx -y"
    # do_function_task "/usr/bin/certbot certonly --test-cert --manual --preferred-challenges dns --manual-auth-hook /root/certificate/cf-auth.sh --manual-cleanup-hook /root/certificate/cf-clean.sh --rsa-key-size 2048 --renew-by-default --register-unsafely-without-email --agree-tos --non-interactive -d gitlab.tanix.nl"
    do_function_task "/usr/bin/certbot certonly --manual --preferred-challenges dns --manual-auth-hook /root/certificate/cf-auth.sh --manual-cleanup-hook /root/certificate/cf-clean.sh --rsa-key-size 2048 --renew-by-default --register-unsafely-without-email --agree-tos --non-interactive -d gitlab.tanix.nl"    
}

do_setup_nginx() {
    do_function_task "dnf install nginx -y"
    do_function_task "curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/gitlab.conf -o /etc/nginx/conf.d/gitlab.conf"
    do_function_task "nginx -t"
    do_function_task "systemctl restart nginx"
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

# Import variables
do_function "Import variables" "do_download_configfile"

# source all script parameters
if [ -f "$SOURCEFILE" ]; then
    source "$SOURCEFILE"
else
    echo "Variable file not available"
    exit 1
fi

## Setup locale
do_function "Setup locale" "do_setup_locale"

## Check hostname
do_function "Check hostname" "do_check_hostname"

## Setup chrony
do_function "Setup chrony" "do_setup_chrony"

## Setup NTP
do_function "Setup NTP" "do_setup_ntp"

## Disable firewalld
do_function "Disable firewalld" "do_disable_firewall"

## Disable SELinux
do_function "Disable SELinux" "do_disable_selinux"

## Update system
do_task "Update system" "yum update -y"

## Add repositories
do_function "Add repositories" "do_add_repositories"

## Install required packages
do_task "Install required packages" "dnf install python3 wget vim curl -y"

## Install and enable docker service
do_function "Install and enable docker service" "do_setup_docker"

## Install Gitlab container
do_function "Install Gitlab container" "do_install_gitlab"

## Correct Python version
do_task "Correct Python version" "alternatives --set python /usr/bin/python3"

## Install Certbot
do_function "Install Certbot" "do_setup_letsencrypt"

## Install Nginx
do_function "Install Nginx" "do_setup_nginx"

## Request container IP addresses
do_task "Request container IP addresses" "docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker ps -aq)"

## Install VMWare Tools
do_task "Install VMWare Tools" "yum install open-vm-tools -y"

## Install JQ
do_task "Install JQ" "yum install jq -y"

## Update system (again)
do_task "Update system" "yum update -y"

# Restore cursor
tput cvvis