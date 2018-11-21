#!/bin/bash

set -e

install-tools() {
    yum -y install yum-utils
    yum-config-manager --enable rhui-REGION-rhel-server-extras
    yum -y install git docker gcc-c++ wget krb5-devel
    systemctl restart docker
    if (which go); then
	echo "golang already installed"
    else
	echo "installing golang.."
	wget https://dl.google.com/go/go1.11.2.linux-amd64.tar.gz
	tar -C /usr/local -xzf go1.11.2.linux-amd64.tar.gz 
	export PATH=$PATH:/usr/local/go/bin
    fi
}

install-openshift() {
    if (which openshift); then
	return
    fi
    export GOPATH=/go
    mkdir -p /go/src/github.com/openshift
    cd /go/src/github.com/openshift
    if [ ! -d origin ]; then
	git clone https://github.com/openshift/origin
    fi
    cd origin
    make
    cd /usr/local/bin
    rm -f *
    ln -s /go/src/github.com/openshift/origin/_output/local/bin/linux/amd64/* .
}

setup-cluster() {
    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
    systemctl stop openshift-master || echo
    systemctl stop openshift-node || echo
    rm -rf /data
    mkdir -p /data/cluster
    cp -f ${dir}/bin/openshift-node.service /etc/systemd/system/openshift-node.service || echo
    cp -f ${dir}/bin/openshift-master.service /etc/systemd/system/openshift-master.service || echo
    cp -f ${dir}/bin/openshift-generate-master-config.sh /usr/local/bin/ || echo
    cp -f ${dir}/bin/openshift-node.sh /usr/local/bin/ || echo
}

install-tools
install-openshift
setup-cluster
systemctl daemon-reload
systemctl start openshift-master
systemctl start openshift-node
