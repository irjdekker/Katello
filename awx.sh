#!/bin/bash
# shellcheck disable=SC2181
# shellcheck disable=SC1090

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

do_install_docker_compose() {
    do_function_task "pip3 install --upgrade pip"
    do_function_task "pip3 install docker-compose"
}

do_clone_awx() {
    do_function_task "git clone -b 16.0.0 https://github.com/ansible/awx.git"
    do_function_task "git clone https://github.com/ansible/awx-logos.git"
}

do_update_inventory() {
    local SECRET_KEY
    SECRET_KEY=$(openssl rand -base64 30 | sed 's/[\\&*./+!]/\\&/g')

    do_function_task "sed -i 's/^.*host_port.*$/host_port=8080/g' /root/awx/installer/inventory"
    do_function_task "sed -i \"s/^\s*admin_password=password\s*$/admin_password=${ADMIN_PASSWORD}/g\" /root/awx/installer/inventory"
    do_function_task "sed -i 's/^.*create_preload_data.*$/create_preload_data=false/g' /root/awx/installer/inventory"
    do_function_task "sed -i \"s/^\s*secret_key=awxsecret\s*$/secret_key=${SECRET_KEY}/g\" /root/awx/installer/inventory"
    do_function_task "sed -i 's/^.*awx_official.*$/awx_official=true/g' /root/awx/installer/inventory"
    do_function_task "sed -i 's/^.*awx_alternate_dns_servers.*$/awx_alternate_dns_servers=\"10.10.5.1\"/g' /root/awx/installer/inventory"
    do_function_task "sed -i 's/^.*\(project_data_dir.*\)$/\1/g' /root/awx/installer/inventory"
}

do_install_playbook() {
    do_function_task "sed -i \"s|/usr/bin/awx-manage create_preload_data|sleep 600 \&\& exec /usr/bin/awx-manage create_preload_data'|g\" /root/awx/installer/roles/local_docker/tasks/compose.yml"
    do_function_task "ansible-playbook -i /root/awx/installer/inventory /root/awx/installer/install.yml -vv"
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
    do_function_task "/usr/bin/certbot certonly --test-cert --manual --preferred-challenges dns --manual-auth-hook /root/certificate/cf-auth.sh --manual-cleanup-hook /root/certificate/cf-clean.sh --rsa-key-size 2048 --renew-by-default --register-unsafely-without-email --agree-tos --non-interactive -d awx.tanix.nl"
}

do_setup_nginx() {
    do_function_task "dnf install nginx -y"
    do_function_task "curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/awx.conf -o /etc/nginx/conf.d/awx.conf"
    do_function_task "nginx -t"
    do_function_task "systemctl restart nginx"
}

do_configure_awx() {
    export TOWER_HOST=http://localhost:8080
    local EXPORT

    for((i=1;i<=15;++i)); do
        sleep 60
        EXPORT=$(TOWER_USERNAME=admin TOWER_PASSWORD="$ADMIN_PASSWORD" awx login -f human)
        if [[ "${EXPORT}" == *"export"* ]]; then
            RETURN="0"
            break
        else
            echo "Waiting for $i minutes on AWX installation" >> "${LOGFILE}" 2>&1
        fi
    done

    if [ "${RETURN}" = "1" ]; then
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "${EXPORT}"
    do_function_task "awx config"

    ## *************************************************************************************************** ##
    ## Create organization
    ## *************************************************************************************************** ##
    do_function_task "awx organizations create --name '${ORG_NAME}' --description '${ORG_NAME}' --max_hosts 100"

    local ORG_COUNT
    local ORGANIZATION_ID
    ORG_COUNT=$(awx organizations list --name "${ORG_NAME}" -f human --filter id | tail -n +3 | wc -l)
    if [ "${ORG_COUNT}" == "1" ]; then
        ORGANIZATION_ID=$(awx organizations list --name "${ORG_NAME}" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    ## *************************************************************************************************** ##
    ## Create team
    ## *************************************************************************************************** ##
    do_function_task "awx teams create --name Dekker --description Dekker --organization ${ORGANIZATION_ID}"

    local TEAM_COUNT
    local TEAM_ID
    TEAM_COUNT=$(awx teams list --name Dekker -f human --filter id | tail -n +3 | wc -l)
    if [ "${TEAM_COUNT}" == "1" ]; then
        TEAM_ID=$(awx teams list --name Dekker -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    ## *************************************************************************************************** ##
    ## Create user
    ## *************************************************************************************************** ##
    do_function_task "awx users create --username irjdekker --email ir.j.dekker@gmail.com --first_name Jeroen --last_name Dekker --password ${PASSWORD}"

    local USER_COUNT
    local USER_ID
    USER_COUNT=$(awx users list --username irjdekker -f human --filter id | tail -n +3 | wc -l)
    if [ "${USER_COUNT}" == "1" ]; then
        USER_ID=$(awx users list --username irjdekker -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx users grant --organization ${ORGANIZATION_ID} --role admin ${USER_ID}"
    do_function_task "awx users grant --team ${TEAM_ID} --role member ${USER_ID}"

    ## *************************************************************************************************** ##
    ## Create credentials
    ## *************************************************************************************************** ##
    local CRED_TYPE_COUNT
    local CRED_TYPE_ID
    CRED_TYPE_COUNT=$(awx credential_types get "Red Hat Satellite 6" -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED_TYPE_COUNT}" == "1" ]; then
        CRED_TYPE_ID=$(awx credential_types get "Red Hat Satellite 6" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx credentials create --name katello_inventory --organization ${ORGANIZATION_ID} --credential_type ${CRED_TYPE_ID} --inputs \"{host: 'https://katello.tanix.nl', username: '${INV_USER}', password: '${INV_PASSWORD}'}\""

    local CRED_TYPE_COUNT
    local CRED_TYPE_ID
    CRED_TYPE_COUNT=$(awx credential_types get "Source Control" -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED_TYPE_COUNT}" == "1" ]; then
        CRED_TYPE_ID=$(awx credential_types get "Source Control" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx credentials create --name gitlab --organization ${ORGANIZATION_ID} --credential_type ${CRED_TYPE_ID} --inputs \"{username: 'root', password: '1234567890'}\""

    local CRED_TYPE_COUNT
    local CRED_TYPE_ID
    CRED_TYPE_COUNT=$(awx credential_types get "Vault" -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED_TYPE_COUNT}" == "1" ]; then
        CRED_TYPE_ID=$(awx credential_types get "Vault" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx credentials create --name vault --organization ${ORGANIZATION_ID} --credential_type ${CRED_TYPE_ID} --inputs \"{vault_password: '1234567890'}\""

    local CRED_TYPE_COUNT
    local CRED_TYPE_ID
    CRED_TYPE_COUNT=$(awx credential_types get "Machine" -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED_TYPE_COUNT}" == "1" ]; then
        CRED_TYPE_ID=$(awx credential_types get "Machine" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx credentials create --name root --organization ${ORGANIZATION_ID} --credential_type ${CRED_TYPE_ID} --inputs \"{username: 'root', ssh_key_data: '********'}\""

    ## *************************************************************************************************** ##
    ## Create inventories
    ## *************************************************************************************************** ##
    do_function_task "awx inventory create --name \"Empty inventory\" --description \"Empty inventory\" --organization ${ORGANIZATION_ID}"
    do_function_task "awx inventory create --name \"Katello inventory\" --description \"Katello inventory\" --organization ${ORGANIZATION_ID}"

    local CRED_COUNT
    local CRED_ID
    CRED_COUNT=$(awx credentials get katello_inventory -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED_COUNT}" == "1" ]; then
        CRED_ID=$(awx credentials get katello_inventory -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    local INV_COUNT
    local INV_ID
    INV_COUNT=$(awx inventory get "Katello inventory" -f human --filter id | tail -n +3 | wc -l)
    if [ "${INV_COUNT}" == "1" ]; then
        INV_ID=$(awx inventory get "Katello inventory" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx inventory_sources create --name Katello --description Katello --source satellite6 --credential ${CRED_ID} --update_on_launch true --overwrite true --inventory ${INV_ID}"

    local INV_SRC_COUNT
    local INV_SRC_ID
    INV_SRC_COUNT=$(awx inventory_sources get Katello -f human --filter id | tail -n +3 | wc -l)
    if [ "${INV_SRC_COUNT}" == "1" ]; then
        INV_SRC_ID=$(awx inventory_sources get Katello -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx inventory_sources update ${INV_SRC_ID}"

    ## *************************************************************************************************** ##
    ## Create projects
    ## *************************************************************************************************** ##
    local CRED_COUNT
    local CRED_ID
    CRED_COUNT=$(awx credentials get gitlab -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED_COUNT}" == "1" ]; then
        CRED_ID=$(awx credentials get gitlab -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx projects create --name \"VM deployment\" --description \"VM deployment\" --organization ${ORGANIZATION_ID} --scm_type git --scm_url http://gitlab.tanix.nl/root/iaas.git --credential ${CRED_ID} --scm_update_on_launch true"

    ## *************************************************************************************************** ##
    ## Create job templates
    ## *************************************************************************************************** ##
    local PROJ_COUNT
    local PROJ_ID
    PROJ_COUNT=$(awx projects get "VM deployment" -f human --filter id | tail -n +3 | wc -l)
    if [ "${PROJ_COUNT}" == "1" ]; then
        PROJ_ID=$(awx projects get "VM deployment" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "curl -u admin:${ADMIN_PASSWORD} -H 'Content-Type:application/json' -H 'Accept:application/json' -k https://awx.tanix.nl/api/v2/projects/${JOB_ID}/update/ -X POST"
    sleep 60

    local INV_COUNT
    local INV_ID
    INV_COUNT=$(awx inventory get "Empty inventory" -f human --filter id | tail -n +3 | wc -l)
    if [ "${INV_COUNT}" == "1" ]; then
        INV_ID=$(awx inventory get "Empty inventory" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    VARIABLES='{"template_sec_env": "NS", "template_vault_env": "PRD"}'
    do_function_task "awx job_templates create --name \"Deploy Server (VM)\" --description \"Deploy Server (VM)\" --organization ${ORGANIZATION_ID} --project ${PROJ_ID} --playbook install-vm-v2.yml --job_type run --inventory ${INV_ID} --allow_simultaneous true"
    do_function_task "awx job_templates create --name \"Configure Server (VM)\" --description \"Configure Server (VM)\" --organization ${ORGANIZATION_ID} --project ${PROJ_ID} --playbook sat6_postinstall.yml --job_type run --inventory ${INV_ID} --allow_simultaneous true"
    do_function_task "awx workflow_job_templates create --name \"Install Server (VM)\" --description \"Install Server (VM)\" --organization ${ORGANIZATION_ID} --inventory ${INV_ID} --allow_simultaneous true --survey_enabled true --extra_vars '${VARIABLES}'"

    local TMPL1_COUNT
    local TMPL1_ID
    TMPL1_COUNT=$(awx job_templates get "Deploy Server (VM)" -f human --filter id | tail -n +3 | wc -l)
    if [ "${TMPL1_COUNT}" == "1" ]; then
        TMPL1_ID=$(awx job_templates get "Deploy Server (VM)" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    local TMPL2_COUNT
    local TMPL2_ID
    TMPL2_COUNT=$(awx job_templates get "Configure Server (VM)" -f human --filter id | tail -n +3 | wc -l)
    if [ "${TMPL2_COUNT}" == "1" ]; then
        TMPL2_ID=$(awx job_templates get "Configure Server (VM)" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    local TMPL3_COUNT
    local TMPL3_ID
    TMPL3_COUNT=$(awx workflow_job_templates get "Install Server (VM)" -f human --filter id | tail -n +3 | wc -l)
    if [ "${TMPL3_COUNT}" == "1" ]; then
        TMPL3_ID=$(awx workflow_job_templates get "Install Server (VM)" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    local CRED1_COUNT
    local CRED1_ID
    CRED1_COUNT=$(awx credentials get vault -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED1_COUNT}" == "1" ]; then
        CRED1_ID=$(awx credentials get vault -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    local CRED2_COUNT
    local CRED2_ID
    CRED2_COUNT=$(awx credentials get root -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED2_COUNT}" == "1" ]; then
        CRED2_ID=$(awx credentials get root -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx job_templates associate --credential ${CRED1_ID} ${TMPL1_ID}"
    do_function_task "awx job_templates associate --credential ${CRED1_ID} ${TMPL2_ID}"
    do_function_task "awx job_templates associate --credential ${CRED2_ID} ${TMPL1_ID}"
    do_function_task "awx job_templates associate --credential ${CRED2_ID} ${TMPL2_ID}"

    SURVEY='{"name":"","description":"","spec":[{"question_name":"Hostname","question_description":"FQDN of the system to deploy","required":true,"type":"text","variable":"survey_hostname","min":0,"max":1024,"default":"","choices":"","new_question":false},{"question_name":"Select the OS Version","question_description":"Select the OS Version","required":true,"type":"multiplechoice","variable":"survey_os_version","min":0,"max":1024,"default":"CentOS 8","choices":"CentOS 7\nCentOS 8","new_question":false},{"question_name":"Lifecycle environment","question_description":"Select the lifecycle environment","required":true,"type":"multiplechoice","variable":"survey_lifecycle","min":0,"max":1024,"default":"production","choices":"development\ntest\nacceptance\nproduction","new_question":false},{"question_name":"Location","question_description":"Select the location","required":true,"type":"multiplechoice","variable":"survey_location","min":0,"max":1024,"default":"home","choices":"home","new_question":false},{"question_name":"Role selection","question_description":"Enter the system_roles you want to select","required":true,"type":"multiplechoice","variable":"survey_role","min":0,"max":1024,"default":"none","choices":"web\nsmtp\ntr_cadappl\nnone","new_question":false}]}'
    do_function_task "curl -u admin:${ADMIN_PASSWORD} -H 'Content-Type:application/json' -H 'Accept:application/json' -k https://awx.tanix.nl/api/v2/job_templates/${TMPL3_ID}/survey_spec/ -X POST -d '${SURVEY}'"

    ## *************************************************************************************************** ##
    ## Create job templates nodes
    ## *************************************************************************************************** ##
    do_function_task "awx workflow_job_template_nodes create --workflow_job_template {TMPL3_ID} --unified_job_template {TMPL1_ID} --identifier \"Step 1\""
    do_function_task "awx workflow_job_template_nodes create --workflow_job_template {TMPL3_ID} --unified_job_template {TMPL2_ID} --identifier \"Step 2\""

    local NOD1_COUNT
    local NOD1_ID
    NOD1_COUNT=$(awx workflow_job_template_nodes list --identifier "Step 1" -f human --filter id | tail -n +3 | wc -l)
    if [ "${NOD1_COUNT}" == "1" ]; then
        NOD1_ID=$(awx workflow_job_template_nodes list --identifier "Step 1" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    local NOD2_COUNT
    local NOD2_ID
    NOD2_COUNT=$(awx workflow_job_template_nodes list --identifier "Step 2" -f human --filter id | tail -n +3 | wc -l)
    if [ "${NOD2_COUNT}" == "1" ]; then
        NOD2_ID=$(awx workflow_job_template_nodes list --identifier "Step 2" -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "curl -u admin:${ADMIN_PASSWORD} -H 'Content-Type:application/json' -H 'Accept:application/json' -k https://awx.tanix.nl/api/v2/workflow_job_template_nodes/${NOD1_ID}/success_nodes/ -X POST -d '{\"id\":${NOD2_ID}}'"
}

do_install_hammer() {
    do_function_task "docker exec awx_task yum -y localinstall https://yum.theforeman.org/releases/2.3/el8/x86_64/foreman-release.rpm"
    do_function_task "docker exec awx_task yum -y localinstall https://fedorapeople.org/groups/katello/releases/yum/3.18/katello/el8/x86_64/katello-repos-latest.rpm"
    do_function_task "docker exec awx_task yum -y localinstall https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm"
    do_function_task "docker exec awx_task yum -y install rubygem-hammer_cli_katello"
    do_function_task "docker exec awx_task mkdir -p /var/lib/awx/.hammer/cli.modules.d"
    do_function_task "docker exec awx_task chmod 700 /var/lib/awx/.hammer"
    do_function_task "docker exec awx_task chmod 700 /var/lib/awx/.hammer/cli.modules.d"
    do_function_task "docker exec awx_task /bin/bash -c \"cat /etc/hammer/cli.modules.d/foreman.yml | grep -e ':foreman' -e ':host' -e ':username' -e ':password' -e ':refresh_cache' -e ':request_timeout' | sed 's/#//g' > /var/lib/awx/.hammer/cli.modules.d/foreman.yml\""
    do_function_task "docker exec awx_task chmod 600 /var/lib/awx/.hammer/cli.modules.d/foreman.yml"
    do_function_task "docker exec awx_task sed -i 's/localhost/katello.tanix.nl/g' /var/lib/awx/.hammer/cli.modules.d/foreman.yml"
    do_function_task "docker exec awx_task sed -i 's/example/${ADMIN_PASSWORD}/g' /var/lib/awx/.hammer/cli.modules.d/foreman.yml"
    do_function_task "docker exec awx_task sed -i 's/seconds//g' /var/lib/awx/.hammer/cli.modules.d/foreman.yml"
    do_function_task "docker exec awx_task hammer --fetch-ca-cert https://katello.tanix.nl/"
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
do_function "Update inventory file" "do_update_inventory"

## Install AWX
do_function "Install AWX" "do_install_playbook"

## Install AWX CLI
do_task "Install AWX CLI" "pip3 install awxkit"

## Install Certbot
do_function "Install Certbot" "do_setup_letsencrypt"

## Install Nginx
do_function "Install Nginx" "do_setup_nginx"

## Install VMWare Tools
do_task "Install VMWare Tools" "yum install open-vm-tools -y"

## Install JQ
do_task "Install JQ" "yum install jq -y"

## Update system (again)
do_task "Update system" "yum update -y"

## Configure AWX
do_function "Configure AWX" "do_configure_awx"

## Install Hammer CLI
do_function "Install Hammer CLI" "do_install_hammer"

# Restore cursor
tput cvvis