# Multi-master setup dcoument

This section contain installation guide for setting up multi master kubernetes cluster. In this setting, we let the client IP be 192.168.99.11, and the masters IP be 192.168.99.13, and 192.168.99.14 respectively. We also assume that kube(kubeadm, kublet, and kubectl) and docker has already been installed in the masters.

## Prerequisites

In case that etcd has already been installed in the master, please remove it by running
```
$ sudo rm -rf /etc/etcd
$ sudo rm -rf /var/lib/etcd
```

In case that old pki files are still present in the master, please remove it by running
```
$ sudo rm -rf /etc/kubernetes/pki
```
In case that the old certificates are still present in the master, please remove it by running
```
$ rm ca-config.json ca-csr.json ca-key.pem ca.pem kubernetes-csr.json kubernetes-key.pem kubernetes.pem
```

## Setting up the client tools

In this part we generate Cloud Flare SSL tool to generate the different certificates, and kubectl to manage the Kubernetes cluster. The installation is done by running the following script.
```
$ ./install_essential_tool.sh
```

## Install HAproxy on the master

1. SSH to the 192.168.99.13 Ubuntu machine.

2. Update the machine.
```
$ sudo apt-get update
$ sudo apt-get upgrade
```

3. Install HAProxy.
```
$ sudo apt-get install haproxy
```

4. Configure HAProxy to load balance the traffic between the two Kubernetes master nodes by adding additional configuration to haproxy.cfg.
```
$ sudo vim /etc/haproxy/haproxy.cfg
...
default
...
global
frontend kubernetes
bind 192.168.99.11:6443
option tcplog
mode tcp
default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
mode tcp
balance roundrobin
option tcp-check
server k8s-master-0 192.168.99.13:6443 check fall 3 rise 2
server k8s-master-1 192.168.99.14:6443 check fall 3 rise 2
```

5. Restart HAProxy.
```
$ sudo systemctl restart haproxy
```

## Generating the TLS certificates

The following processes are done on the client. This section could be skipped if the certificates has already been generated.

### Creating a certificate authority

1. Create the certificate authority configuration file.
```
$ vim ca-config.json
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
```

2. Create the certificate authority signing request configuration file.
```
$ vim ca-csr.json
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "IE",
    "L": "Cork",
    "O": "Kubernetes",
    "OU": "CA",
    "ST": "Cork Co."
  }
 ]
}
```

3. Generate the certificate authority certificate and private key.
```
$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

### Creating the certificate for the Etcd cluster

1. Create the certificate signing request configuration file.
```
$ vim kubernetes-csr.json
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
  {
    "C": "IE",
    "L": "Cork",
    "O": "Kubernetes",
    "OU": "Kubernetes",
    "ST": "Cork Co."
  }
 ]
}
```

2. Generate the certificate and private key.
```
$ cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-hostname=192.168.99.11,192.168.99.13,192.168.99.14,127.0.0.1,kubernetes.default \
-profile=kubernetes kubernetes-csr.json | \
cfssljson -bare kubernetes
```

3. Copy the certificate to each nodes.
```
$ scp ca.pem kubernetes.pem kubernetes-key.pem master@192.168.99.13:~
$ scp ca.pem kubernetes.pem kubernetes-key.pem schwan@192.168.99.14:~
```

## Installing and configuring Etcd

### Note that Etcd configuration is performed on every master nodes.

1. Shell into master machine.

2. Create a configuration directory for Etcd and move the certificates to the configuration directory.
```
$ sudo mkdir /etc/etcd /var/lib/etcd
$ sudo mv ~/ca.pem ~/kubernetes.pem ~/kubernetes-key.pem /etc/etcd
```

3. Setting up etcd binaries
```
$ wget https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.g
$ tar xvzf etcd-v3.3.9-linux-amd64.tar.gz
$ sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
```

4. Create an etcd systemd unit file. <b> Note that the IP should be adjusted on different masters.</b>
```
$ sudo vim /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \
  --name 192.168.99.13 \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth \
  --initial-advertise-peer-urls https://192.168.99.13:2380 \
  --listen-peer-urls https://192.168.99.13:2380 \
  --listen-client-urls https://192.168.99.13:2379,http://127.0.0.1:2379 \
  --advertise-client-urls https://192.168.99.13:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster 192.168.99.13=https://192.168.99.13:2380,192.168.99.14=https://10.10.40.92:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5


[Install]
WantedBy=multi-user.target
```

5. Reload and start etcd.
```
$ sudo systemctl daemon-reload
$ sudo systemctl enable etcd
$ sudo systemctl start etcd
```

## Initializing the master nodes

1. Shell into one of master machine. In this case, we use 192.168.99.13. 
```
$ ssh master@192.168.99.13
```
2. Create the configuration file for kubeadm.
```
$ vim config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: stable
apiServerCertSANs:
- 192.168.99.11
controlPlaneEndpoint: "192.168.99.11:6443"
etcd:
  external:
    endpoints:
    - https://192.168.99.13:2379
    - https://192.168.99.14:2379
    caFile: /etc/etcd/ca.pem
    certFile: /etc/etcd/kubernetes.pem
    keyFile: /etc/etcd/kubernetes-key.pem
networking:
  podSubnet: 10.30.0.0/24
apiServerExtraArgs:
  apiserver-count: "3"
```

3. Initialize the machine as a master node.
```
$ sudo kubeadm init --config=config.yaml
```

4. Copy the certificates to the other masters
```
$ sudo scp -r /etc/kubernetes/pki schwan@192.168.99.14:~
```

5. Shell into another machine then repeat step 2-3. After that, join the second master to the first master.

## Configuring kubectl on the client machine

1. SSH to one of the master node.
```
$ ssh master@192.168.99.13
```

2. Add permissions to the admin.conf file.
```
$ sudo chmod +r /etc/kubernetes/admin.conf
```

3. From the client machine, copy the configuration file.
```
$ scp master@192.168.99.13:/etc/kubernetes/admin.conf 
```

4. Create the kubectl configuration directory.
```
$ mkdir ~/.kube
```

5. Move the configuration file to the configuration directory.
```
$ mv admin.conf ~/.kube/config
```

6. Modify the permissions of the configuration file.
```
$ chmod 600 ~/.kube/config
```

7. Go back to the SSH session on the master and change back the permissions of the configuration file.
```
$ sudo chmod 600 /etc/kubernetes/admin.conf
```

## Deploying the overlay network

1. Deploy the overlay network pods from the client machine.
```
$ kubectl apply -f \
 "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
```

2. Check that the pods are deployed properly.

```
$ kubectl get pods -n kube-system
```
