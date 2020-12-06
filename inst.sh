#!/bin/bash
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
read -s -n 1 -p "Press any key to continue . . ."
echo
echo -n Password: 
read -s password
echo
read -s -n 1 -p "Press any key to continue . . ."
foreman-installer --scenario katello --foreman-initial-admin-username admin --foreman-initial-admin-password "$password"
cat /var/log/foreman-installer/katello.log | grep -e "ERROR"
foreman-maintain service status
yum install open-vm-tools -y
yum update -y

