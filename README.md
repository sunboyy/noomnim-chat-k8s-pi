# Noomnim Chat Kubernetes on Raspberry Pi

## Raspberry Pi configuration

1. Flash Raspberry Pi with Raspbian Stretch [Download](http://downloads.raspberrypi.org/raspbian/images/raspbian-2018-11-15/2018-11-13-raspbian-stretch.zip)
2. Run the script below to set static IP address to the Pi. Change IP address and router address depend on your preferences.

```sh
cat << EOF | sudo tee -a /etc/dhcpcd.conf
interface eth0
static ip_address=192.168.99.21/24
static routers=192.168.99.1
static domain_name_servers=8.8.8.8

interface wlan0
static ip_address=192.168.99.31/24
static routers=192.168.99.1
static domain_name_servers=8.8.8.8
EOF
```

3. Run `sudo raspi-config`
	- Configure host name and wifi in Network Options
	- Configure localization: Enable en_US.UTF-8 and th_TH.UTF-8 and set default to en_US.UTF-8
4. Reboot the Pi
5. Run the following script to install Docker and disable swap

```sh
sudo apt-get update
curl -sSL get.docker.com | sh && \
	sudo usermod pi -aG docker
sudo dphys-swapfile swapoff && \
	sudo dphys-swapfile uninstall && \
	sudo update-rc.d dphys-swapfile remove
sudo swapoff -a
sudo systemctl disable dphys-swapfile.service
```

6. Edit file `/boot/cmdline.txt` anda ppend `cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory` to the end of the first line.
7. Reboot the Pi
8. Run the following script to install `kubeadm`

```sh
cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo apt-get update
sudo apt-get install -qy kubeadm
```

## Deploying the application

```
wget -O- https://raw.githubusercontent.com/sunboyy/noomnim-chat-k8s-pi/master/k8s-deploy.sh | bash -
```
