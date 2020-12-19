#!/bin/bash
## The easiest way to get the script on your machine is:
## wget -O - https://raw.githubusercontent.com/irjdekker/Katello/master/katello.sh 2>/dev/null | bash -s <password>

## Exit when any command fails
# set -e

## Keep track of the last executed command
# trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
## Echo an error message before exiting
# trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT

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

OSSETUP=('7.x,http://mirror.1000mbps.com/centos/7/,os/x86_64/,extras/x86_64/,updates/x86_64/,configmanagement/x86_64/ansible-29/' \
'7.9,http://mirror.1000mbps.com/centos-vault/7.9.2009/,os/x86_64/,extras/x86_64/,updates/x86_64/,configmanagement/x86_64/ansible-29/' \
'7.8,http://mirror.1000mbps.com/centos-vault/7.8.2003/,os/x86_64/,extras/x86_64/,updates/x86_64/,configmanagement/x86_64/ansible-29/' \
'7.7,http://mirror.1000mbps.com/centos-vault/7.7.1908/,os/x86_64/,extras/x86_64/,updates/x86_64/,configmanagement/x86_64/ansible-29/' \
'7.6,http://mirror.1000mbps.com/centos-vault/7.6.1810/,os/x86_64/,extras/x86_64/,updates/x86_64/,configmanagement/x86_64/ansible27/')
LOGFILE="$HOME/katello-install-$(date +%Y-%m-%d_%Hh%Mm).log"
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

do_setup_firewall() {
    do_function_task "firewall-cmd --add-port={53,80,443,5647,9090}/tcp --permanent"
    do_function_task "firewall-cmd --add-port={67-69,53}/udp --permanent"
    do_function_task "firewall-cmd --reload"
    do_function_task "firewall-cmd --list-all"
}

do_clean_disks() {
    do_function_task "lvremove -f /dev/vg_pulp/lv_pulp"
    do_function_task "vgremove -f vg_pulp"
    do_function_task "pvremove -f /dev/sdb"
}

do_setup_disks() {
    do_function_task "pvcreate /dev/sdb"
    do_function_task "vgcreate vg_pulp /dev/sdb"
    do_function_task "lvcreate -y -l 100%FREE -n lv_pulp vg_pulp"
    do_function_task "mkfs.xfs -f /dev/mapper/vg_pulp-lv_pulp"
    do_function_task "mkdir /var/lib/pulp"
    do_function_task "mount /dev/mapper/vg_pulp-lv_pulp /var/lib/pulp/"
    do_function_task "echo '/dev/mapper/vg_pulp-lv_pulp /var/lib/pulp/ xfs defaults 0 0' >> /etc/fstab"
    do_function_task "tail -n1 /etc/fstab "
    do_function_task "restorecon -Rv /var/lib/pulp/"
    do_function_task "df -hP /var/lib/pulp/"
}

do_add_repositories() {
    do_function_task "yum -y localinstall https://yum.theforeman.org/releases/2.2/el7/x86_64/foreman-release.rpm"
    do_function_task "yum -y localinstall https://fedorapeople.org/groups/katello/releases/yum/3.17/katello/el7/x86_64/katello-repos-latest.rpm"
    do_function_task "sed -i \"s/@PULP_ENABLED@/1/\" /etc/yum.repos.d/katello.repo"
    do_function_task "yum -y localinstall https://yum.puppet.com/puppet6-release-el-7.noarch.rpm"
    do_function_task "yum -y install epel-release centos-release-scl-rh"
}

do_config_katello() {
    do_function_task "cd /etc/foreman-installer/scenarios.d/"
    do_function_task "mv /etc/foreman-installer/scenarios.d/katello-answers.yaml /etc/foreman-installer/scenarios.d/katello-answers.yaml.orig"
    do_function_task "wget -P /etc/foreman-installer/scenarios.d/ https://raw.githubusercontent.com/irjdekker/Katello/master/katello-answers.yaml"
    do_function_task "chown root:root /etc/foreman-installer/scenarios.d/katello-answers.yaml"
    do_function_task "chmod 600 /etc/foreman-installer/scenarios.d/katello-answers.yaml"
}

do_install_katello() {
    local PASSWORD
    PASSWORD="$1"
    do_function_task "foreman-installer --scenario katello --foreman-initial-admin-username admin --foreman-initial-admin-password \"${PASSWORD}\""
    do_function_task "foreman-maintain service status"
}

do_compute_resource() {
    do_function_task "hammer compute-resource create --organization-id 1 --location-id 2 --name \"Tanix vCenter\" --provider \"Vmware\" --server \"vcenter.tanix.nl\" --user \"administrator@tanix.local\" --password \"${PASSWORD}\" --datacenter \"Datacenter\" --caching-enabled 1 --set-console-password 1"
    do_function_task "curl -u admin:${PASSWORD} -H 'Content-Type:application/json' -H 'Accept:application/json' -k https://katello.tanix.nl/api/compute_resources/1-Tanix%20vCenter/refresh_cache -X PUT"
}

do_compute_profiles() {
    local cluster
    cluster=$(hammer --no-headers compute-resource clusters --organization-id 1 --location-id 2 --name "Tanix vCenter" --fields Id | awk '{$1=$1};1')
    local network_id
    network_id=$(hammer --no-headers compute-resource networks --organization-id 1 --location-id 2 --name "Tanix vCenter" --fields Id,Name | grep "tanix-5" | cut -d '|' -f 1 | awk '{$1=$1};1')

    do_function_task "hammer compute-profile values create --organization-id 1 --location-id 2 --compute-profile \"1-Small\" --compute-resource \"Tanix vCenter\" --compute-attributes cpus=1,corespersocket=1,memory_mb=2048,firmware=automatic,cluster=${cluster},resource_pool=Resources,path=\"/Datacenters/Datacenter/vm\",guest_id=centos7_64Guest,hardware_version=Default,memoryHotAddEnabled=1,cpuHotAddEnabled=1,add_cdrom=0,boot_order=[disk],scsi_controller_type=VirtualLsiLogicController --volume name=\"Hard disk\",mode=persistent,datastore=\"Datastore Non-SSD\",size_gb=30,thin=true --interface compute_type=VirtualVmxnet3,compute_network=${network_id}"
    do_function_task "hammer compute-profile values create --organization-id 1 --location-id 2 --compute-profile \"2-Medium\" --compute-resource \"Tanix vCenter\" --compute-attributes cpus=2,corespersocket=1,memory_mb=2048,firmware=automatic,cluster=${cluster},resource_pool=Resources,path=\"/Datacenters/Datacenter/vm\",guest_id=centos7_64Guest,hardware_version=Default,memoryHotAddEnabled=1,cpuHotAddEnabled=1,add_cdrom=0,boot_order=[disk],scsi_controller_type=VirtualLsiLogicController --volume name=\"Hard disk\",mode=persistent,datastore=\"Datastore Non-SSD\",size_gb=30,thin=true --interface compute_type=VirtualVmxnet3,compute_network=${network_id}"
    do_function_task "hammer compute-profile values create --organization-id 1 --location-id 2 --compute-profile \"3-Large\" --compute-resource \"Tanix vCenter\" --compute-attributes cpus=2,corespersocket=1,memory_mb=4096,firmware=automatic,cluster=${cluster},resource_pool=Resources,path=\"/Datacenters/Datacenter/vm\",guest_id=centos7_64Guest,hardware_version=Default,memoryHotAddEnabled=1,cpuHotAddEnabled=1,add_cdrom=0,boot_order=[disk],scsi_controller_type=VirtualLsiLogicController --volume name=\"Hard disk\",mode=persistent,datastore=\"Datastore Non-SSD\",size_gb=30,thin=true --interface compute_type=VirtualVmxnet3,compute_network=${network_id}"
}

do_create_subnet() {
    local domain_id
    domain_id=$(hammer --no-headers domain list --organization-id 1 --location-id 2 --fields Id | awk '{$1=$1};1')

    do_function_task "hammer subnet create --organization-id 1 --location-id 2 --domain-ids \"${domain_id}\" --name \"tanix-5\" --network-type \"IPv4\" --network \"10.10.5.0\" --prefix 24 --gateway \"10.10.5.1\" --dns-primary \"10.10.5.1\" --boot-mode \"Static\""
}

do_centos7_credential() {
    do_function_task "mkdir -p /etc/pki/rpm-gpg/import"
    do_function_task "cd /etc/pki/rpm-gpg/import/"
    do_function_task "wget -P /etc/pki/rpm-gpg/import/ http://mirror.1000mbps.com/centos/RPM-GPG-KEY-CentOS-7"
    do_function_task "hammer gpg create --organization-id 1 --key \"RPM-GPG-KEY-CentOS-7\" --name \"RPM-GPG-KEY-CentOS-7\""    
    do_function_task "wget -P /etc/pki/rpm-gpg/import/ http://mirror.1000mbps.com/centos/RPM-GPG-KEY-CentOS-Official"
    do_function_task "hammer gpg create --organization-id 1 --key \"RPM-GPG-KEY-CentOS-Official\" --name \"RPM-GPG-KEY-CentOS-8\""
    do_function_task "wget -P /etc/pki/rpm-gpg/import/ https://yum.theforeman.org/releases/2.2/RPM-GPG-KEY-foreman"
    do_function_task "hammer gpg create --organization-id 1 --key \"RPM-GPG-KEY-foreman\" --name \"RPM-GPG-KEY-foreman\""
}

do_lcm_setup() {
    do_function_task "hammer lifecycle-environment create --organization-id 1 --name \"Development\" --label \"Development\" --prior \"Library\""
    do_function_task "hammer lifecycle-environment create --organization-id 1 --name \"Test\" --label \"Test\" --prior \"Development\""
    do_function_task "hammer lifecycle-environment create --organization-id 1 --name \"Acceptance\" --label \"Acceptance\" --prior \"Test\""
    do_function_task "hammer lifecycle-environment create --organization-id 1 --name \"Production\" --label \"Production\" --prior \"Acceptance\""
}

do_populate_katello_client() {
    local SYNC_TIME
    SYNC_TIME=$(date --date "1970-01-01 02:00:00 $(shuf -n1 -i0-10800) sec" '+%T')

    ## Create Katello client product
    do_function_task "hammer product create --organization-id 1 --name \"Katello Client 7\""

    ## Create Katello client repositories
    do_function_task "hammer repository create --organization-id 1 --product \"Katello Client 7\" --name \"Katello Client 7\" --label \"Katello_Client_7\" --content-type \"yum\" --download-policy \"immediate\" --gpg-key \"RPM-GPG-KEY-foreman\" --url \"https://yum.theforeman.org/client/2.2/el7/x86_64/\" --mirror-on-sync \"no\""

    ## Create Katello client synchronization plan
    do_function_task "hammer sync-plan create --organization-id 1 --name \"Daily Sync Katello Client 7\" --interval daily --enabled true --sync-date \"2020-01-01 ${SYNC_TIME}\""
    do_function_task "hammer product set-sync-plan --organization-id 1 --name \"Katello Client 7\" --sync-plan \"Daily Sync Katello Client 7\""

    ## Synchronize Katello client repositories
    do_function_task_retry "hammer repository synchronize --organization-id 1 --product \"Katello Client 7\" --name \"Katello Client 7\"" "5"
}

do_populate_katello() {
    local OS_VERSION
    OS_VERSION="$1"
    local OS_NICE
    OS_NICE=${OS_VERSION//[^[:alnum:]-]/_}
    local SYNC_TIME
    SYNC_TIME=$(date --date "1970-01-01 02:00:00 $(shuf -n1 -i0-10800) sec" '+%T')

    ## Create Katello product
    do_function_task "hammer product create --organization-id 1 --name \"CentOS ${OS_VERSION} Linux x86_64\""

    ## Create Katello repositories
    for item in "${OSSETUP[@]}"
    do
        if [[ "${item}" == *","* ]]
        then
            IFS=',' read -ra tmpArray <<< "${item}"
            tmpOS=${tmpArray[0]}
            tmpBaseUrl=${tmpArray[1]}
            tmpBaseOS=${tmpArray[2]}
            tmpBaseExtras=${tmpArray[3]}
            tmpBaseUpdates=${tmpArray[4]}
            tmpBaseAnsible=${tmpArray[5]}

            if [[ "${OS_VERSION}" == "${tmpOS}" ]] ; then
                do_function_task "hammer repository create --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} OS x86_64\" --label \"CentOS_${OS_NICE}_OS_x86_64\" --content-type \"yum\" --download-policy \"immediate\" --gpg-key \"RPM-GPG-KEY-CentOS-7\" --url \"${tmpBaseUrl}${tmpBaseOS}\" --mirror-on-sync \"no\""
                do_function_task "hammer repository create --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} Extras x86_64\" --label \"CentOS_${OS_NICE}_Extras_x86_64\" --content-type \"yum\" --download-policy \"immediate\" --gpg-key \"RPM-GPG-KEY-CentOS-7\" --url \"${tmpBaseUrl}${tmpBaseExtras}\" --mirror-on-sync \"no\""
                do_function_task "hammer repository create --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} Updates x86_64\" --label \"CentOS_${OS_NICE}_Updates_x86_64\" --content-type \"yum\" --download-policy \"immediate\" --gpg-key \"RPM-GPG-KEY-CentOS-7\" --url \"${tmpBaseUrl}${tmpBaseUpdates}\" --mirror-on-sync \"no\""
                do_function_task "hammer repository create --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} Ansible x86_64\" --label \"CentOS_${OS_NICE}_Ansible_x86_64\" --content-type \"yum\" --download-policy \"immediate\" --gpg-key \"RPM-GPG-KEY-CentOS-7\" --url \"${tmpBaseUrl}${tmpBaseAnsible}\" --mirror-on-sync \"no\""
            fi
        fi
    done

    ## Create Katello synchronization plan
    do_function_task "hammer sync-plan create --organization-id 1 --name \"Daily Sync CentOS ${OS_VERSION}\" --interval daily --enabled true --sync-date \"2020-01-01 ${SYNC_TIME}\""
    do_function_task "hammer product set-sync-plan --organization-id 1 --name \"CentOS ${OS_VERSION} Linux x86_64\" --sync-plan \"Daily Sync CentOS ${OS_VERSION}\""

    ## Synchronize Katello repositories
    do_function_task_retry "hammer repository synchronize --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} OS x86_64\"" "5"
    do_function_task_retry "hammer repository synchronize --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} Extras x86_64\"" "5"
    do_function_task_retry "hammer repository synchronize --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} Updates x86_64\"" "5"
    do_function_task_retry "hammer repository synchronize --organization-id 1 --product \"CentOS ${OS_VERSION} Linux x86_64\" --name \"CentOS ${OS_VERSION} Ansible x86_64\"" "5"

    ## Create Katello content view
    do_function_task "hammer content-view create --organization-id 1 --name \"CentOS ${OS_VERSION}\" --label \"CentOS_${OS_NICE}\""

    ## Add repositories to content view
    do_function_task "hammer content-view add-repository --organization-id 1 --name \"CentOS ${OS_VERSION}\" --product \"CentOS ${OS_VERSION} Linux x86_64\" --repository \"CentOS ${OS_VERSION} OS x86_64\""
    do_function_task "hammer content-view add-repository --organization-id 1 --name \"CentOS ${OS_VERSION}\" --product \"CentOS ${OS_VERSION} Linux x86_64\" --repository \"CentOS ${OS_VERSION} Extras x86_64\""
    do_function_task "hammer content-view add-repository --organization-id 1 --name \"CentOS ${OS_VERSION}\" --product \"CentOS ${OS_VERSION} Linux x86_64\" --repository \"CentOS ${OS_VERSION} Updates x86_64\""
    do_function_task "hammer content-view add-repository --organization-id 1 --name \"CentOS ${OS_VERSION}\" --product \"CentOS ${OS_VERSION} Linux x86_64\" --repository \"CentOS ${OS_VERSION} Ansible x86_64\""
    do_function_task "hammer content-view add-repository --organization-id 1 --name \"CentOS ${OS_VERSION}\" --product \"Katello Client 7\" --repository \"Katello Client 7\""

    ## Publish and promote content view
    do_function_task "hammer content-view publish --organization-id 1 --name \"CentOS ${OS_VERSION}\" --description \"Initial publishing\""
    hammer --no-headers lifecycle-environment list --fields Name | grep -v "Library" | while read -r lcm;
    do
        do_function_task "hammer content-view version promote --organization-id 1 --content-view \"CentOS ${OS_VERSION}\" --version \"1.0\" --to-lifecycle-environment \"${lcm}\""
    done

    ## Create Katello activation keys
    hammer --no-headers lifecycle-environment list --fields Name | grep -v "Library" | while read -r lcm;
    do
        do_function_task "hammer activation-key create --organization-id 1 --name \"CentOS_${OS_NICE}_${lcm}_Key\" --lifecycle-environment \"${lcm}\" --content-view \"CentOS ${OS_VERSION}\" --unlimited-hosts"
    done

    ## Assign activation keys to Katello subscription (current view)
    local sub_centos_id
    sub_centos_id=$(hammer --no-headers subscription list --fields Id --search "CentOS ${OS_VERSION} Linux x86_64" | awk '{$1=$1};1')
    local sub_katello_id
    sub_katello_id=$(hammer --no-headers subscription list --fields Id --search "Katello Client 7" | awk '{$1=$1};1')
    hammer --no-headers lifecycle-environment list --fields Name | grep -v "Library" | while read -r lcm;
    do
        do_function_task "hammer activation-key add-subscription --organization-id 1 --name \"CentOS_${OS_NICE}_${lcm}_Key\" --quantity \"1\" --subscription-id \"${sub_centos_id}\""
        do_function_task "hammer activation-key add-subscription --organization-id 1 --name \"CentOS_${OS_NICE}_${lcm}_Key\" --quantity \"1\" --subscription-id \"${sub_katello_id}\""        
    done  

    ## Create Katello hostgroup
    hammer --no-headers location list --fields Name | while read -r location; 
    do
        domain_id=$(hammer --no-headers domain list --organization-id 1 --location "$location" --fields Id | awk '{$1=$1};1')
        hammer --no-headers lifecycle-environment list --fields Name | grep -v "Library" | while read -r lcm;
        do
            lcm_lower=$(echo "$lcm" | tr "[:upper:]" "[:lower:]")
            location_lower=$(echo "$location" | tr "[:upper:]" "[:lower:]")
            hostgroup_name="hg_${lcm_lower}_${location_lower}_${OS_NICE}"
            
            do_function_task "hammer hostgroup create --organization-id 1 --location \"${location}\" --name \"${hostgroup_name}\" --lifecycle-environment \"${lcm}\" --content-view \"CentOS ${OS_VERSION}\" --content-source \"katello.tanix.nl\" --compute-resource \"Tanix vCenter\" --compute-profile \"1-Small\" --domain-id \"${domain_id}\" --subnet \"tanix-5\" --architecture \"x86_64\" --operatingsystem \"CentOS-7\" --partition-table \"Kickstart default\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"yum-config-manager-disable-repo\" --parameter-type boolean --value \"true\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"enable-epel\" --parameter-type boolean --value \"false\""
            do_function_task "hammer hostgroup set-parameter --hostgroup \"${hostgroup_name}\" --name \"kt_activation_keys\" --value \"CentOS_${OS_NICE}_${lcm}_Key\""            
        done
    done
}

do_setup_bootdisks() {
    do_function_task "mkdir /var/lib/foreman/bootdisk"
    do_function_task "yum install shim-x64 -y"
    do_function_task "/usr/bin/cp -f /boot/efi/EFI/centos/shimx64.efi /var/lib/foreman/bootdisk/shimx64.efi"
    do_function_task "yum install grub2-efi-x64 -y"
    do_function_task "/usr/bin/cp -f /boot/efi/EFI/centos/grubx64.efi /var/lib/foreman/bootdisk/grubx64.efi"
    do_function_task "chmod 744 /var/lib/foreman/bootdisk/*.efi"
}

do_create_templates() {
    do_function_task "wget -P /tmp/ https://raw.githubusercontent.com/irjdekker/Katello/master/Kickstart_default_custom_packages"
    do_function_task "hammer template create --name \"Kickstart default custom packages\" --organization-id 1 --location-id 2 --type snippet --locked 1 --file /tmp/Kickstart_default_custom_packages"
    do_function_task "wget -P /tmp/ https://raw.githubusercontent.com/irjdekker/Katello/master/Kickstart_default_custom_post"
    do_function_task "hammer template create --name \"Kickstart default custom post\" --organization-id 1 --location-id 2 --type snippet --locked 1 --file /tmp/Kickstart_default_custom_post"
}

do_register_katello() {
    do_function_task "curl --insecure --output katello-ca-consumer-latest.noarch.rpm https://katello.tanix.nl/pub/katello-ca-consumer-latest.noarch.rpm"
    do_function_task "yum localinstall katello-ca-consumer-latest.noarch.rpm -y"
    do_function_task "subscription-manager register --org=\"Tanix\" --activationkey=\"CentOS_7_x_Production_Key\""
}

do_create_host() {
    local NAME
    NAME="$1"
    local HOSTGROUP
    HOSTGROUP="$2"
    local IP
    IP="$3"
    local PASSWORD
    PASSWORD="$4"
    local PROFILE
    PROFILE="$5"

    hostgroup_id=$(hammer --no-headers hostgroup list --fields Id --search "${HOSTGROUP}" | awk '{$1=$1};1')
    content_view=$(hammer hostgroup info --id "${hostgroup_id}" --fields "Content View/Name" | grep -i "name" | cut -d ":" -f 2 | awk '{$1=$1};1')
    repository=$(hammer content-view info --organization-id 1 --name "${content_view}" --fields "Yum Repositories/Name" | grep " OS " | cut -d ":" -f 2 | awk '{$1=$1};1')
    repository_id=$(hammer --no-headers repository list --name "${repository}" --fields Id | awk '{$1=$1};1')
    
    if [ -n "${PROFILE}" ]
    then
        compute_profile="${PROFILE}"
    else
        compute_profile=$(hammer hostgroup info --id "${hostgroup_id}" --fields "Compute Profile" | grep -i "compute profile" | cut -d ":" -f 2 | awk '{$1=$1};1')
    fi  

    do_function_task "hammer host create --name \"${NAME}\" --organization \"Tanix\" --location \"Home\" --hostgroup-id \"${hostgroup_id}\" --compute-profile \"${compute_profile}\" --owner-type \"User\" --owner \"admin\" --provision-method bootdisk --kickstart-repository-id \"${repository_id}\" --build 1 --managed 1 --comment \"Build via script on $(date)\" --root-password \"${PASSWORD}\" --ip \"${IP}\" --compute-attributes \"start=1\""
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
        exit
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
            print_task "${MESSAGE}" -1 false
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

## Check if password is specified
if [[ $# -eq 0 ]]
then
    echo "No password supplied"
    exit
fi

PASSWORD="$1"

## Check if script run by user root
if [ "$(whoami)" != "root" ]; then
    echo "Script startup must be run as user: root"
    exit
fi

# Hide cursor
tput civis

if false; then
## Setup locale
do_function "Setup locale" "do_setup_locale"

## Check hostname
do_function "Check hostname" "do_check_hostname"

## Setup chrony
do_function "Setup chrony" "do_setup_chrony"

## Setup NTP
do_function "Setup NTP" "do_setup_ntp"

## Setup firewall for Katello
do_function "Setup firewall for Katello" "do_setup_firewall"

## Clean previous disks
do_function "Clean previous disks" "do_clean_disks"

## Setup disk for pulp
do_function "Setup disk for pulp" "do_setup_disks"

## Update system
do_task "Update system" "yum update -y"

## Add repositories for Katello
do_function "Add repositories for Katello" "do_add_repositories"

## Install Katello package
do_task "Install Katello package" "yum install katello -y"

## Configure Katello installer
do_function "Configure Katello installer" "do_config_katello"

## Install Katello service
do_function "Install Katello service" "do_install_katello \"${PASSWORD}\""

## Install VMWare Tools
do_task "Install VMWare Tools" "yum install open-vm-tools -y"

## Update system (again)
do_task "Update system" "yum update -y"

## Create Katello compute resource (vCenter)
do_function "Create Katello compute resource (vCenter)" "do_compute_resource"
fi

## Update Katello compute profiles
do_function "Update Katello compute profiles" "do_compute_profiles"

## Create Katello subnet
do_function "Create Katello subnet" "do_create_subnet"

## Create Katello LCM environments
do_function "Create Katello LCM environments" "do_lcm_setup"

## Create Katello credential
do_function "Create Katello CentOS 7 credential" "do_centos7_credential"

## Create Katello setup for Katello Client 7
do_function "Create Katello setup for Katello Client 7" "do_populate_katello_client"

## Create Katello setup for CentOS 7.8
#do_function "Create Katello setup for CentOS 7.8" "do_populate_katello \"7.8\""

## Create Katello setup for CentOS 7.x
do_function "Create Katello setup for CentOS 7.x" "do_populate_katello \"7.x\""

## Setup bootdisks to Katello
do_function "Setup bootdisks to Katello" "do_setup_bootdisks"

## Create templates for Katello deployment
do_function "Create templates for Katello deployment" "do_create_templates"

# Register katello host
do_function "Register katello host" "do_register_katello"

# Change destroy setting
do_task "Change destroy setting" "hammer settings set --name \"destroy_vm_on_host_delete\" --value \"yes\""

# Create test host
do_function "Create test host" "do_create_host \"awk\" \"hg_production_home_7_x\" \"10.10.5.37\" \"${PASSWORD}\" \"2-Medium\""

# Restore cursor
tput cvvis