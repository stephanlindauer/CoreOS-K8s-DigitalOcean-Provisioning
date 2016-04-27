#!/bin/bash

private_ips=$1
echo $private_ips

cd
git clone --depth=1 https://github.com/stephanlindauer/coreos-k8s-digitalocean-provisioning
mkdir -p /opt/bin
mv coreos-k8s-digitalocean-provisioning/binaries/* /opt/bin/
echo "done setting up binaries"

if [[ $(hostname) == coreos-k8s-master ]]; then
    echo "PRIVATE_IPS=$private_ips" > /etc/environment-cluster
    cat /etc/environment-cluster
fi

cd /etc/systemd/system/
systemctl enable *
systemctl start *
