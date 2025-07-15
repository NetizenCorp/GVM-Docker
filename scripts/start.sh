#!/usr/bin/env bash
set -Eeuo pipefail

# Set Variables

USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-admin}
TIMEOUT=${TIMEOUT:-15}
RELAYHOST=${RELAYHOST:-smtp}
SMTPPORT=${SMTPPORT:-25}

AUTO_SYNC=${AUTO_SYNC:-true}
HTTPS=${HTTPS:-true}
TZ=${TZ:-UTC}
SSHD=${SSHD:-false}
DB_PASSWORD=${DB_PASSWORD:-none}

# Copy Cron Scripts

crontab cronsettings.txt
cron start

# Create Redis Folder

if [ ! -d "/run/redis" ]; then
	mkdir /run/redis
  	cp /redis.conf /etc/redis/
  	chown redis:redis /etc/redis/redis.conf
  	echo "db_address = /run/redis/redis.sock" | tee -a /etc/openvas/openvas.conf
fi

# If redis socket exists then remove socket before start

if [ -S /run/redis/redis.sock ]; then
        rm /run/redis/redis.sock
fi

# Starting Redis Server

# redis-server --unixsocket /run/redis/redis.sock --unixsocketperm 700 --timeout 0 --databases 65536 --maxclients 4096 --daemonize yes --port 6379 --bind 0.0.0.0
redis-server /etc/redis/redis.conf

# Waiting for socket to be created

echo "Wait for redis socket to be created..."
while  [ ! -S /run/redis/redis.sock ]; do
        sleep 1
done

# Testing redis socket connection

echo "Testing redis status..."
X="$(redis-cli -s /run/redis/redis.sock ping)"
while  [ "${X}" != "PONG" ]; do
        echo "Redis not yet ready..."
        sleep 1
        X="$(redis-cli -s /run/redis/redis.sock ping)"
done
echo "Redis ready."

# Starting Mosquitto

# echo "Starting Mosquitto..."
# /usr/sbin/mosquitto &

# Copy server uri on first run

if [ ! -f /mqttfirstrun ]; then
  echo "openvasd_server = http://localhost:3000" | tee -a /etc/openvas/openvas.conf
	touch /mqttfirstrun
fi

# Creating data folder

if [ ! -d /data ]; then
	echo "Creating Data folder..."
        mkdir /data
fi

# Creating database folder

if [ ! -d /data/database ]; then
	echo "Creating Database folder..."
	mkdir /data/database
	chown postgres:postgres -R /data/database
	su -c "/usr/lib/postgresql/14/bin/initdb /data/database" postgres
fi

# Setting folder permissions

chown postgres:postgres -R /data/database

# Starting PostgreSQL

echo "Starting PostgreSQL..."
su -c "/usr/lib/postgresql/14/bin/pg_ctl -D /data/database start" postgres

# Creating SSH Folder and configuring

if [ ! -d /data/ssh ]; then
	echo "Creating SSH folder..."
	mkdir /data/ssh
	
	rm -rf /etc/ssh/ssh_host_*
	
	dpkg-reconfigure openssh-server
	
	mv /etc/ssh/ssh_host_* /data/ssh/
fi

# If the symbolic link doesn't exist the create the link

if [ ! -h /etc/ssh ]; then
	rm -rf /etc/ssh
	ln -s /data/ssh /etc/ssh
fi

# Starting first run configurations (user permissions, timezones, signing keys, creating folders)

if [ ! -f "/firstrun" ]; then
	echo "Running first start configuration..."
	
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

	echo "Creating Greenbone Vulnerability system user..."
	useradd -r -M -U -G sudo -s /bin/bash gvm || echo "User already exists"
	usermod -aG tty gvm
	usermod -aG sudo gvm
	usermod -aG redis gvm
	echo "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas" >> /etc/sudoers
 	chmod 0440 /etc/sudoers.d/gvm
  
 	echo "Importing Greenbone Signing Keys..."
 	curl -f -L https://www.greenbone.net/GBCommunitySigningKey.asc -o /tmp/GBCommunitySigningKey.asc
  	gpg --import /tmp/GBCommunitySigningKey.asc
  
  	echo "8AE4BE429B60A59B311C2E739823FAA60ED1E580:6:" > /tmp/ownertrust.txt
  	gpg --import-ownertrust < /tmp/ownertrust.txt

 	echo "Verifying Signing Keys..."
 	export GNUPGHOME=/tmp/openvas-gnupg
 	mkdir -p $GNUPGHOME

  	gpg --import /tmp/GBCommunitySigningKey.asc
 	gpg --import-ownertrust < /tmp/ownertrust.txt

 	export OPENVAS_GNUPG_HOME=/etc/openvas/gnupg
 	mkdir -p $OPENVAS_GNUPG_HOME
 	cp -r /tmp/openvas-gnupg/* $OPENVAS_GNUPG_HOME/
 	chown -R gvm:gvm $OPENVAS_GNUPG_HOME

	echo "Creating Directories..."
	mkdir -p /var/lib/gvm
	mkdir -p /run/gvmd
	mkdir -p /var/lib/notus
 	mkdir -p /run/ospd/
 	mkdir -p /run/gsad/
	mkdir -p /run/notus-scanner/
	mkdir -p /var/lib/openvas/
	
	echo "Assigning Directory Permissions..."
	chown -R gvm:gvm /var/lib/gvm
	chown -R gvm:gvm /run/ospd
	chown -R gvm:gvm /run/gsad
	chown -R gvm:gvm /run/notus-scanner
	chown -R gvm:gvm /var/lib/openvas
	chown -R gvm:gvm /var/log/gvm
	chown -R gvm:gvm /run/gvmd
	chown -R gvm:gvm /var/lib/notus
	chown -R gvm:gvm /usr/bin/nmap
	
	# Adjusting permissions
	chmod -R g+srw /var/lib/gvm
	chmod -R g+srw /var/lib/openvas
	chmod -R g+srw /var/log/gvm
	
	chown gvm:gvm /usr/local/sbin/gvmd
	chmod 6750 /usr/local/sbin/gvmd
	
	# chown gvm:gvm /usr/local/bin/greenbone-feed-sync
	# chmod 740 /usr/local/bin/greenbone-feed-sync
	
	# Downloading Python3-Impacket and Copying
	git clone https://github.com/SecureAuthCorp/impacket.git /python3-impacket/
	cp -R /python3-impacket/* /usr/share/doc/python3-impacket/

	touch /firstrun 
fi

# Creating GVM database

if [ ! -f "/data/firstrun" ]; then
	echo "Creating Greenbone Vulnerability Manager database"
	su -c "createuser -DRS gvm" postgres
	su -c "createdb -O gvm gvmd" postgres
	su -c "psql --dbname=gvmd --command='create role dba with superuser noinherit;'" postgres
	su -c "psql --dbname=gvmd --command='grant dba to gvm;'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"uuid-ossp\";'" postgres
	su -c "psql --dbname=gvmd --command='create extension \"pgcrypto\";'" postgres
	
	echo "listen_addresses = '*'" >> /data/database/postgresql.conf
	echo "port = 5432" >> /data/database/postgresql.conf
	echo "jit = off" >> /data/database/postgresql.conf
  	sed -i "s/max_wal_size = 1GB/max_wal_size = 4GB/" /data/database/postgresql.conf
	
	echo "host    all             all              0.0.0.0/0                 md5" >> /data/database/pg_hba.conf
	echo "host    all             all              ::/0                      md5" >> /data/database/pg_hba.conf
	
	chown postgres:postgres -R /data/database
	
	su -c "/usr/lib/postgresql/14/bin/pg_ctl -D /data/database restart" postgres
 
	touch /data/firstrun
fi

# Migrating database from older version of GVM

su -c "gvmd --migrate" gvm

# Setting database password for gvm

if [ $DB_PASSWORD != "none" ]; then
	su -c "psql --dbname=gvmd --command=\"alter user gvm password '$DB_PASSWORD';\"" postgres
fi

# Creating GVMD Folder

echo "Creating gvmd folder..."
su -c "mkdir -p /var/lib/gvm/gvmd/report_formats" gvm
chown gvm:gvm -R /var/lib/gvm
find /var/lib/gvm/gvmd/report_formats -type f -name "generate" -exec chmod +x {} \;

# Creating scanner certificates

if [ ! -d /var/lib/gvm/CA ] || [ ! -d /var/lib/gvm/private ] || [ ! -d /var/lib/gvm/private/CA ] || [ ! -f /var/lib/gvm/CA/cacert.pem ] || [ ! -f /var/lib/gvm/CA/clientcert.pem ] || [ ! -f /var/lib/gvm/CA/servercert.pem ] || [ ! -f /var/lib/gvm/private/CA/cakey.pem ] || [ ! -f /var/lib/gvm/private/CA/clientkey.pem ] || [ ! -f /var/lib/gvm/private/CA/serverkey.pem ]; then
	echo "Creating certs folder..."
	mkdir -p /var/lib/gvm/CA/
	mkdir -p /var/lib/gvm/private/

	echo "Generating certs..."
	gvm-manage-certs -a
	chown gvm:gvm -R /var/lib/gvm/
fi

# Sync NVTs, CERT data, and SCAP data on container start
if [ "$AUTO_SYNC" = true ] || [ ! -f "/firstsync" ]; then
	/sync-all.sh
	touch /firstsync
fi
true

###########################
#Remove leftover pid files#
###########################

if [ -f /run/ospd/ospd.pid ]; then
	rm /run/ospd/ospd.pid
fi

if [ -S /tmp/ospd.sock ]; then
	rm /tmp/ospd.sock
fi

if [ -S /run/ospd/ospd.sock ]; then
	rm /run/ospd/ospd-openvas.sock
fi

if [ ! -d /run/ospd ]; then
	mkdir /run/ospd
fi

# Starting PostFix email server

echo "Starting Postfix for report delivery by email"
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
service postfix start

# Starting OSPD-Openvas

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
ospd-openvas --unix-socket /run/ospd/ospd-openvas.sock --pid-file /run/ospd/ospd-openvas.pid --log-file /var/log/gvm/ospd-openvas.log --lock-file-dir /var/lib/openvas --socket-mode 0o776 --notus-feed-dir /var/lib/notus/advisories --log-level INFO

# Waiting for OSPD Socket Creations

while [ ! -S /run/ospd/ospd-openvas.sock ]; do
	sleep 1
done

# Starting OpenVAS Daemon

echo "Starting OpenVAS Daemon..."
su -c "/usr/local/bin/openvasd --mode service_notus --products /var/lib/notus/products --advisories /var/lib/notus/advisories --listening 127.0.0.1:3000 &" gvm

# Creating OSPD link

echo "Creating OSPd socket link from old location..."
rm -rf /tmp/ospd.sock
ln -s /run/ospd/ospd-openvas.sock /tmp/ospd.sock

# Starting GVMD

echo "Starting Greenbone Vulnerability Manager..."
su -c "gvmd --listen=0.0.0.0 --port=9390 --max-ips-per-target=65536 --affected-products-query-size=50000 --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1" gvm

echo "Waiting for Greenbone Vulnerability Manager to finish startup..."
until su -c "gvmd --get-users" gvm; do
	sleep 1
done

# Creating GVM Admin User

if [ ! -f "/data/.created_gvm_user" ]; then
	echo "Creating Greenbone Vulnerability Manager admin user"
	su -c "gvmd --role=\"Super Admin\" --create-user=\"$USERNAME\" --password=\"$PASSWORD\"" gvm
	
	USERSLIST=$(su -c "gvmd --get-users --verbose" gvm)
	IFS=' '
	read -ra ADDR <<<"$USERSLIST"
	
	echo "${ADDR[1]}"
	
	su -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value ${ADDR[1]}" gvm
	
	touch /data/.created_gvm_user
fi

# Sets Password after first creation of the user

su -c "gvmd --user=\"$USERNAME\" --new-password=\"$PASSWORD\"" gvm

# Starting GSA

echo "Starting Greenbone Security Assistant..."
if [ $HTTPS == "true" ]; then
	su -c "gsad --verbose --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1 --timeout=$TIMEOUT --no-redirect --mlisten=127.0.0.1 --mport=9390 --port=9392 --ssl-private-key=/var/lib/gvm/private/CA/serverkey.pem --ssl-certificate=/var/lib/gvm/CA/servercert.pem" gvm
else
	su -c "gsad --verbose --http-only --timeout=$TIMEOUT --no-redirect --mlisten=127.0.0.1 --mport=9390 --port=9392" gvm
fi

# Starting SSHD server for remote scanner connection

if [ $SSHD == "true" ]; then
	echo "Starting OpenSSH Server..."
	if [ ! -d /var/lib/gvm/.ssh ]; then
		echo "Creating scanner SSH keys folder..."
		mkdir -p /var/lib/gvm/.ssh
		chown gvm:gvm -R /var/lib/gvm/.ssh
	fi
		
	if [ ! -d /sockets ]; then
		mkdir /sockets
		chown gvm:gvm -R /sockets
	fi
	
	echo "gvm:gvm" | chpasswd
	
	rm -rf /var/run/sshd
	mkdir -p /var/run/sshd
	cp /sshd_config /etc/ssh/sshd_config
	/usr/sbin/sshd -f /sshd_config
fi

GVMVER=$(su -c "gvmd --version" gvm )
echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo "+ Your GVM $GVMVER container is now ready to use! +"
echo "++++++++++++++++++++++++++++++++++++++++++++++"
echo ""
echo "-----------------------------------------------------------"
echo "Server Public key: $(cat /etc/ssh/ssh_host_ed25519_key.pub)"
echo "-----------------------------------------------------------"
echo ""
echo "++++++++++++++++"
echo "+ Tailing logs +"
echo "++++++++++++++++"
tail -F /var/log/gvm/*
