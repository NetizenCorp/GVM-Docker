#!/usr/bin/env bash
set -Eeuo pipefail

USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-admin}
TIMEOUT=${TIMEOUT:-15}
RELAYHOST=${RELAYHOST:-smtp}#!/usr/bin/env bash
set -Eeuo pipefail

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

crontab cronsettings.txt
cron start

if [ ! -d "/run/redis" ]; then
	mkdir /run/redis
fi
if  [ -S /run/redis/redis.sock ]; then
        rm /run/redis/redis.sock
fi
redis-server --unixsocket /run/redis/redis.sock --unixsocketperm 700 --timeout 0 --databases 65536 --maxclients 4096 --daemonize yes --port 6379 --bind 0.0.0.0

echo "Wait for redis socket to be created..."
while  [ ! -S /run/redis/redis.sock ]; do
        sleep 1
done

echo "Testing redis status..."
X="$(redis-cli -s /run/redis/redis.sock ping)"
while  [ "${X}" != "PONG" ]; do
        echo "Redis not yet ready..."
        sleep 1
        X="$(redis-cli -s /run/redis/redis.sock ping)"
done
echo "Redis ready."

echo "Starting Mosquitto..."
/usr/sbin/mosquitto &
echo "mqtt_server_uri = localhost:1883" | tee -a /etc/openvas/openvas.conf


if  [ ! -d /data ]; then
	echo "Creating Data folder..."
        mkdir /data
fi

if  [ ! -d /data/database ]; then
	echo "Creating Database folder..."
	mkdir /data/database
	chown postgres:postgres -R /data/database
	su -c "/usr/lib/postgresql/13/bin/initdb /data/database" postgres
fi

chown postgres:postgres -R /data/database

echo "Starting PostgreSQL..."
su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database start" postgres

if  [ ! -d /data/ssh ]; then
	echo "Creating SSH folder..."
	mkdir /data/ssh
	
	rm -rf /etc/ssh/ssh_host_*
	
	dpkg-reconfigure openssh-server
	
	mv /etc/ssh/ssh_host_* /data/ssh/
fi

if  [ ! -h /etc/ssh ]; then
	rm -rf /etc/ssh
	ln -s /data/ssh /etc/ssh
fi

if [ ! -f "/firstrun" ]; then
	echo "Running first start configuration..."
	
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

	echo "Creating Greenbone Vulnerability system user..."
	useradd -r -M -U -G sudo -s /bin/bash gvm || echo "User already exists"
	usermod -aG tty gvm
	usermod -aG sudo gvm
	usermod -aG redis gvm

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
	
	chown gvm:gvm /usr/local/bin/greenbone-feed-sync
	chmod 740 /usr/local/bin/greenbone-feed-sync

	touch /firstrun 
fi

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
	
	echo "host    all             all              0.0.0.0/0                 md5" >> /data/database/pg_hba.conf
	echo "host    all             all              ::/0                      md5" >> /data/database/pg_hba.conf
	
	chown postgres:postgres -R /data/database
	
  su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database restart" postgres
 
	touch /data/firstrun
fi

if [ ! -f "/data/upgrade_to_21.4.0" ]; then
	su -c "psql --dbname=gvmd --command='CREATE TABLE IF NOT EXISTS vt_severities (id SERIAL PRIMARY KEY,vt_oid text NOT NULL,type text NOT NULL, origin text,date integer,score double precision,value text);'" postgres
	su -c "psql --dbname=gvmd --command='ALTER TABLE vt_severities ALTER COLUMN score SET DATA TYPE double precision;'" postgres
	su -c "psql --dbname=gvmd --command='UPDATE vt_severities SET score = round((score / 10.0)::numeric, 1);'" postgres
	su -c "psql --dbname=gvmd --command='ALTER TABLE vt_severities OWNER TO gvm;'" postgres
	touch /data/upgrade_to_21.4.0
fi

su -c "gvmd --migrate" gvm

if [ $DB_PASSWORD != "none" ]; then
	su -c "psql --dbname=gvmd --command=\"alter user gvm password '$DB_PASSWORD';\"" postgres
fi

echo "Creating gvmd folder..."
su -c "mkdir -p /var/lib/gvm/gvmd/report_formats" gvm
chown gvm:gvm -R /var/lib/gvm
find /var/lib/gvm/gvmd/report_formats -type f -name "generate" -exec chmod +x {} \;

if [ ! -d /var/lib/gvm/CA ] || [ ! -d /var/lib/gvm/private ] || [ ! -d /var/lib/gvm/private/CA ] ||
	[ ! -f /var/lib/gvm/CA/cacert.pem ] || [ ! -f /var/lib/gvm/CA/clientcert.pem ] ||
	[ ! -f /var/lib/gvm/CA/servercert.pem ] || [ ! -f /var/lib/gvm/private/CA/cakey.pem ] ||
	[ ! -f /var/lib/gvm/private/CA/clientkey.pem ] || [ ! -f /var/lib/gvm/private/CA/serverkey.pem ]; then
	echo "Creating certs folder..."
	mkdir -p /var/lib/gvm/CA
	mkdir -p /var/lib/gvm/private

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

echo "Starting Postfix for report delivery by email"
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
service postfix start

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
ospd-openvas --log-file /var/log/gvm/ospd-openvas.log --unix-socket /run/ospd/ospd-openvas.sock --socket-mode 0o666 --log-level INFO

while  [ ! -S /run/ospd/ospd-openvas.sock ]; do
	sleep 1
done

echo "Starting Notus Scanner..."
/usr/local/bin/notus-scanner --products-directory /var/lib/notus/products --log-file /var/log/gvm/notus-scanner.log

echo "Creating OSPd socket link from old location..."
rm -rf /tmp/ospd.sock
ln -s /run/ospd/ospd-openvas.sock /tmp/ospd.sock

echo "Starting Greenbone Vulnerability Manager..."
su -c "gvmd --listen=0.0.0.0 --port=9390 --max-ips-per-target=65536 --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1" gvm

echo "Waiting for Greenbone Vulnerability Manager to finish startup..."
until su -c "gvmd --get-users" gvm; do
	sleep 1
done

if [ ! -f "/var/lib/gvm/.created_gvm_user" ]; then
	echo "Creating Greenbone Vulnerability Manager admin user"
	su -c "gvmd --role=\"Super Admin\" --create-user=\"$USERNAME\" --password=\"$PASSWORD\"" gvm
	
	USERSLIST=$(su -c "gvmd --get-users --verbose" gvm)
	IFS=' '
	read -ra ADDR <<<"$USERSLIST"
	
	echo "${ADDR[1]}"
	
	su -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value ${ADDR[1]}" gvm
	
	touch /var/lib/gvm/.created_gvm_user
fi

su -c "gvmd --user=\"$USERNAME\" --new-password=\"$PASSWORD\"" gvm

echo "Starting Greenbone Security Assistant..."
if [ $HTTPS == "true" ]; then
	su -c "gsad --verbose --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0 --timeout=$TIMEOUT --no-redirect --mlisten=127.0.0.1 --mport=9390 --port=9392 --ssl-private-key=/var/lib/gvm/private/CA/serverkey.pem --ssl-certificate=/var/lib/gvm/CA/servercert.pem" gvm
else
	su -c "gsad --verbose --http-only --timeout=$TIMEOUT --no-redirect --mlisten=127.0.0.1 --mport=9390 --port=9392" gvm
fi

if [ ! -f "/var/lib/gvm/.fixed_db" ]; then
	echo "Fixing Database Tables..."
	su -c "psql --dbname=gvmd --command='ALTER TABLE IF EXISTS results ADD COLUMN hash_value VARCHAR;'" postgres
	su -c "psql --dbname=gvmd --command='ALTER TABLE IF EXISTS report_host_details ADD COLUMN hash_value VARCHAR;'" postgres
	
	touch /var/lib/gvm/.fixed_db
fi

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
SMTPPORT=${SMTPPORT:-25}

AUTO_SYNC=${AUTO_SYNC:-true}
HTTPS=${HTTPS:-true}
TZ=${TZ:-UTC}
SSHD=${SSHD:-false}
DB_PASSWORD=${DB_PASSWORD:-none}

crontab cronsettings.txt
cron start

if [ ! -d "/run/redis" ]; then
	mkdir /run/redis
	echo "db_address = /run/redis/redis.sock" | sudo tee -a /etc/openvas/openvas.conf
fi
if  [ -S /run/redis/redis-op.sock ]; then
        rm /run/redis/redis.sock
fi
redis-server --unixsocket /run/redis/redis.sock --unixsocketperm 770 --timeout 0 --databases 65536 --maxclients 4096 --daemonize yes --port 6379 --bind 0.0.0.0 --save "" --appendonly no

echo "Wait for redis socket to be created..."
while  [ ! -S /run/redis/redis.sock ]; do
        sleep 1
done

echo "Testing redis status..."
X="$(redis-cli -s /run/redis/redis.sock ping)"
while  [ "${X}" != "PONG" ]; do
        echo "Redis not yet ready..."
        sleep 1
        X="$(redis-cli -s /run/redis/redis.sock ping)"
done
echo "Redis ready."

echo "Starting Mosquitto..."
/usr/sbin/mosquitto &
echo "mqtt_server_uri = localhost:1883\ntable_driven_lsc = yes" | tee -a /etc/openvas/openvas.conf


if  [ ! -d /data ]; then
	echo "Creating Data folder..."
        mkdir /data
fi

if  [ ! -d /data/database ]; then
	echo "Creating Database folder..."
	mkdir /data/database
	chown postgres:postgres -R /data/database
	su -c "/usr/lib/postgresql/13/bin/initdb /data/database" postgres
fi

chown postgres:postgres -R /data/database

echo "Starting PostgreSQL..."
su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database start" postgres

if  [ ! -d /data/ssh ]; then
	echo "Creating SSH folder..."
	mkdir /data/ssh
	
	rm -rf /etc/ssh/ssh_host_*
	
	dpkg-reconfigure openssh-server
	
	mv /etc/ssh/ssh_host_* /data/ssh/
fi

if  [ ! -h /etc/ssh ]; then
	rm -rf /etc/ssh
	ln -s /data/ssh /etc/ssh
fi

if [ ! -f "/firstrun" ]; then
	echo "Running first start configuration..."
	
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

	echo "Creating Greenbone Vulnerability system user..."
	useradd -r -M -d /var/lib/gvm -U -G sudo -s /bin/bash gvm || echo "User already exists"
	usermod -aG gvm gvm
	usermod -aG tty gvm
	usermod -aG sudo gvm
	usermod -aG redis gvm
	echo "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas" >> /etc/sudoers
	
	echo "Creating Directories..."
	mkdir -p /run/gvmd
	mkdir -p /var/lib/notus
	mkdir -p /var/lib/gvm
	mkdir -p /run/ospd/
	mkdir -p /run/gsad/
	mkdir -p /run/notus-scanner/
	mkdir -p /var/lib/openvas/
	
	echo "Assigning Directory Permissions..."
	chown -R gvm:gvm /var/lib/gvm
	chown -R gvm:gvm /run/ospd
	chown -R gvm:gvm /run/gsad
	chown -R gvm:gvm /run/notus-scanner
	su -c "touch /run/ospd/feed-update.lock" gvm
	chown -R gvm:gvm /var/lib/openvas/plugins/
	chown -R gvm:gvm /var/lib/gvm
	chown -R gvm:gvm /var/lib/openvas
	chown -R gvm:gvm /var/log/gvm
	chown -R gvm:gvm /run/gvmd
	chown -R gvm:gvm /var/lib/notus
	chown -R gvm:gvm /usr/bin/nmap
	chown -R gvm:gvm /run/redis/
	
	# Adjusting permissions
	chmod -R g+srw /var/lib/gvm
	chmod -R g+srw /var/lib/openvas
	chmod -R g+srw /var/log/gvm
	
	chown -R gvm:gvm /usr/local/sbin/gvmd
	chmod -R 6750 /usr/local/sbin/gvmd
	chown -R gvm:gvm /usr/local/sbin/openvas
	chmod -R 6750 /usr/local/sbin/openvas
	
	chown gvm:gvm /usr/local/bin/greenbone-feed-sync
	chmod 740 /usr/local/bin/greenbone-feed-sync
	# chown gvm:gvm /usr/local/sbin/greenbone-*-sync
	# chmod 740 /usr/local/sbin/greenbone-*-sync

	touch /firstrun 
fi

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
	
	echo "host    all             all              0.0.0.0/0                 md5" >> /data/database/pg_hba.conf
	echo "host    all             all              ::/0                      md5" >> /data/database/pg_hba.conf
	
	chown postgres:postgres -R /data/database
	
	su -c "/usr/lib/postgresql/13/bin/pg_ctl -D /data/database restart" postgres
	
	touch /data/firstrun
fi

if [ ! -f "/data/upgrade_to_21.4.0" ]; then
	su -c "psql --dbname=gvmd --command='CREATE TABLE IF NOT EXISTS vt_severities (id SERIAL PRIMARY KEY,vt_oid text NOT NULL,type text NOT NULL, origin text,date integer,score double precision,value text);'" postgres
	su -c "psql --dbname=gvmd --command='ALTER TABLE vt_severities ALTER COLUMN score SET DATA TYPE double precision;'" postgres
	su -c "psql --dbname=gvmd --command='UPDATE vt_severities SET score = round((score / 10.0)::numeric, 1);'" postgres
	su -c "psql --dbname=gvmd --command='ALTER TABLE vt_severities OWNER TO gvm;'" postgres
	touch /data/upgrade_to_21.4.0
fi

su -c "gvmd --migrate" gvm

if [ $DB_PASSWORD != "none" ]; then
	su -c "psql --dbname=gvmd --command=\"alter user gvm password '$DB_PASSWORD';\"" postgres
fi


echo "Creating gvmd folder..."
su -c "mkdir -p /var/lib/gvm/gvmd/report_formats" gvm
#cp -r /report_formats /var/lib/gvm/gvmd/
chown gvm:gvm -R /var/lib/gvm
find /var/lib/gvm/gvmd/report_formats -type f -name "generate" -exec chmod +x {} \;

if [ ! -d /var/lib/gvm/CA ] || [ ! -d /var/lib/gvm/private ] || [ ! -d /var/lib/gvm/private/CA ] ||
	[ ! -f /var/lib/gvm/CA/cacert.pem ] || [ ! -f /var/lib/gvm/CA/clientcert.pem ] ||
	[ ! -f /var/lib/gvm/CA/servercert.pem ] || [ ! -f /var/lib/gvm/private/CA/cakey.pem ] ||
	[ ! -f /var/lib/gvm/private/CA/clientkey.pem ] || [ ! -f /var/lib/gvm/private/CA/serverkey.pem ]; then
	echo "Creating certs folder..."
	mkdir -p /var/lib/gvm/CA
	mkdir -p /var/lib/gvm/private

	echo "Generating certs..."
	gvm-manage-certs -a

	chown gvm:gvm -R /var/lib/gvm/
fi

# Sync NVTs, CERT data, and SCAP data on container start
if [ "$AUTO_SYNC" = true ] || [ ! -f "/firstsync" ]; then
	# Sync NVTs, CERT data, and SCAP data on container start
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

echo "Starting Postfix for report delivery by email"
sed -i "s/^relayhost.*$/relayhost = ${RELAYHOST}:${SMTPPORT}/" /etc/postfix/main.cf
service postfix start

echo "Starting Open Scanner Protocol daemon for OpenVAS..."
ospd-openvas --log-file /var/log/gvm/ospd-openvas.log --unix-socket /run/ospd/ospd-openvas.sock --socket-mode 0o666 --log-level INFO

while  [ ! -S /run/ospd/ospd-openvas.sock ]; do
	sleep 1
done

echo "Starting Notus Scanner..."
/usr/local/bin/notus-scanner --products-directory /var/lib/notus/products --log-file /var/log/gvm/notus-scanner.log

echo "Creating OSPd socket link from old location..."
rm -rf /tmp/ospd.sock
ln -s /run/ospd/ospd-openvas.sock /tmp/ospd.sock

echo "Starting Greenbone Vulnerability Manager..."
su -c "gvmd --listen=0.0.0.0 --port=9390 --max-ips-per-target=65536 --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0:-VERS-TLS1.1" gvm

echo "Waiting for Greenbone Vulnerability Manager to finish startup..."
until su -c "gvmd --get-users" gvm; do
	sleep 1
done

#if [[ ! -f "/var/lib/gvm/.created_gvm_user" || ! -f "/data/created_gvm_user" ]]; then
#if [ $FIRST == "true" ]; then
if [ ! -f "/var/lib/gvm/.created_gvm_user" ]; then
	echo "Creating Greenbone Vulnerability Manager admin user"
	su -c "gvmd --role=\"Super Admin\" --create-user=\"$USERNAME\" --password=\"$PASSWORD\"" gvm
	
	USERSLIST=$(su -c "gvmd --get-users --verbose" gvm)
	IFS=' '
	read -ra ADDR <<<"$USERSLIST"
	
	echo "${ADDR[1]}"
	
	su -c "gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value ${ADDR[1]}" gvm
	
	touch /var/lib/gvm/.created_gvm_user
fi

su -c "gvmd --user=\"$USERNAME\" --new-password=\"$PASSWORD\"" gvm

echo "Starting Greenbone Security Assistant..."
if [ $HTTPS == "true" ]; then
	su -c "gsad --verbose --gnutls-priorities=SECURE128:-AES-128-CBC:-CAMELLIA-128-CBC:-VERS-SSL3.0:-VERS-TLS1.0 --timeout=$TIMEOUT --no-redirect --mlisten=127.0.0.1 --mport=9390 --port=9392 --ssl-private-key=/var/lib/gvm/private/CA/serverkey.pem --ssl-certificate=/var/lib/gvm/CA/servercert.pem" gvm
else
	su -c "gsad --verbose --http-only --timeout=$TIMEOUT --no-redirect --mlisten=127.0.0.1 --mport=9390 --port=9392" gvm
fi

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
