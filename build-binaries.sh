#!/bin/bash

docker run -i -t google/golang /bin/bash -c "go get github.com/coreos/flannel"
sudo docker cp $(docker ps --latest -q):/go/bin/flannel ./binaries/
docker rm $(docker ps --latest -q)

mkdir kubernetes-tmp
cd kubernetes-tmp
wget https://github.com/kubernetes/kubernetes/releases/download/v0.7.0/kubernetes.tar.gz
tar -zxvf kubernetes.tar.gz kubernetes/server/kubernetes-server-linux-amd64.tar.gz
tar -zxvf kubernetes/server/kubernetes-server-linux-amd64.tar.gz kubernetes/server/bin/

sudo mv kubernetes/server/bin/* ../binaries/

cd ..

rm -rf kubernetes-tmp
