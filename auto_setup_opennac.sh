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
# also available through the world wide web at this URL:G
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

help() {
    cat <<HELP
Usage: $0 [options] <basic_data_filename> <globals_data_filename> <authrepositories_data_filename>

Setup a previously installed Opennac on this machine

Available options:
    --help          display this help and exit
HELP
    exit 0
}

if [ "$1" == "--help" ]; then
    help
fi

# $1 == basic data filename
# $2 == globals data filename
# $3 == authrepositories data filename

CFG_READY=n
if [ $# -eq 3 ]; then 
	if [ -f $1 ]; then
		if [ -f $2 ]; then
			if [ -f $3 ]; then
				CFG_READY=y
			fi
		fi
	fi
fi

# prevent non absolute paths in filenames
OPENNAC_DIR=/usr/share/opennac
basic_data=$1
globals_data=$2
authrepositories_data=$3
echo $1 | grep -q ^/ || basic_data=$OPENNAC_DIR/$1
echo $2 | grep -q ^/ || globals_data=$OPENNAC_DIR/$2
echo $3 | grep -q ^/ || authrepositories_data=$OPENNAC_DIR/$3

if [ "$CFG_READY" == "n" ]; then
	echo "Missing or undefined setup data files"
	echo "Run with --help for more info."
	echo "Running $OPENNAC_DIR/getparams.sh first is required."
	echo "Aborting now."
	exit 1
fi

# Got data, run setup.

source $basic_data

# VARS: DB_NAME DB_HOST_IP DB_PORT MYSQL_ROOT_PASS MYSQL_ADMIN_USER MYSQL_ADMIN_PASS MONITOR_USER MONITOR_PASS

echo "  Configuring MySQLd"
mkdir /var/log/mysql
chown mysql:mysql /var/log/mysql
cat<<EOF>/etc/my.cnf
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql

# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

# Replication (Master)
#server-id = 1
#log_bin = /var/log/mysql/mysql-bin.log
#binlog_do_db = opennac
#expire_logs_days = 5

# Replication (Slave)
#server-id=X
#relay-log = /var/log/mysql/mysql-relay-bin.log
#log_bin  = /var/log/mysql/mysql-bin.log
#binlog_do_db = opennac
#expire_logs_days = 5
#slave-net-timeout = 60

# Skip reverse DNS lookup of clients
skip-name-resolve

# Performance Tunning
innodb_file_per_table

innodb_log_file_size=64M
innodb_buffer_pool_size=2G
innodb_log_buffer_size=4M
#innodb_flush_method=O_DIRECT
max_connections=1024
innodb_open_files=1024
table_open_cache=400

#innodb_flush_log_at_trx_commit:
# 1: InnoDB is fully ACID compliant (default).
# 2: committed transactions will be flushed to the redo logs only once a second
# 0: faster but you are more likely to lose some data in case of a crash
#innodb_flush_log_at_trx_commit=2

slow_query_log = 0
slow_query_log_file ='/var/log/mysql/slow-query.log'
long_query_time = 1

[mysqld_safe]
log-error=/var/log/mysql/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF

echo "	Starting MySQLd"
service mysqld start

echo "	Starting automatic MySQL secure installation." 
echo -e "\n\n${MYSQL_ROOT_PASS}\n${MYSQL_ROOT_PASS}\n\n\n\n" | /usr/bin/mysql_secure_installation

echo "  Creating $MYSQL_ADMIN_USER user with $MYSQL_ADMIN_PASS password"
echo "CREATE USER '$MYSQL_ADMIN_USER'@'$DB_HOST_IP' IDENTIFIED BY '$MYSQL_ADMIN_PASS';" | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
echo "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '$MYSQL_ADMIN_USER'@'$DB_HOST_IP' WITH GRANT OPTION;"       | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
echo "GRANT REPLICATION CLIENT ON *.* TO '$MYSQL_ADMIN_USER'@'$DB_HOST_IP';"       | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
echo "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '$MYSQL_ADMIN_USER'@'localhost' IDENTIFIED BY '$MYSQL_ADMIN_PASS' WITH GRANT OPTION;"       | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
echo "GRANT REPLICATION CLIENT ON *.* TO '$MYSQL_ADMIN_USER'@'localhost';"       | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
echo "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '$MYSQL_ADMIN_USER'@'127.0.0.1' IDENTIFIED BY '$MYSQL_ADMIN_PASS' WITH GRANT OPTION;"       | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
echo "GRANT REPLICATION CLIENT ON *.* TO '$MYSQL_ADMIN_USER'@'127.0.0.1';"       | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}


echo "  Creating \"$DB_NAME\" database and load data." 
cd /usr/share/opennac/api/docs
mysqladmin create $DB_NAME -h $DB_HOST_IP -P $DB_PORT -u $MYSQL_ADMIN_USER -p$MYSQL_ADMIN_PASS
test "$?" == "0" && echo ">>> Database $DB_NAME created."
mysql -h $DB_HOST_IP -P $DB_PORT -u $MYSQL_ADMIN_USER -p$MYSQL_ADMIN_PASS $DB_NAME < opennac.sql 
test "$?" == "0" && echo ">>> Data loaded."

echo "  Creating $MONITOR_USER monitor user"
echo "CREATE USER $MONITOR_USER@'$DB_HOST_IP';"                               | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
echo "GRANT SELECT ON ${DB_NAME}.ASSETS TO '$MONITOR_USER'@'$DB_HOST_IP' IDENTIFIED BY '$MONITOR_PASS';"      | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
echo "GRANT REPLICATION CLIENT ON *.* TO '$MONITOR_USER'@'$DB_HOST_IP' IDENTIFIED BY '$MONITOR_PASS';"      | mysql -h $DB_HOST_IP -P $DB_PORT -u root -p${MYSQL_ROOT_PASS}
test "$?" == "0" && echo ">>> $MONITOR_USER created"

# copy the .sample files from /usr/share/opennac/utils/httpd into /etc/httpd/conf.d and rename to .conf. Adapt paths as necessary
SRC_DIR=/usr/share/opennac/utils/httpd/conf.d ; DST_DIR=/etc/httpd/conf.d
cp $SRC_DIR/*.sample $DST_DIR
cd $DST_DIR
for file in *.sample; do 
	sed -i 's_/var/www/opennac_/usr/share/opennac_g' $file
 	mv $file `echo $file | sed 's/\.sample$//'`
done

# enable "combinedio" log format and add execution time in milis
sed -i 's/#[ \t]*LogFormat \(.*\)" combinedio/LogFormat \1 %D" combinedio/' /etc/httpd/conf/httpd.conf

# disable HTTP TRACE
echo "TraceEnable off" >> /etc/httpd/conf/httpd.conf

# PHP.D
echo "  Configuring PHP."
cd /etc/php.d
echo "extension=gearman.so" > gearman.ini

CLOCK_FILE=/etc/sysconfig/clock
TIMEZONE=`egrep "^ZONE" $CLOCK_FILE 2>/dev/null | cut -f2 -d= | sed "s/[\"| |\']//g"`
test -z $TIMEZONE && TIMEZONE="Europe/Berlin"
cat<<EOF>opennac.ini
include_path = ".:/usr/local/lib/php"
short_open_tag = On
date.timezone = "${TIMEZONE}"
EOF

# Enable APC for the CLI version of PHP
APC_FILE=`grep -P -l "^[ \t]*extension[ \t]*=[ \t]*apc[u]*.so" /etc/php.d/*`
if test -n "$APC_FILE"; then
  grep -P -q '^[ \t]*apc.enable_cli.*' $APC_FILE && sed -i 's/^[ \t]*apc.enable_cli.*/apc.enable_cli=1/' $APC_FILE || sed -i '0,/.*apc.enable_cli.*/s//apc.enable_cli=1/' $APC_FILE
  grep -P -q '^[ \t]*apc.shm_size.*' $APC_FILE && sed -i 's/^[ \t]*apc.shm_size.*/apc.shm_size=512M/' $APC_FILE || sed -i '0,/.*apc.shm_size.*/s//apc.shm_size=512M/' $APC_FILE
fi

# Update "memory_limit" value in PHP configuration
sed -i 's/memory_limit[ \t]*=.*/memory_limit = 512M/' /etc/php.ini

# Update "max_execution_time" value in PHP configuration
sed -i 's/max_execution_time[ \t]*=.*/max_execution_time = 120/' /etc/php.ini

# Restart HTTPD service, to apply changes
service httpd restart

###  Write cfg files
echo "  Writing Opennac config files."

# USERPORTAL
cd /usr/share/opennac/userportal/application/configs
mv application.ini.sample application.ini # unchanged
mv globals.ini.sample globals.ini # unchanged
# API
cd /usr/share/opennac/api/application/configs
cp $globals_data globals.ini ; chown apache:apache globals.ini
mv application.ini.sample application.ini # db access data
sed -i "s/resources.multidb.dbR.host =.*/resources.multidb.dbR.host = \"${DB_HOST_IP}\"/"               application.ini
sed -i "s/resources.multidb.dbR.port =.*/resources.multidb.dbR.port = \"${DB_PORT}\"/"                  application.ini
sed -i "s/resources.multidb.dbR.dbname =.*/resources.multidb.dbR.dbname = \"${DB_NAME}\"/"              application.ini
sed -i "s/resources.multidb.dbR.username =.*/resources.multidb.dbR.username = \"${MYSQL_ADMIN_USER}\"/" application.ini
sed -i "s/resources.multidb.dbR.password =.*/resources.multidb.dbR.password = \"${MYSQL_ADMIN_PASS}\"/" application.ini
sed -i "s/resources.multidb.dbW.host =.*/resources.multidb.dbW.host = \"${DB_HOST_IP}\"/"               application.ini
sed -i "s/resources.multidb.dbW.port =.*/resources.multidb.dbW.port = \"${DB_PORT}\"/"                  application.ini
sed -i "s/resources.multidb.dbW.dbname =.*/resources.multidb.dbW.dbname = \"${DB_NAME}\"/"              application.ini
sed -i "s/resources.multidb.dbW.username =.*/resources.multidb.dbW.username = \"${MYSQL_ADMIN_USER}\"/" application.ini
sed -i "s/resources.multidb.dbW.password =.*/resources.multidb.dbW.password = \"${MYSQL_ADMIN_PASS}\"/" application.ini
mv api.ini.sample api.ini # 
mv mobile-connect.ini.sample mobile-connect.ini
mv google-auth/google-people.json.sample google-auth/google-people.json
cp $authrepositories_data auth-repositories.ini ; chown apache:apache auth-repositories.ini
# apply auth-repositories info. Note: HTTPD service is required, due to cache usage.
/usr/share/opennac/api/scripts/updateAuthRepositories.php --assumeyes

# HEALTHCKECK
cd /usr/share/opennac/healthcheck
cp -rfv healthcheck.ini.master healthcheck.ini
# find and replace config vars in libexec/checkMysql.sh
sed -i "s/-H localhost/-H $DB_HOST_IP/" libexec/checkMysql.sh
sed -i "s/-P 3306/-P $DB_PORT/" libexec/checkMysql.sh
sed -i "s/-d opennac/-d $DB_NAME/" libexec/checkMysql.sh
sed -i "s/-u nagios/-u $MONITOR_USER/" libexec/checkMysql.sh
sed -i "s/Simpl3PaSs/$MONITOR_PASS/" libexec/checkMysql.sh
# find and replace config vars in libexec/check_mysql_replication.sh
sed -i "s/-u nagios/-u $MONITOR_USER/" libexec/check_mysql_replication.sh
sed -i "s/Simpl3PaSs/$MONITOR_PASS/" libexec/check_mysql_replication.sh

# DHCPREADER
cd /usr/share/opennac/dhcpreader
mv dhcpreader.config.sample dhcpreader.config
fifo=`grep dhcpfile dhcpreader.config | awk '{ print $3}'` 
test -p $fifo || mkfifo $fifo

# COLLECTD
COLLECTD_MYSQL_FILE=/etc/collectd.d/mysql.conf

if test -f $COLLECTD_MYSQL_FILE; then
   echo " Configuring collectd."
   egrep -v "^#" $COLLECTD_MYSQL_FILE | grep -q "<Plugin mysql>"
   if [ $? -eq 1 ]; then
      echo "" >> $COLLECTD_MYSQL_FILE
      echo "<Plugin mysql>" >> $COLLECTD_MYSQL_FILE
      echo "	Host \"$DB_HOST_IP\"" >> $COLLECTD_MYSQL_FILE
      echo "	Port $DB_PORT" >> $COLLECTD_MYSQL_FILE
      echo "	User \"$MYSQL_ADMIN_USER\"" >> $COLLECTD_MYSQL_FILE
      echo "	Password \"$MYSQL_ADMIN_PASS\"" >> $COLLECTD_MYSQL_FILE
      echo "	Database \"$DB_NAME\"" >> $COLLECTD_MYSQL_FILE
      echo "</Plugin>" >> $COLLECTD_MYSQL_FILE
   fi
fi

# FreeRADIUS SQL.CONF
# find and replace config vars in /etc/raddb/sql.conf.sample
sed -i "/^[ \t]*server[ \t]*=/ s/server.*/server = \"${DB_HOST_IP}\"/" /etc/raddb/sql.conf.sample
sed -i "/^[ \t]*port[ \t]*=/ s/port.*/port = ${DB_PORT}/" /etc/raddb/sql.conf.sample
sed -i "/^[ \t]*login[ \t]*=/ s/login.*/login = \"${MYSQL_ADMIN_USER}\"/" /etc/raddb/sql.conf.sample
sed -i "/^[ \t]*password[ \t]*=/ s/password.*/password = \"${MYSQL_ADMIN_PASS}\"/" /etc/raddb/sql.conf.sample
sed -i "/^[ \t]*radius_db[ \t]*=/ s/radius_db.*/radius_db = \"${DB_NAME}\"/" /etc/raddb/sql.conf.sample

# Configure Redis server
sed -i 's/^bind .*/bind 0.0.0.0/' /etc/redis.conf
sed -i 's/^save/#save/' /etc/redis.conf
sed -i 's/repl-diskless-sync no/repl-diskless-sync yes/' /etc/redis.conf
chkconfig redis on
service redis start

# Configure Rsyslog 
sed -i '/$ActionFileEnableSync/a \\n# Increased max message to support large messages send from openNAC Core to openNAC Analytics\n$MaxMessageSize 64k' /etc/rsyslog.conf
# Avoid reverse dns resolution in rsyslog
sed -i 's/SYSLOGD_OPTIONS=\(.*\)"/SYSLOGD_OPTIONS=\1 -x -Q"/' /etc/sysconfig/rsyslog

echo "  Configuring paths and permissions."
 
# Zend path
cd /usr/share/php && ln -s /usr/local/lib/php/Zend .
chmod 755 /usr/local/lib/php

# chgrp apache /etc/dhcp
chgrp apache /etc/dhcp

# Sudo for apache
cat << 'EOF' >> /etc/sudoers 
Defaults:apache !requiretty
apache ALL=(ALL) NOPASSWD: ALL
EOF

# Add hostname to /etc/hosts if not present
echo "  Configuring host names."
grep -q ^127.0.0.1.*`hostname` /etc/hosts || sed -i "/^127.0.0.1/s/$/\ `hostname`/" /etc/hosts
sed -i "/^::1/d" /etc/hosts
grep -q "onmaster" /etc/hosts || echo "127.0.0.1     onmaster" >> /etc/hosts
grep -q "onanalytics" /etc/hosts || echo "127.0.0.1     onanalytics" >> /etc/hosts
grep -q "onaggregator" /etc/hosts || echo "127.0.0.1     onaggregator" >> /etc/hosts

# Use sample ldap data
test "$USE_LDAP_SAMPLE_DATA" == "y" &&	{
    echo "  Configuring LDAP."
	rm -fr /etc/openldap/slapd.d
	cp -pr /usr/share/opennac/dist/openldap/* /etc/openldap
}

# populate macvendors in database
chmod +x /usr/share/opennac/api/scripts/macvendor.sh
/usr/share/opennac/api/scripts/macvendor.sh ${DB_HOST_IP} ${DB_PORT} ${MYSQL_ADMIN_USER} ${MYSQL_ADMIN_PASS} ${DB_NAME}

echo "Finished $0"
