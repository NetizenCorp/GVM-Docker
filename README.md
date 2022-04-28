![Netizen Logo](https://www.netizen.net/assets/img/netizen_banner_cybersecure_small.png)

Visit out Website: https://www.netizen.net

# Greenbone Vulnerability Manager/Scanner
## Latest Version: 21.4.4
![Docker Pulls](https://img.shields.io/docker/pulls/netizensoc/gvm-scanner?style=plastic)
![GitHub](https://img.shields.io/github/license/thecomet28/gvm-docker)

This setup is based on Greenbone Vulnerability Management and OpenVAS. We have made improvements to help stability and functionality.

## Documentation
* Detailed instructions can be requested by emailing us at info@netizen.net. We will be publishing documentation soon.
* A remote scanner can be found at visiting our [Openvas-Docker](https://github.com/thecomet28/OpenVAS-Docker).

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
Any Issues or Suggestions for the Project can be communicated via the [issues](https://github.com/thecomet28/GVM-Docker/issues). Thanks.
