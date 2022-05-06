![Netizen Logo](https://www.netizen.net/assets/img/netizen_banner_cybersecure_small.png)

Visit out Website: https://www.netizen.net

# Greenbone Vulnerability Manager/Scanner
## Latest Version: 21.4.4-v2
![Docker Pulls](https://img.shields.io/docker/pulls/netizensoc/gvm-scanner?style=plastic)
![GitHub](https://img.shields.io/github/license/thecomet28/gvm-docker)

The docker container is based on the latest version of Greenbone Vulnerability Management 11 and OpenVAS. Netizen continues to make improvements to the software for stability and functionality of the suite. Our container supports AMD 64-bit and ARM 64-bit based operating systems.

A remote scanner can be found at visiting our [Openvas-Docker Github Repo](https://github.com/NetizenCorp/OpenVAS-Docker).

## Installation for AMD 64-Bit Based Operating Systems
First, install required packages, docker, and docker-compose on your linux system. After installation, apply permissions to a user(s) that will use docker. ${USER} is the username of the user(s).
```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common docker.io docker-compose
sudo usermod -aG docker ${USER}
```
Next, create a directory and download the docker-compose.yml file from github.
```bash
mkdir -p /home/$USER/docker/gvm-docker
cd /home/$USER/docker/gvm-docker
wget https://raw.githubusercontent.com/NetizenCorp/GVM-Docker/main/docker-compose.yml
```
Next, you will modify the docker-compose.yml file using your preferred editor (nano or vim).
```bash
nano docker-compose.yml
```
Edit the yml file with your preferences. NOTE: Netizen is not responsible for any breach if user fails to change the default username and passwords. Make sure to store your passwords in a secure password manager.
```bash
version: "3.1"
services:
    gvm:
        image: netizensoc/gvm-scanner:[latest|dev] # PICK A VERSION AND REMOVE BRACKETS BEFORE COMPOSING. Latest is the stable image. Dev is the development image.
        volumes:
          - gvm-data:/data              # DO NOT MODIFY
        environment:
          - USERNAME="admin"            # You can leave the username as admin or change to what ever you like
          - PASSWORD="admin"            # Please use 10+ Characters consisting of numbers, lower & uppercase letters. Special Characters can break the login.
          - HTTPS=true                  # DO NOT MODIFY
          - TZ="ETC"                    # Change to your corresponding timezone
          - SSHD=true                   # Mark true if using a Remote Scanner. Mark false if using a standalone operation.
          - DB_PASSWORD="dbpassword"    # Run the following command to generate "openssl rand -hex 40"
        ports:
          - "443:9392"  # Web interface
          - "5432:5432" # Access PostgreSQL database from external tools
          - "2222:22"   # SSH for remote sensors. You can remove if you don't plan on using remote scanners.
        restart: unless-stopped # Remove if your using for penetration testing or one-time scans. Only use if using for production/continuous scanning
volumes:
    gvm-data:
```
Next, its time to stand up the docker using docker-compose.
```bash
sudo docker-compose up -d # The -d option is for a detached docker image
```
It will take time for the container to be ready as it compiles the NVTs, CVE, CERTS, and SCAP data. To monitor this activity use the docker logs command.
```bash
docker container ls # Lists the current containers running on the system. Look under the Names column for the container name. Ex: gvm-docker_gvm_1
docker logs -f [container name] # Example: docker logs -f gvm-docker_gvm_1
```

After everything is complete, go the https://[Host IP Address]/ to access the scanner. Use the credentials you provided in the yml file.

## Installation for ARM 64-Bit Based Operating Systems
First, install docker and docker-compose on your linux system. After installation, apply permissions to a user(s) that will use docker. ${USER} is the username of the user(s).
```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common docker.io docker-compose
sudo usermod -aG docker ${USER}
```
Next, create a directory, clone the GitHub Repository, and Build the Docker Image. Note: The building process will take time to complete.
```bash
mkdir -p /home/$USER/docker/
cd /home/$USER/docker/
git clone https://github.com/NetizenCorp/GVM-Docker.git
cd GVM-Docker/
docker build . -t gvm
```
After the build is complete, you will modify the docker-compose.yml file using your preferred editor (nano or vim).
```bash
nano docker-compose.yml
```
Edit the yml file with your preferences. NOTE: Netizen is not responsible for any breach if user fails to change the default username and passwords. Make sure to store your passwords in a secure password manager.
```bash
version: "3.1"
services:
    gvm:
        image: gvm:latest
        volumes:
          - gvm-data:/data              # DO NOT MODIFY
        environment:
          - USERNAME="admin"            # You can leave the username as admin or change to what ever you like
          - PASSWORD="admin"            # Please use 10+ Characters consisting of numbers, lower & uppercase letters. Special Characters can break the login.
          - HTTPS=true                  # DO NOT MODIFY
          - TZ="ETC"                    # Change to your corresponding timezone
          - SSHD=true                   # Mark true if using a Remote Scanner. Mark false if using a standalone operation.
          - DB_PASSWORD="dbpassword"    # Run the following command to generate "openssl rand -hex 40"
        ports:
          - "443:9392"  # Web interface
          - "5432:5432" # Access PostgreSQL database from external tools
          - "2222:22"   # SSH for remote sensors. You can remove if you don't plan on using remote scanners.
        restart: unless-stopped # Remove if your using for penetration testing or one-time scans. Only use if using for production/continuous scanning
volumes:
    gvm-data:
```
Next, its time to stand up the docker using docker-compose.
```bash
sudo docker-compose up -d # The -d option is for a detached docker image
```
It will take time for the container to be ready as it compiles the NVTs, CVE, CERTS, and SCAP data. To monitor this activity use the docker logs command.
```bash
docker container ls # Lists the current containers running on the system. Look under the Names column for the container name. Ex: gvm-docker_gvm_1
docker logs -f [container name] # Example: docker logs -f gvm-docker_gvm_1
```

After everything is complete, go the https://[Host IP Address]/ to access the scanner. Use the credentials you provided in the yml file.
## Architecture

The key points to take away from the diagram below, is the way our setup establishes connection with the remote sensor, and the available ports on the GMV-Docker container. You can still use any add on tools you've used in the past with OpenVAS on 9390. One of the latest/best upgrades allows you connect directly to postgres using your favorite database tool. 

![GVM Container Architecture](https://securecompliance.co/wp-content/uploads/2020/11/SCS-GVM-Docker.svg)

## Docker Tags

| Tag       | Description              |
| --------- | ------------------------ |
| latest    | Latest stable version    |
| dev       | Latest development build |

## Estimated Hardware Requirements

| Hosts              | CPU Cores     | Memory    | Disk Space |
| :----------------- | :------------ | :-------- | :--------- |
| 512 active IPs     | 4@2GHz cores  | 8 GB RAM  | 30 GB      |
| 2,500 active IPs   | 6@2GHz cores  | 12 GB RAM | 60 GB      |
| 10,000 active IPs  | 8@3GHz cores  | 16 GB RAM | 250 GB     |
| 25,000 active IPs  | 16@3GHz cores | 32 GB RAM | 1 TB       |
| 100,000 active IPs | 32@3GHz cores | 64 GB RAM | 2 TB       |


## About
Any Issues or Suggestions for the Project can be communicated via the [issues](https://github.com/NetizenCorp/GVM-Docker/issues). Thanks.
