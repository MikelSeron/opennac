#!/bin/bash

#OPENNAC_REPO_URL=https://repo-opennac-testing.opencloudfactory.com/x86_64
KIBANA_ALT=kibana-6.2.2-linux-x86_64.tar.gz

grep -q "openNAC" /etc/issue 2>/dev/null
if [ $? -eq 1 ]; then
  cat >> /etc/issue  << EOF
openNAC Sensor/Analytics live image
Default root password: opennac

EOF
fi

grep -q "openNAC" /etc/motd 2>/dev/null
if [ $? -eq 1 ]; then
  cat >> /etc/motd  << EOF
openNAC Sensor/Analytics live image

To setup keyboard layout execute:

system-config-keyboard

To setup timezone execute:

timedatectl set-timezone [TIMEZONE]

To setup network interfaces you can execute:

nmtui

more info...

https://redmine-opennac.opencloudfactory.com/projects/opennac/wiki

openNAC team,

EOF
fi

# Set Time
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Madrid /etc/localtime
echo ZONE=\\\"Europe/Madrid\\\" > /etc/sysconfig/clock

mkdir -p /var/lib/rpm-state
yum -y update

yum -y install epel-release

# Set opennac repo
mkdir /home/opennac
cd /home/opennac/
wget "https://onedrive.live.com/download?cid=3076FCAFFB59C02A&resid=3076FCAFFB59C02A%211336&authkey=AMEBLEbCRSIgypw" -O opennacrepo.tar.gz
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

# Disable Firewalld
systemctl stop firewalld
systemctl disable firewalld

rpm -qa system-config-keyboard | grep -q system-config-keyboard 2>/dev/null
if [ $? -eq 1 ]; then
  yum -y install system-config-keyboard
fi

rpm -qa ntp | grep -q ntp 2>/dev/null
if [ $? -eq 1 ]; then
  yum -y install ntp
  systemctl disable chronyd
  systemctl stop chronyd
  systemctl enable ntpd
  systemctl start ntpd
fi

rpm -qa open-vm-tools | grep -q open-vm-tools 2>/dev/null
if [ $? -eq 1 ]; then
  yum -y install open-vm-tools
fi

rpm -qa python2-pip | grep -q python2-pip 2>/dev/null
if [ $? -eq 1 ]; then
  yum -y install python2-pip
fi

pip install es2csv

yum -y install elasticsearch elasticsearch-curator git java-1.8.0-openjdk kibana logstash nodejs patch rubygems nc

#enable and start elasticsearch
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch
for (( c=1; c<=10; c++ )); do  
	sleep 5
	
	if (curl -s --noproxy "*" -XGET 'http://localhost:9200/' >/dev/null 2>/dev/null)
	then
		break
	fi
done
# If ElasticSearch is down, notice it in stderr and exit
if (curl -s --noproxy "*" -XGET 'http://localhost:9200/' >/dev/null 2>/dev/null)
then
	echo "ElasticSearch started ok"
fi

#enable and start kibana (wait until it creates it's index structure)
systemctl enable kibana
systemctl start kibana
i=0
while ! (systemctl status kibana -l | grep "Status changed from yellow to green - Ready")
do
	sleep 10
	((i++))
	if [ ${i} -eq 10 ]
	then
		curl -s --noproxy "*" -XGET http://localhost:5601/ 2&>1 >> /tmp/opennac-analytics.log
		echo	 "It was not possible to contact Kibana, so we are exiting. Check the logs and run the install/update again."
		exit 1
	fi
done

# Set services on boot and start them
for service in redis logstash; do
  systemctl enable $service
  systemctl start $service
done

yum -y install opennac-analytics opennac-healthcheck

# install iptables
rpm -qa iptables-services | grep -q iptables-services 2>/dev/null
if [ $? -eq 1 ]; then
  yum -y install iptables-services
  systemctl enable iptables
  systemctl start iptables
fi

#Copy iptables configuration file
cp -rf /usr/share/opennac/analytics/iptables_analytics /etc/sysconfig/iptables
service iptables restart

rpm -qa vim | grep -q vim 2>/dev/null
if [ $? -eq 1 ]; then
  yum -y install vim
fi

rpm -qa nano | grep -q nano 2>/dev/null
if [ $? -eq 1 ]; then
  yum -y install nano
fi

grep -q "onanalytics" /etc/hosts 2>/dev/null
if [ $? -eq 1 ]; then
  echo "" >> /etc/hosts
  echo "127.0.0.1	onanalytics" >> /etc/hosts
fi

grep -q "onaggregator" /etc/hosts 2>/dev/null
if [ $? -eq 1 ]; then
  echo "" >> /etc/hosts
  echo "127.0.0.1	onaggregator" >> /etc/hosts
fi

grep -q "oncore" /etc/hosts 2>/dev/null
if [ $? -eq 1 ]; then
  echo "" >> /etc/hosts
  echo "127.0.0.1	oncore" >> /etc/hosts
fi

grep -q "onmaster" /etc/hosts 2>/dev/null
if [ $? -eq 1 ]; then
  echo "" >> /etc/hosts
  echo "127.0.0.1	onmaster" >> /etc/hosts
fi

# Install Kibana alternative, for debug operations, in "/opt/kibana-..."
cp /home/opennac/repo-opennac.opencloudfactory.com/x86_64/$KIBANA_ALT /opt
cd /opt
#wget $OPENNAC_REPO_URL/$KIBANA_ALT
tar xzf $KIBANA_ALT
rm -f $KIBANA_ALT

# If output of this script is piped tot "tee" then needs to kill it to force termination
echo "Finished $0. You have to configure the openNAC server to send information to openNAC Analytics ..."
kill `pidof tee` >/dev/null 2>&1