# Multi-master setup via HA proxy

This section contain installation guide for multi master setting. In this setting, we let the client IP be 192.168.99.11, and the masters IP be 192.168.99.13, and 192.168.99.14 respectively. In this setting, we assume that kube(kubeadm, kublet, and kubectl) and docker has already been installed in the masters.

## Setting up the client tools
In this part we generate Cloud Flare SSL tool to generate the different certificates, and kubectl to manage the Kubernetes cluster. The installation is done by running the following script.
```
./install_essential_tool.sh
```


