#!/bin/bash

# filenames

dir=/usr/share/opennac
basic_answers_file=$dir/.basic.data
globals_answers_file=$dir/.globals.data
authrepositories_answers_file=$dir/.authrepositories.data

# function set_defaults. Modify if needed

set_defaults () {
	DB_NAME="opennac"
	DB_HOST_IP="localhost"
	DB_PORT="3306"
	MYSQL_ROOT_PASS="opennac"
	MYSQL_ADMIN_USER="admin"
	MYSQL_ADMIN_PASS="opennac"
	MONITOR_USER="nagios"
	MONITOR_PASS="Simpl3PaSs"
	RADIUS_PASS="testing123"
	USE_LDAP_SAMPLE_DATA="y"
	globals_url="opennac.local"
	globals_quarantine_vlan="320"
	globals_quarantine_network="172.16.20.0/24"
	globals_quarantine_ip_gateway="172.16.20.254"
	globals_quarantine_dhcp="172.16.20.100-172.16.20.200"
	globals_quarantine_ip="172.16.20.254"
	globals_quarantine_dns1="172.16.20.254"
	globals_quarantine_dns2=""
	globals_registry_vlan="310"
	globals_registry_network="172.16.10.0/24"
	globals_registry_ip_gateway="172.16.10.254"
	globals_registry_dhcp="172.16.10.100-172.16.10.200"
	globals_registry_ip="172.16.10.254"
	globals_registry_dns1="172.16.10.254"
	globals_registry_dns2=""
	globals_users_vlan="330"
	globals_users_network="192.168.4.0/24"
	globals_users_ip="192.168.4.15"
	globals_users_ip_gateway="192.168.4.1"
	globals_users_dns1="8.8.8.8"
	globals_users_dns2="8.8.4.4"
	globals_users_dhcp="192.168.4.200-192.168.4.210"
	globals_admin_network="192.168.1.0/24"
	globals_admin_ip="192.168.1.1"
	authrepositories_type="ldap"
	authrepositories_readOnly="true"
	authrepositories_ldap_host="localhost"
	authrepositories_ldap_port="389"
	authrepositories_ldap_username="cn=Manager,dc=example,dc=com"
	authrepositories_ldap_password="secret"
	authrepositories_ldap_baseDn="dc=example,dc=com"
}

# function check_dir

check_dir () {

test -d $dir || mkdir -p $dir

}

# function write_basic_data

write_basic_data () {

check_dir

cat <<EOF>$basic_answers_file
DB_NAME="${DB_NAME}"
DB_HOST_IP="${DB_HOST_IP}"
DB_PORT="${DB_PORT}"
MYSQL_ROOT_PASS="${MYSQL_ROOT_PASS}"
MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER}"
MYSQL_ADMIN_PASS="${MYSQL_ADMIN_PASS}"
MONITOR_USER="${MONITOR_USER}"
MONITOR_PASS="${MONITOR_PASS}"
RADIUS_PASS="${RADIUS_PASS}"
USE_LDAP_SAMPLE_DATA="${USE_LDAP_SAMPLE_DATA}"
EOF

}

# function write_globals_answers

function write_globals_data () {

check_dir

cat <<EOF>$globals_answers_file
[administrator]
userid = "${MYSQL_ADMIN_USER}"
password = "${MYSQL_ADMIN_PASS}"
url = "${globals_url}"

[quarantine]
vlan = "${globals_quarantine_vlan}"
network = "${globals_quarantine_network}"
ip_gateway = "${globals_quarantine_ip_gateway}"
dhcp = "${globals_quarantine_dhcp}"
ip = "${globals_quarantine_ip}"
dns1 = "${globals_quarantine_dns1}"
dns2 = "${globals_quarantine_dns2}"

[registry]
vlan = "${globals_registry_vlan}"
network = "${globals_registry_network}"
ip_gateway = "${globals_registry_ip_gateway}"
dhcp = "${globals_registry_dhcp}"
ip = "${globals_registry_ip}"
dns1 = "${globals_registry_dns1}"
dns2 = "${globals_registry_dns2}"

[users]
vlan = "${globals_users_vlan}"
network = "${globals_users_network}"
ip = "${globals_users_ip}"
ip_gateway = "${globals_users_ip_gateway}"
dns1 = "${globals_users_dns1}"
dns2 = "${globals_users_dns2}"
dhcp = "${globals_users_dhcp}"

[admin]
network = "${globals_admin_network}"
ip = "${globals_admin_ip}"
EOF

}

# function write_authrepositories_data

function write_authrepositories_data () {

check_dir

cat <<EOF>$authrepositories_answers_file
; Each section defines a repository
; There are 2 repository types: db and ldap
; Order of sections determines priority in user searches


[localdb]
type = "db"
readOnly = false
table = "USERS"
identityColumn = "USERID"
credentialColumn = "PASSWORD"
db.adapter = "PDO_MYSQL"
db.params.charset = "utf8"
db.params.host = "${DB_HOST_IP}"
db.params.dbname = "${DB_NAME}"
db.params.username = "${MYSQL_ADMIN_USER}"
db.params.password = "${MYSQL_ADMIN_PASS}"

[sample ldap]
type = "ldap"
readOnly = ${authrepositories_readOnly}
ldap.host = "${authrepositories_ldap_host}"
ldap.port = "${authrepositories_ldap_port}"
ldap.username = "${authrepositories_ldap_username}"
ldap.password = "${authrepositories_ldap_password}"
ldap.baseDn = "${authrepositories_ldap_baseDn}"
ldap.accountFilterFormat = "(uid=%s)"
ldap.bindRequiresDn = true
ldap.uidattr = "uid"
ldap.mailattr = "mail"
EOF

}

# function good_bye

good_bye () {
	echo "Data collected to:"
	echo "$basic_answers_file"
	echo "$globals_answers_file"
	echo "$authrepositories_answers_file"
	echo "Run \"$dir/auto_setup_opennac.sh $basic_answers_file $globals_answers_file $authrepositories_answers_file\" to install opennac."
}

# Start

# Check no previouis config exist. Set default values first, ask to be modified, then write files

test -f $basic_answers_file && {
	echo "Previous config found in $basic_answers_file."
	echo "Please delete:"
	echo "	$basic_answers_file"
	echo "	$globals_answers_file" 
	echo "	$authrepositories_answers_file"
	echo "and run again this script."
	echo "Aborting now."
	exit 1
	}
	
set_defaults

YESNO=z
until [ "$YESNO" == "y" -o "$YESNO" == "n" ]; do
	read -p "Use default values? [yn]: " YESNO
	done

if [ "$YESNO" == "n" ]; then
	YESNO=z
	until [ "$YESNO" == "y" ]; do
		read -p "Database name?: " DB_NAME
		read -p "Database Host IP?: " DB_HOST_IP
		read -p "Database Port?: " DB_PORT
		read -p "Password for root MySQL user?: " MYSQL_ROOT_PASS
		read -p "Admin user name?: " MYSQL_ADMIN_USER
		read -p "Admin user password: " MYSQL_ADMIN_PASS
		read -p "Monitor user name: " MONITOR_USER
		read -p "Monitor user password: " MONITOR_PASS
		read -p "RADIUS password: " RADIUS_PASS
		echo "
		Database name: 		$DB_NAME
		Database Host IP: 	$DB_HOST_IP
		Database Port:  	$DB_PORT
		MySQL root password:	$MYSQL_ROOT_PASS
		Admin user:	    	$MYSQL_ADMIN_USER
		Admin password:		$MYSQL_ADMIN_PASS
		Monitor user:		$MONITOR_USER
		Monitor password:	$MONITOR_PASS
		RADIUS  password:	$RADIUS_PASS
		"
		read -p "Is this ok? [yn]: " YESNO
	done

	ENABLE_LDAP=z
	until [ "$ENABLE_LDAP" == "y" -o "$ENABLE_LDAP" == "n" ]; do
       		read -p "Enable LDAP? [yn]: " ENABLE_LDAP
		USE_LDAP_SAMPLE_DATA=z
		until [ "$USE_LDAP_SAMPLE_DATA" == "y" -o "$USE_LDAP_SAMPLE_DATA" == "n" ]; do
       			read -p "Use sample LDAP data (existing schema will be deleted)? [yn]: " USE_LDAP_SAMPLE_DATA
		done
	done

	if [ "$ENABLE_LDAP" == "y" ]; then
		YESNO=z
        	until [ "$YESNO" == "y" ]; do
                	read -p "LDAP server IP?: " authrepositories_ldap_host
                	read -p "LDAP server port?: " authrepositories_ldap_port
                	read -p "LDAP login username?: " authrepositories_ldap_username
                	read -p "LDAP login password?: " authrepositories_ldap_password
                	read -p "LDAP base DN?: " authrepositories_ldap_baseDn
			echo "
		LDAP server IP:		${authrepositories_ldap_host}
		LDAP server port:	${authrepositories_ldap_port}
		LDAP login username:	${authrepositories_ldap_username}
		LDAP login password:	${authrepositories_ldap_password}
		BaseDN:			${authrepositories_ldap_baseDn}
			"
                	read -p "Is this ok? [yn]: " YESNO
        	done
	fi
fi

write_basic_data
write_globals_data
write_authrepositories_data

# strip LDAP section of authrepositories answers file if not selected

if [ "$ENABLE_LDAP" == "n" ]; then
	sed -i '/\[sample ldap\]/,$d' $authrepositories_answers_file
fi

good_bye
