#!/bin/bash

apt-get update

apt-get install -y gnupg curl apt-utils ca-certificates wget

echo "deb http://apt.postgresql.org/pub/repos/apt jammy-pgdg main" > /etc/apt/sources.list.d/pgdg.list
# wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

apt-get update

INSTALL_PKGS="
bison \
build-essential \
cmake \
cron \
curl \
dpkg \
fakeroot \
gcc-mingw-w64 \
gcc \
gnupg \
gnutls-bin \
gpgsm \
heimdal-dev \
libgcrypt20-dev \
libjson-glib-dev \
libglib2.0-dev \
libgnutls28-dev \
libgpgme-dev \
libhiredis-dev \
libical-dev \
libksba-dev \
libldap2-dev \
libmicrohttpd-dev \
libpaho-mqtt-dev \
libnet1-dev \
libpcap-dev \
libpopt-dev \
libpq-dev \
libradcli-dev \
libsnmp-dev \
libssh-gcrypt-dev \
libbsd-dev \
libunistring-dev \
libxml2-dev \
mosquitto \
nano \
nmap \
nsis \
openssh-client \
openssh-server \
perl-base \
pkg-config \
postgresql-server-dev-13 \
postgresql-13 \
postfix \
python3 \
python3-cffi \
python3-defusedxml \
python3-impacket \
python3-lxml \
python3-packaging \
python3-paramiko \
python3-pip \
python3-psutil \
python3-redis \
python3-setuptools \
python3-wrapt \
python3-paho-mqtt \
redis-server \
rpm \
rsync \
smbclient \
snmp \
socat \
sshpass \
texlive-fonts-recommended \
texlive-latex-extra \
uuid-dev \
wget \
xml-twig-tools \
xmlstarlet \
xsltproc \
zip"

echo $INSTALL_PKGS

apt-get install -yq --no-install-recommends $INSTALL_PKGS

# Install Node.js
curl -sL https://deb.nodesource.com/setup_14.x | bash -
apt-get install nodejs -yq --no-install-recommends


# Install Yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list
apt-get update
apt-get install yarn -yq --no-install-recommends


rm -rf /var/lib/apt/lists/*
