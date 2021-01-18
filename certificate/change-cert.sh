#!/bin/bash
workdirectory=`dirname "$(readlink -f "$0")"`
current_user=$(whoami)

echo -e "\033[1;34mStopping domoticz service ...\033[0m"
sudo service domoticz.sh stop

echo -e "\033[1;34mRenewing certificate ...\033[0m"
sudo /usr/bin/certbot certonly --manual --preferred-challenges dns --manual-public-ip-logging-ok --manual-auth-hook $workdirectory/cf-auth.sh --manual-cleanup-hook $workdirectory/cf-clean.sh --rsa-key-size 2048 --renew-by-default --register-unsafely-without-email --agree-tos --non-interactive -d *.tanix.nl

rc=$?;
if [[ $rc != 0 ]]; then
    echo -e "\033[0;31mError occured ...\033[0m"
    echo -e "\033[1;34mStarting domoticz service ...\033[0m"
    sudo service domoticz.sh start
    echo -e "\033[0;31mScript failed ...\033[0m"
    exit $rc
else
    echo -e "\033[1;34mUpdating domoticz certificate ...\033[0m"
    [ -f /home/$current_user/domoticz/letsencrypt_server_cert.pem ] && sudo rm /home/$current_user/domoticz/letsencrypt_server_cert.pem
    sudo cat /etc/letsencrypt/live/tanix.nl/privkey.pem >> /home/$current_user/domoticz/letsencrypt_server_cert.pem
    sudo cat /etc/letsencrypt/live/tanix.nl/fullchain.pem >> /home/$current_user/domoticz/letsencrypt_server_cert.pem
    [ -f /etc/ssl/certs/dhparam.pem ] || sudo /usr/bin/openssl dhparam -out /etc/ssl/certs/dhparam.pem 2048
    sudo cat /etc/ssl/certs/dhparam.pem >> /home/$current_user/domoticz/letsencrypt_server_cert.pem
    sudo /usr/bin/openssl pkcs12 -export -inkey /etc/letsencrypt/live/tanix.nl/privkey.pem -in /etc/letsencrypt/live/tanix.nl/fullchain.pem -out /home/$current_user/domoticz/letsencrypt_server_cert.p12 -name ubnt -password pass:<CERT_PASSWORD>
    sudo chown $current_user:$current_user /home/$current_user/domoticz/letsencrypt_server_cert.p12

    echo -e "\033[1;34mStarting domoticz service ...\033[0m"
    sudo service domoticz.sh start
    echo -e "\033[1;34mScript ended succesfully ...\033[0m"
    exit 0
fi
