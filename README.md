![Netizen Logo](https://www.netizen.net/assets/img/netizen_banner_cybersecure_small.png)

Visit our Website: https://www.netizen.net

# Greenbone Vulnerability Manager/Scanner
## Latest Version: 22.6.1
![Docker Pulls](https://img.shields.io/docker/pulls/netizensoc/gvm-scanner?style=plastic)
![GitHub](https://img.shields.io/github/license/thecomet28/gvm-docker)

The docker container is based on the latest version of Greenbone Vulnerability Management and OpenVAS. Netizen continues to make improvements to the software for the stability and functionality of the suite. This container supports AMD 64-bit and ARM 64-bit Linux-based operating systems. If upgrading from a previous version of GVM 21.04.x and older, or PostgreSQL version 13 or older, you will need to follow the PostgreSQL upgrade instructions. It is recommended to take a backup of your containers or VM before continuing in case of data corruption during the upgrade.

A remote scanner can be found by visiting our [Openvas-Docker Github Repo](https://github.com/NetizenCorp/OpenVAS-Docker).

## Table of Contents
- Installation Instructions
- [PostgreSQL Upgrade Instructions](https://github.com/NetizenCorp/GVM-Docker/tree/dev#postgresql-upgrade)
- [Architecture](https://github.com/NetizenCorp/GVM-Docker/tree/dev#architecture)
- [Docker Tags](https://github.com/NetizenCorp/GVM-Docker/tree/dev#docker-tags)
- [Estimated Hardware Requirements](https://github.com/NetizenCorp/GVM-Docker/tree/dev#estimated-hardware-requirements)
- [About](https://github.com/NetizenCorp/GVM-Docker/tree/dev#about)

## Installation Instructions

### Docker System Installation (AMD/ARM 64-bit Only)
First, install the required packages, docker, and docker-compose on your Linux system. After installation, apply permissions to a user(s) that will use docker. ${USER} is the username of the user(s).
```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common docker.io docker-compose
```
Next, create a directory and download the docker-compose.yml file from GitHub.
```bash
mkdir -p /home/$USER/gvm-docker
cd /home/$USER/gvm-docker
wget https://raw.githubusercontent.com/NetizenCorp/GVM-Docker/main/docker-compose.yml
```
Next, you will modify the docker-compose.yml file using your preferred editor (nano or vim).
```bash
nano docker-compose.yml
```
Edit the yml file with your preferences. NOTE: Netizen is not responsible for any breach if the user fails to change the default username and passwords. Make sure to store your passwords in a secure password manager.
```bash
version: "3.8"
services:
    gvm:
        image: netizensoc/gvm-scanner:[latest|dev] # PICK A VERSION AND REMOVE BRACKETS BEFORE COMPOSING. Latest is the stable image. Dev is the development image.
        volumes:
          - gvm-data:/data              # DO NOT MODIFY
        environment:
          - USERNAME="admin"            # You can leave the username as admin or change to whatever you like
          - PASSWORD="admin"            # Please use 15+ Characters consisting of numbers, lower & uppercase letters, and a special character.
          - HTTPS=true                  # DO NOT MODIFY
          - TZ="ETC"                    # Change to your corresponding timezone
          - SSHD=true                   # Mark true if using a Remote Scanner. Mark false if using a standalone operation.
          - DB_PASSWORD="dbpassword"    # Run the following command to generate "openssl rand -hex 40"
        ports:
          - "443:9392"  # Web interface
          - "5432:5432" # Access PostgreSQL database from external tools
          - "2222:22"   # SSH for remote sensors. You can remove if you don't plan on using remote scanners.
          # - "9390:9390" # For GVM API Access. Leave commented if you do not plan on using the API for external web application access.
        restart: unless-stopped # Remove if your using for penetration testing or one-time scans. Only use if using for production/continuous scanning
volumes:
    gvm-data:
```
Next, it's time to stand up the docker using docker-compose.
```bash
sudo docker-compose up -d # The -d option is for a detached docker image
```
It will take time for the container to be ready as it compiles the NVTs, CVE, CERTS, and SCAP data. To monitor this activity use the docker logs command.
```bash
sudo docker container ls # Lists the current containers running on the system. Look under the Names column for the container name. Ex: gvm-docker_gvm_1
sudo docker logs -f [container name] # Example: docker logs -f gvm-docker_gvm_1
```

After everything is complete, go the https://[Host IP Address]/ to access the scanner. Use the credentials you provided in the yml file.

## PostgreSQL Upgrade
If you are upgrading from a previous major version of PostgreSQL 13 or Under, you will need to upgrade your database before installation. The instructions below will guide you through the upgrade by doing a backup of your database, recreating the docker image, and restoring the backup. The new version of GVM uses Postgres version 14. Please follow the steps below.

- Log into the terminal Linux Box hosting the GVM scanner and then type the following commands
```bash
sudo docker exec -it [container name] bash
pg_dump -U postgres -d gvmd --role gvm -n public --blobs --format=c -f "dumpfile.sql"
exit
sudo docker container ls
```
- Copy the container ID of the GVM scanner to use for the docker copy
```bash
sudo docker cp [Container ID]:/dumpfile.sql ~/dumpfile.sql
sudo docker container stop [Container name]
sudo docker container rm [Container name] #This will remove the container
sudo docker volume ls #This will list the previous volume used for that docker image
sudo docker volume rm [Volume name] #This will delete the old volume.
sudo docker image ls #This is find the name of the image and remove the old version
sudo docker image rm [image name]
sudo docker-compose up -d
```
- After starting up the docker image, wait for it to load all GVM configs, NVT, SCAP, and CERT data before restoring the database. Use the docker logs command to monitor the progress. To restore the database file run the following commands:
```bash
sudo docker container ls #This is to get the new container ID of the docker image
sudo docker cp /dumpfile.sql [Container ID]:/
sudo docker exec -it [container name] bash
pg_restore -U gvm -d gvmd -c dumpfile.sql
```
After executing that command, wait for the restore function to place all the information back. After restoration, restart the docker container and then log in to verify your data has been restored.

## Architecture

The key points to take away from the diagram below are the way our setup establishes a connection with the remote scanner and the available ports on the GMV-Docker container. You can still use any add-on tools you've used in the past with OpenVAS on 9390. One of the latest/best upgrades allows you to connect directly to Postgres using your favorite database tool. 

![GVM Container Architecture](https://greenbone.github.io/docs/latest/_images/greenbone-community-22.4-architecture.png)

## Docker Tags

| Tag       | Description              |
| --------- | ------------------------ |
| latest    | Latest stable version    |
| dev       | Latest development build |

## Estimated Hardware Requirements

| Hosts              | CPU Cores     | Memory    | Disk Space |
| :----------------- | :------------ | :-------- | :--------- |
| 512 active IPs     | 4@2GHz cores  | 8 GB RAM  | 100 GB      |
| 2,500 active IPs   | 6@2GHz cores  | 12 GB RAM | 200 GB     |
| 10,000 active IPs  | 8@3GHz cores  | 16 GB RAM | 500 GB     |
| 25,000 active IPs  | 16@3GHz cores | 32 GB RAM | 1 TB       |
| 100,000 active IPs | 32@3GHz cores | 64 GB RAM | 2 TB       |


## About
Any Issues or Suggestions for the Project can be communicated via the [issues](https://github.com/NetizenCorp/GVM-Docker/issues). Thanks.
