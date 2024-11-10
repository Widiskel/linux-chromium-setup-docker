#!/bin/bash

curl -s https://raw.githubusercontent.com/Widiskel/Widiskel/refs/heads/main/show_logo.sh | bash
sleep 3

if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt update -y && sudo apt upgrade -y
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
        sudo apt-get remove -y $pkg
    done

    sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    
    sudo apt update -y && sudo apt install -y docker-ce
    sudo systemctl start docker
    sudo systemctl enable docker

    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    echo "Docker installed successfully."
else
    echo "Docker is already installed."
fi

TIMEZONE=$(timedatectl | grep "Time zone" | awk '{print $3}')
if [ -z "$TIMEZONE" ]; then
    TIMEZONE="Asia/Jakarta"
fi

echo "Setting up Chromium USER & PASSWORD..."
read -p "Enter a custom username: " CUSTOM_USER
read -s -p "Enter a custom password: " CUSTOM_PASSWORD
echo "Username Set to $CUSTOM_USER, user password from previous step"
read -p "Enter a HTTP PORT You want to use (ex: 3010, default 3010 enter to continue): " CUSTOM_HTTP_PORT
CUSTOM_HTTP_PORT=${CUSTOM_HTTP_PORT:-3010} 
read -p "Enter a HTTPS PORT You want to use (ex: 3011, default 3011 enter to continue): " CUSTOM_HTTPS_PORT
CUSTOM_HTTPS_PORT=${CUSTOM_HTTPS_PORT:-3011}
echo "HTTP PORT|HTTPS PORT: $CUSTOM_HTTP_PORT | $CUSTOM_HTTPS_PORT"
read -p "Enter Proxy you want to use for this browser (ex: PROXYHOST:PROXYPORT ,default no proxy): " PROXY
PROXY=${PROXY:-""} 
if [[ "$PROXY" != "" ]]; then
    HTTPPROXY="http://$PROXY"
    HTTPSPROXY="https://$PROXY"
else
    HTTPPROXY=""
    HTTPSPROXY=""
fi
echo "HTTPPROXY|HTTPSPROXY: $HTTPPROXY|$HTTPSPROXY"


read -p "This app will running using docker container, Enter container name (ex : chromium-1, default chromium enter to continue): " CONTAINERNAME
CONTAINERNAME=${CONTAINERNAME:-chromium} 
echo "Container Name: $CONTAINERNAME"

echo "Setting up Chromium with Docker Compose..."
mkdir -p $HOME/$CONTAINERNAME && cd $HOME/$CONTAINERNAME

cat <<EOF | sudo tee .env
CUSTOM_USER=$CUSTOM_USER
PASSWORD=$CUSTOM_PASSWORD
TIMEZONE=$TIMEZONE
CUSTOM_HTTP_PORT=$CUSTOM_HTTP_PORT
CUSTOM_HTTPS_PORT=$CUSTOM_HTTPS_PORT
HTTPPROXY=$HTTPPROXY
HTTPSPROXY=$HTTPSPROXY
CONTAINERNAME=$CONTAINERNAME
EOF

cat <<EOF | sudo tee docker-compose.yaml
---
version: '3'
services:
  ${CONTAINERNAME}:
    image: lscr.io/linuxserver/chromium:latest
    container_name: ${CONTAINERNAME}
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=${CUSTOM_USER}
      - PASSWORD=${PASSWORD}
      - PUID=1000
      - PGID=1000
      - TZ=${TIMEZONE}
      - LANG=en_US.UTF-8
      - CHROME_CLI=https://google.com/
      - HTTP_PROXY=${HTTPPROXY}
      - HTTPS_PROXY=${HTTPSPROXY}
      - NO_PROXY=localhost,127.0.0.1
    volumes:
      - ${HOME}/${CONTAINERNAME}/config:/config
    ports:
      - ${CUSTOM_HTTP_PORT}:3000
      - ${CUSTOM_HTTPS_PORT}:3001
    shm_size: "1gb"
    restart: unless-stopped
EOF

if [ ! -f "docker-compose.yaml" ]; then
    echo "Failed to create docker-compose.yaml. Exiting..."
    exit 1
fi

echo "Starting Chromium Container..."
cd $HOME/chromium
docker-compose up -d

IPVPS=$(curl -s ifconfig.me)
cat <<EOF | sudo tee credentials.txt
---
USERNAME : $CUSTOM_USER
PASSWORD : $CUSTOM_PASSWORD
ACCESS   : http://$IPVPS:$CUSTOM_HTTP_PORT/ or https://$IPVPS:$CUSTOM_HTTPS_PORT/
EOF

echo "Chromium Docker Setup Complete..."
echo "Chromium container running, access it on: http://$IPVPS:$CUSTOM_HTTP_PORT/ or https://$IPVPS:$CUSTOM_HTTPS_PORT/"
echo "Username: $CUSTOM_USER"
echo "Password: $CUSTOM_PASSWORD"
echo "How to access : "
echo "1. Open access url"
echo "2. Enter Username and Password"
echo "3. If you use proxy and it need auth, you will be asked for enting username and password"
echo "4. Done and LFG"
