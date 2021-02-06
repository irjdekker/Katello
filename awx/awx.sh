#!/bin/bash
# shellcheck disable=SC2181
# shellcheck disable=SC1090

## The easiest way to get the script on your machine is:
## a) without specifying the password
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/awx.sh -o awx.sh 2>/dev/null && bash awx.sh && rm -f awx.sh
## b) with specifying the password
## curl -s https://raw.githubusercontent.com/irjdekker/Katello/master/awx.sh 2>/dev/null | bash -s <password>

## *************************************************************************************************** ##
##      __      __     _____  _____          ____  _      ______  _____                                ##
##      \ \    / /\   |  __ \|_   _|   /\   |  _ \| |    |  ____|/ ____|                               ##
##       \ \  / /  \  | |__) | | |    /  \  | |_) | |    | |__  | (___                                 ##
##        \ \/ / /\ \ |  _  /  | |   / /\ \ |  _ <| |    |  __|  \___ \                                ##
##         \  / ____ \| | \ \ _| |_ / ____ \| |_) | |____| |____ ____) |                               ##
##          \/_/    \_\_|  \_\_____/_/    \_\____/|______|______|_____/                                ##
##                                                                                                     ##
## *************************************************************************************************** ##
## The following variables are defined below

SCRIPT_NAME="awx"
COMMAND_DEBUG=true

## *************************************************************************************************** ##
##       _____   ____  _    _ _______ _____ _   _ ______  _____                                        ##
##      |  __ \ / __ \| |  | |__   __|_   _| \ | |  ____|/ ____|                                       ##
##      | |__) | |  | | |  | |  | |    | | |  \| | |__  | (___                                         ##
##      |  _  /| |  | | |  | |  | |    | | | . ` |  __|  \___ \                                        ##
##      | | \ \| |__| | |__| |  | |   _| |_| |\  | |____ ____) |                                       ##
##      |_|  \_\\____/ \____/   |_|  |_____|_| \_|______|_____/                                        ##
##                                                                                                     ##
## *************************************************************************************************** ##

do_create_files() {
    cat <<EOF > /tmp/cred.yml
---
username: root
ssh_key_data: |
$(awk '{printf "      %s\n", $0}' < /tmp/key)
EOF

    cat <<EOF > /tmp/awx.conf
server {
   listen 80;
   server_name awx.tanix.nl;
   add_header Strict-Transport-Security max-age=2592000;
   rewrite ^ https://$server_name$request_uri? permanent;
}

server {
   listen 443 ssl http2;
   server_name awx.tanix.nl;
   
   access_log /var/log/nginx/awx.access.log;
   error_log /var/log/nginx/awx.error.log;

   ssl on;
   ssl_certificate /etc/letsencrypt/live/awx.tanix.nl/fullchain.pem;
   ssl_certificate_key /etc/letsencrypt/live/awx.tanix.nl/privkey.pem;
   ssl_session_timeout 5m;
   ssl_ciphers EECDH+CHACHA20:EECDH+AES128:RSA+AES128:EECDH+AES256:RSA+AES256:EECDH+3DES:RSA+3DES:!MD5;
   ssl_protocols TLSv1.2;
   ssl_prefer_server_ciphers on;
   
   location / {
      proxy_http_version 1.1;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto \$scheme;
      proxy_set_header Upgrade \$http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_pass http://localhost:8080/;
   }
}
EOF
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
    do_function_task "/bin/cp -f /tmp/awx.conf /etc/nginx/conf.d/awx.conf"
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
    do_function_task "awx organizations create --name \"${ORG_NAME}\" --description \"${ORG_NAME}\" --max_hosts 100"

    ## *************************************************************************************************** ##
    ## Create team
    ## *************************************************************************************************** ##
    do_function_task "awx teams create --name \"Dekker\" --description \"Dekker\" --organization \"${ORG_NAME}\""

    ## *************************************************************************************************** ##
    ## Create user
    ## *************************************************************************************************** ##
    do_function_task "awx users create --username irjdekker --email ir.j.dekker@gmail.com --first_name Jeroen --last_name Dekker --password \"${PASSWORD}\""
    do_function_task "awx users grant --organization \"${ORG_NAME}\" --role admin irjdekker"
    do_function_task "awx users grant --team \"Dekker\" --role member irjdekker"

    ## *************************************************************************************************** ##
    ## Create credentials
    ## *************************************************************************************************** ##
    do_function_task "awx credentials create --name katello_inventory --organization \"${ORG_NAME}\" --credential_type \"Red Hat Satellite 6\" --inputs \"{host: 'https://katello.tanix.nl', username: '${INV_USER}', password: '${INV_PASSWORD}'}\""
    do_function_task "awx credentials create --name gitlab --organization \"${ORG_NAME}\" --credential_type \"Source Control\" --inputs \"{username: 'root', password: '1234567890'}\""
    do_function_task "awx credentials create --name vault --organization \"${ORG_NAME}\" --credential_type \"Vault\" --inputs \"{vault_password: '1234567890'}\""
    do_function_task "awx credentials create --name root --organization \"${ORG_NAME}\" --credential_type \"Machine\" --inputs \"@/tmp/cred.yml\""

    ## *************************************************************************************************** ##
    ## Create inventories
    ## *************************************************************************************************** ##
    do_function_task "awx inventory create --name \"Empty inventory\" --description \"Empty inventory\" --organization \"${ORG_NAME}\""
    do_function_task "awx inventory create --name \"Katello inventory\" --description \"Katello inventory\" --organization \"${ORG_NAME}\""

    local CRED_COUNT
    local CRED_ID
    CRED_COUNT=$(awx credentials get katello_inventory -f human --filter id | tail -n +3 | wc -l)
    if [ "${CRED_COUNT}" == "1" ]; then
        CRED_ID=$(awx credentials get katello_inventory -f human --filter id | tail -n +3 | xargs)
    else
        print_task "${MESSAGE}" 1 true
        exit 1
    fi

    do_function_task "awx inventory_sources create --name Katello --description Katello --source satellite6 --credential ${CRED_ID} --update_on_launch true --overwrite true --inventory \"Katello inventory\""
    do_function_task "awx inventory_sources update \"Katello\""

    ## *************************************************************************************************** ##
    ## Create projects
    ## *************************************************************************************************** ##
    do_function_task "awx projects create --name \"VM deployment\" --description \"VM deployment\" --organization \"${ORG_NAME}\" --scm_type git --scm_url http://gitlab.tanix.nl/root/iaas.git --credential gitlab --scm_update_on_launch true"

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
    VARIABLES='{"template_sec_env": "NS", "template_vault_env": "PRD"}'
    do_function_task "awx job_templates create --name \"Deploy Server (VM)\" --description \"Deploy Server (VM)\" --organization \"${ORG_NAME}\" --project \"VM deployment\" --playbook install-vm-v2.yml --job_type run --inventory \"Empty inventory\" --allow_simultaneous true"
    do_function_task "awx job_templates create --name \"Configure Server (VM)\" --description \"Configure Server (VM)\" --organization \"${ORG_NAME}\" --project \"VM deployment\" --playbook sat6_postinstall.yml --job_type run --inventory \"Empty inventory\" --allow_simultaneous true"
    do_function_task "awx workflow_job_templates create --name \"Install Server (VM)\" --description \"Install Server (VM)\" --organization \"${ORG_NAME}\" --inventory \"Empty inventory\" --allow_simultaneous true --survey_enabled true --ask_variables_on_launch false --ask_inventory_on_launch false --ask_scm_branch_on_launch false --ask_limit_on_launch false --scm_branch \"\" --limit \"\" --extra_vars '${VARIABLES}'"

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

    do_function_task "awx job_templates associate --credential vault ${TMPL1_ID}"
    do_function_task "awx job_templates associate --credential vault ${TMPL2_ID}"
    do_function_task "awx job_templates associate --credential root ${TMPL1_ID}"
    do_function_task "awx job_templates associate --credential root ${TMPL2_ID}"

    SURVEY='{"name":"","description":"","spec":[{"question_name":"Hostname","question_description":"FQDN of the system to deploy","required":true,"type":"text","variable":"survey_hostname","min":0,"max":1024,"default":"","choices":"","new_question":false},{"question_name":"Select the OS Version","question_description":"Select the OS Version","required":true,"type":"multiplechoice","variable":"survey_os_version","min":0,"max":1024,"default":"CentOS 8","choices":"CentOS 7\nCentOS 8","new_question":false},{"question_name":"Lifecycle environment","question_description":"Select the lifecycle environment","required":true,"type":"multiplechoice","variable":"survey_lifecycle","min":0,"max":1024,"default":"production","choices":"development\ntest\nacceptance\nproduction","new_question":false},{"question_name":"Location","question_description":"Select the location","required":true,"type":"multiplechoice","variable":"survey_location","min":0,"max":1024,"default":"home","choices":"home","new_question":false},{"question_name":"Role selection","question_description":"Enter the system_roles you want to select","required":true,"type":"multiplechoice","variable":"survey_role","min":0,"max":1024,"default":"none","choices":"web\nsmtp\ntr_cadappl\nnone","new_question":false}]}'
    do_function_task "curl -u admin:${ADMIN_PASSWORD} -H 'Content-Type:application/json' -H 'Accept:application/json' -k https://awx.tanix.nl/api/v2/workflow_job_templates/${TMPL3_ID}/survey_spec/ -X POST -d '${SURVEY}'"

    ## *************************************************************************************************** ##
    ## Create job templates nodes
    ## *************************************************************************************************** ##
    do_function_task "awx workflow_job_template_nodes create --workflow_job_template ${TMPL3_ID} --unified_job_template ${TMPL1_ID} --identifier \"Step 1\""
    do_function_task "awx workflow_job_template_nodes create --workflow_job_template ${TMPL3_ID} --unified_job_template ${TMPL2_ID} --identifier \"Step 2\""

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

do_setup_bashrc() {
    do_function_task "echo \"export TOWER_HOST=http://localhost:8080\" | tee -a /root/.bashrc > /dev/null"
    do_function_task "echo \"export TOWER_USERNAME=admin\" | tee -a /root/.bashrc > /dev/null"
    do_function_task "echo \"export TOWER_PASSWORD=$ADMIN_PASSWORD\" | tee -a /root/.bashrc > /dev/null"
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

## Create required files
do_function "Create required files" "do_create_files"

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

## Clone IAAS repository
do_task "Clone IAAS repository" "git clone http://gitlab.tanix.nl/root/iaas.git ~/iaas"

## Setup .bashrc
do_function "Setup .bashrc" "do_setup_bashrc"

# Restore cursor
tput cvvis