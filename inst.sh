#!/bin/bash
## The easiest way to get the script on your machine is:
## wget -O - https://raw.githubusercontent.com/irjdekker/Katello/master/inst.sh 2>/dev/null | bash
echo
echo -n Password: 
read -s password
echo
localectl set-locale LC_CTYPE=en_US.utf8
localectl status
hostnamectl status
dnsdomainname -f
hostname 
yum install chrony -y
systemctl enable chronyd
systemctl start chronyd
chronyc sources
timedatectl set-ntp true
timedatectl status
firewall-cmd --add-port={53,80,443,5647,9090}/tcp --permanent
firewall-cmd --add-port={67-69,53}/udp --permanent
firewall-cmd --reload
firewall-cmd --list-all
lvremove -f /dev/vg_pulp/lv_pulp
vgremove -f vg_pulp
pvremove -f /dev/sdb
pvcreate /dev/sdb
vgcreate vg_pulp /dev/sdb
lvcreate -y -l 100%FREE -n lv_pulp vg_pulp
mkfs.xfs -f /dev/mapper/vg_pulp-lv_pulp
mkdir /var/lib/pulp
mount /dev/mapper/vg_pulp-lv_pulp /var/lib/pulp/
echo "/dev/mapper/vg_pulp-lv_pulp /var/lib/pulp/ xfs defaults 0 0" >> /etc/fstab
tail -n1 /etc/fstab 
restorecon -Rv /var/lib/pulp/
df -hP /var/lib/pulp/
yum update -y
yum -y localinstall https://yum.theforeman.org/releases/2.2/el7/x86_64/foreman-release.rpm
yum -y localinstall https://fedorapeople.org/groups/katello/releases/yum/3.17/katello/el7/x86_64/katello-repos-latest.rpm
yum -y localinstall https://yum.puppet.com/puppet6-release-el-7.noarch.rpm
yum -y install epel-release centos-release-scl-rh
yum install katello -y
cd /etc/foreman-installer/scenarios.d/
mv /etc/foreman-installer/scenarios.d/katello-answers.yaml /etc/foreman-installer/scenarios.d/katello-answers.yaml.orig
wget -P /etc/foreman-installer/scenarios.d/ https://raw.githubusercontent.com/irjdekker/Katello/master/katello-answers.yaml
chown root:root /etc/foreman-installer/scenarios.d/katello-answers.yaml
chmod 600 /etc/foreman-installer/scenarios.d/katello-answers.yaml
foreman-installer --scenario katello --foreman-initial-admin-username admin --foreman-initial-admin-password "$password"
cat /var/log/foreman-installer/katello.log | grep -e "ERROR"
foreman-maintain service status
yum install open-vm-tools -y
yum update -y
hammer product create --organization-id 1 --name "CentOS 7 Linux x86_64"
mkdir -p /etc/pki/rpm-gpg/import
cd /etc/pki/rpm-gpg/import/
wget -P /etc/pki/rpm-gpg/import/ http://mirror.centos.org/centos-7/7/os/x86_64/RPM-GPG-KEY-CentOS-7
hammer gpg create --organization-id 1 --key "RPM-GPG-KEY-CentOS-7" --name "RPM-GPG-KEY-CentOS-7"
hammer repository create --organization-id 1 --product "CentOS 7 Linux x86_64" --name "CentOS 7 OS x86_64" --label "CentOS_7_OS_x86_64" --content-type "yum" \
--download-policy "on_demand" --gpg-key "RPM-GPG-KEY-CentOS-7" --url "http://mirror.centos.org/centos-7/7/os/x86_64/" --mirror-on-sync "no"
hammer repository create --organization-id 1 --product "CentOS 7 Linux x86_64" --name "CentOS 7 Extra x86_64" --label "CentOS_7_Extra_x86_64" --content-type "yum" \
--download-policy "on_demand" --gpg-key "RPM-GPG-KEY-CentOS-7" --url "http://mirror.centos.org/centos-7/7/extras/x86_64/" --mirror-on-sync "no"
hammer repository create --organization-id 1 --product "CentOS 7 Linux x86_64" --name "CentOS 7 Updates x86_64" --label "CentOS_7_Updates_x86_64" --content-type "yum" \
--download-policy "on_demand" --gpg-key "RPM-GPG-KEY-CentOS-7" --url "http://mirror.centos.org/centos-7/7/updates/x86_64/" --mirror-on-sync "no"
hammer repository create --organization-id 1 --product "CentOS 7 Linux x86_64" --name "CentOS 7 Ansible x86_64" --label "CentOS_Ansible_x86_64" --content-type "yum" \
--download-policy "on_demand" --gpg-key "RPM-GPG-KEY-CentOS-7" --url "http://mirror.centos.org/centos-7/7/configmanagement/x86_64/ansible-29/" --mirror-on-sync "no"
hammer sync-plan create --organization-id 1 --name "Daily Sync" --interval daily --enabled true –sync-date "2020-12-06 02:30:00"
hammer product set-sync-plan --organization-id 1 --name "CentOS 7 OS x86_64" --sync-plan "Daily Sync"
hammer product synchronize --organization-id 1 --name "CentOS 7 OS x86_64"
hammer lifecycle-environment create --organization-id 1 --name "Development" --label "Development" --prior "Library"
hammer lifecycle-environment create --organization-id 1 --name "Test" --label "Test" --prior "Development"
hammer lifecycle-environment create --organization-id 1 --name "Acceptance" --label "Acceptance" --prior "Test"
hammer lifecycle-environment create --organization-id 1 --name "Production" --label "Production" --prior "Acceptance"
hammer content-view create --organization-id 1 --name "CentOS 7" --label "CentOS_7" --product "CentOS 7 Linux x86_64"
hammer content-view publish --organization-id 1 --name "CentOS 7" --description "Initial publishing"
hammer content-view version promote --organization-id 1 --content-view "CentOS 7" --version "1.0" --to-lifecycle-environment "Development"
hammer content-view version promote --organization-id 1 --content-view "CentOS 7" --version "1.0" --to-lifecycle-environment "Test"
hammer content-view version promote --organization-id 1 --content-view "CentOS 7" --version "1.0" --to-lifecycle-environment "Acceptance"
hammer content-view version promote --organization-id 1 --content-view "CentOS 7" --version "1.0" --to-lifecycle-environment "Production"
hammer activation-key create --name "CentOS_7_Development_Key" --lifecycle-environment "Development" --content-view "CentOS 7" --unlimited-hosts
hammer activation-key create --name "CentOS_7_Test_Key" --lifecycle-environment "Test" --content-view "CentOS 7" --unlimited-hosts
hammer activation-key create --name "CentOS_7_Acceptance_Key" --lifecycle-environment "Acceptance" --content-view "CentOS 7" --unlimited-hosts
hammer activation-key create --name "CentOS_7_Production_Key" --lifecycle-environment "Production" --content-view "CentOS 7" --unlimited-hosts
hammer activation-key add-subscription --name "CentOS_7_Development_Key" --quantity "1" --subscription-id "1"
hammer activation-key add-subscription --name "CentOS_7_Test_Key" --quantity "1" --subscription-id "1"
hammer activation-key add-subscription --name "CentOS_7_Acceptance_Key" --quantity "1" --subscription-id "1"
hammer activation-key add-subscription --name "CentOS_7_Production_Key" --quantity "1" --subscription-id "1"
read -s -n 1 -p "Press any key to continue . . ."