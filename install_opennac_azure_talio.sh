#!/bin/bash
#################################################################################
#
# OpenNac
#
# Open source network access control
#
# NOTICE OF LICENSE
#
# Licensed under the Open Software License version 3.0
#
# This source file is subject to the Open Software License (OSL 3.0) that is
# bundled with this package in the files license.txt / license.rst. It is
# also available through the world wide web at this URL:
# http://opensource.org/licenses/OSL-3.0
# If you did not receive a copy of the license and are unable to obtain it
# through the world wide web, please send an email to
# licensing@opennac.org so we can send you a copy immediately.
#
# author: Opennac Core Dev Team
# copyright: Copyright (c) 2013, Opennac Tech S.L. (http://opennac.org/)
# license: http://opensource.org/licenses/OSL-3.0 Open Software License (OSL 3.0)
# link: http://opennac.org
#
#################################################################################

#wget -N -l inf -r -np -p https://repo-opennac.opencloudfactory.com/

# $1 == basic data filename
# $2 == globals data filename
# $3 == authrepositories data filename

#if [ $# -ne 3 ]; then
#	echo "Missing config files"
#	echo "Please run $OPENNAC_DIR/getparams.sh first. Also run with --help for more info."
#	echo "Aborting now."
#	exit 1
#fi

OPENNAC_DIR=/usr/share/opennac

help() {
    cat <<HELP
Usage: $0 [options] <basic_data_filename> <globals_data_filename> <authrepositories_data_filename>

Available options:
    --help          display this help and exit
HELP
    exit 0
}

if [ "$1" == "--help" ]; then
    help
fi

# Install an opennac host from scratch.
service iptables stop

# Disable SELINUX
sed -i "s/^SELINUX=.*/SELINUX=disabled/" /etc/selinux/config

# Set Time
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Madrid /etc/localtime
echo ZONE=\\\"Europe/Madrid\\\" > /etc/sysconfig/clock

# Enable CentOS repos [base] [updates] [extras] [centosplus] [contrib] ...
sed -i "s/enabled=0/enabled=1/" /etc/yum.repos.d/CentOS-Base.repo

# Update installed packages
mkdir -p /var/lib/rpm-state
yum -y update
	
# Install epel repo
yum -y install epel-release

# Install some core system packages
yum -y install httpd wget sudo ntpd cronie system-config-keyboard firstboot

# Install system utilities
yum -y install libcurl-devel libpcap-devel net-snmp-utils screen patch ansible gdb nfs-utils

chkconfig --add firstboot
echo "RUN_FIRSTBOOT=YES" > /etc/sysconfig/firstboot

# Set opennac repo
mkdir /home/opennac
cd /home/opennac/
wget "https://onedrive.live.com/download?cid=3076FCAFFB59C02A&resid=3076FCAFFB59C02A%211339&authkey=AISakl0YMDTKe-8" -O opennacrepo.tar.gz
tar xvzf opennacrepo.tar.gz

yum install -y createrepo
createrepo /home/opennac/repo-opennac.opencloudfactory.com/x86_64

cat <<EOF>/etc/yum.repos.d/opennac.repo
[OPENNAC]
name=openNAC repo
baseurl="file:///home/opennac/repo-opennac.opencloudfactory.com/x86_64/"
enabled=1
gpgcheck=0
EOF

yum clean all
yum update -y

# Install Active Directory integration packages
yum -y remove samba-winbind samba-common samba-client samba-winbind-clients samba
yum -y install samba4 samba4-winbind samba4-winbind-clients krb5-server krb5-workstation

# install opennac rpms and dependenc/usr/share/opennac/.basic.data /usr/share/opennac/.globals.data /usr/share/opennac/.authrepositories.dataes.
yum -y --enablerepo=epel install opennac-userportal opennac-dhcpreader opennac-utils opennac-api opennac-admonportal opennac-dhcp-helper-reader opennac-gauth
test "$?" == "0" || {
	echo "--> yum install FAILED. Aborting ..."
	exit 1
}

# Auto-Setup
echo "Starting Auto-Setup"
#$OPENNAC_DIR/auto_setup_opennac.sh $1 $2 $3
#/usr/share/opennac/utils/build-repo/auto_setup_opennac.sh /usr/share/opennac/utils/build-repo/.basic.data.sample /usr/share/opennac/utils/build-repo/.globals.data.sample /usr/share/opennac/utils/build-repo/.authrepositories.data.sample
yes | bash /usr/share/opennac/utils/build-repo/getparams.sh
bash /usr/share/opennac/utils/build-repo/auto_setup_opennac.sh /usr/share/opennac/.basic.data /usr/share/opennac/.globals.data /usr/share/opennac/.authrepositories.data

# Set services on boot and start them
for service in ntpd mysqld memcached gearmand opennac httpd named dhcp-helper-reader radiusd slapd snmptrapd collectd; do
        chkconfig $service on && {
                service $service stop >/dev/null 2>&1
                service $service start
        }

done
sleep 5
ldapadd -f /tmp/base.ldif -x -D "cn=Manager,dc=example,dc=com" -w secret

#cp /usr/share/opennac/utils/vm-iface-config/opennac-iface /etc/init.d/
#chmod a+x /etc/init.d/opennac-iface
#chkconfig --add opennac-iface
#chkconfig opennac-iface on

cat >> /etc/issue  << EOF
openNAC live image
Default root password: opennac

EOF

cat >> /etc/motd  << EOF
openNAC live image

To setup keyboard layout execute:

system-config-keyboard

To setup timezone execute:

system-config-date-tui 

To setup network interfaces you can execute:

/usr/share/opennac/utils/vm-iface-config/opennac-iface

more info...

https://redmine-opennac.opencloudfactory.com/projects/opennac/wiki

openNAC team,

EOF

chmod a+x /usr/share/opennac/utils/vm-iface-config/opennac-iface

# Add opennac_timezone.sh execution when time is configured 
# from "/usr/sbin/system-config-date-tui" and "firstboot" menu
TIMEZONE_CMD="/usr/share/opennac/utils/build-repo/opennac_timezone.sh update"

grep -q "opennac_timezone.sh" /usr/sbin/system-config-date-tui 2>/dev/null
if [ $? -eq 1 ]; then
   echo "" >> /usr/sbin/system-config-date-tui
   echo "# Update openNAC PHP timezone property" >> /usr/sbin/system-config-date-tui
   echo "$TIMEZONE_CMD" >> /usr/sbin/system-config-date-tui
fi

grep -q "opennac_timezone.sh" /etc/init.d/firstboot 2>/dev/null
if [ $? -eq 1 ]; then
   ESCAPED_CMD=`echo $TIMEZONE_CMD | sed 's/\//\\\\\//g'`
   sed -i "s/exit \$RETVAL/# Update openNAC PHP timezone property\n\t$ESCAPED_CMD\n\n\texit \$RETVAL/" /etc/init.d/firstboot
fi

# Add network restart when network is configured from "/usr/sbin/system-config-network-tui" menu
grep -q "service network restart" /usr/share/system-config-network/netconf_tui.py 2>/dev/null
if [ $? -eq 1 ]; then
   sed -i -r 's/^( *)devlist.save\(\)/&\n\1os.system\("service network restart"\)/' /usr/share/system-config-network/netconf_tui.py
fi

# Disable weak ciphers for SSH
grep -q "Ciphers" /etc/ssh/sshd_config 2>/dev/null
if [ $? -eq 1 ]; then
   echo "" >> /etc/ssh/sshd_config
   echo "# Disable weak ciphers" >> /etc/ssh/sshd_config
   echo "Ciphers aes128-ctr,aes192-ctr,aes256-ctr" >> /etc/ssh/sshd_config
   echo "MACs hmac-sha1,hmac-ripemd160" >> /etc/ssh/sshd_config
   service sshd restart >/dev/null 2>/dev/null
fi

# Change default shell for user mysql
/usr/bin/chsh -s /sbin/nologin mysql

# replace "rpmnew" config files
mv /etc/named.conf.rpmnew /etc/named.conf 2>/dev/null
mv /etc/named.rfc1912.zones.rpmnew /etc/named.rfc1912.zones 2>/dev/null
mv /etc/dhcp/dhcpd.conf.rpmnew /etc/dhcp/dhcpd.conf 2>/dev/null
mv /etc/snmp/snmptrapd.conf.rpmnew /etc/snmp/snmptrapd.conf 2>/dev/null

# replace ".sample" config files in FreeRADIUS dir
mv /etc/raddb/modules.sample/* /etc/raddb/modules/ 2>/dev/null
rmdir /etc/raddb/modules.sample 2>/dev/null
FILES=($(find /etc/raddb -type f -name "*.sample" 2>/dev/null))
yes | for file in "${FILES[@]}"; do cp ${file} ${file%.*};done

# modify default_days, using 3600 days, in "/etc/raddb/certs/ca.cnf" and "/etc/raddb/certs/server.cnf" files of radius certs
# and regenerate new certificates
sed -i 's/default_days.*/default_days\t\t= 3600/' /etc/raddb/certs/ca.cnf
sed -i 's/default_days.*/default_days\t\t= 3600/' /etc/raddb/certs/server.cnf
make -C /etc/raddb/certs destroycerts;  /etc/raddb/certs/bootstrap
chown root:radiusd /etc/raddb/certs/*

# configure https web access
echo \"Configuring HTTPS ...\";
/usr/share/opennac/utils/build-repo/enable_https.sh --assumeyes

#Copy iptables configuration file
cp -rf /usr/share/opennac/utils/build-repo/iptables_core /etc/sysconfig/iptables
service iptables restart

#Overwrite filebeat configuration file
mv /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.orig
cp -av /usr/share/opennac/utils/filebeat/filebeat.yml /etc/filebeat/filebeat.yml
chown root: /etc/filebeat/filebeat.yml

cd /usr/share/opennac/healthcheck/
cp -rfv healthcheck.ini.master healthcheck.ini

yes | php /usr/share/opennac/api/scripts/updatedb.php

bash /usr/share/opennac/utils/scripts/post-install_no-move.sh

# If output of this script is piped tot "tee" then needs to kill it to force termination
echo "Finished $0. You can connect to http://your_server/admin"
kill `pidof tee` >/dev/null 2>&1