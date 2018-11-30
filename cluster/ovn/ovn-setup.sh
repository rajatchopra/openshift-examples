#!/bin/bash

set -e
set -x

install_ovn() {
    if (which ovs-vsctl); then
        echo "ovn already installed"
    else
        rpm -i http://cbs.centos.org/kojifiles/packages/openvswitch/2.9.0/4.el7/x86_64/openvswitch-2.9.0-4.el7.x86_64.rpm
        rpm -i http://cbs.centos.org/kojifiles/packages/openvswitch/2.9.0/4.el7/x86_64/openvswitch-ovn-common-2.9.0-4.el7.x86_64.rpm
        rpm -i http://cbs.centos.org/kojifiles/packages/openvswitch/2.9.0/4.el7/x86_64/openvswitch-ovn-central-2.9.0-4.el7.x86_64.rpm
        rpm -i http://cbs.centos.org/kojifiles/packages/openvswitch/2.9.0/4.el7/x86_64/openvswitch-ovn-central-2.9.0-4.el7.x86_64.rpm
        rpm -i http://cbs.centos.org/kojifiles/packages/openvswitch/2.9.0/4.el7/x86_64/openvswitch-ovn-host-2.9.0-4.el7.x86_64.rpm
        rpm -i http://cbs.centos.org/kojifiles/packages/openvswitch/2.9.0/4.el7/x86_64/openvswitch-ovn-vtep-2.9.0-4.el7.x86_64.rpm
        rpm -i http://cbs.centos.org/kojifiles/packages/openvswitch/2.9.0/4.el7/x86_64/openvswitch-devel-2.9.0-4.el7.x86_64.rpm
    fi

    systemctl enable openvswitch
    systemctl start openvswitch || echo
    systemctl enable ovn-northd
    systemctl start ovn-northd || echo
    systemctl start ovn-controller || echo
}

install_ovn_kubernetes() {
    if (which ovnkube); then
		echo "ovnkube already installed"
    else
		go get github.com/openvswitch/ovn-kubernetes
		cd ${GOPATH}/src/github.com/openvswitch/ovn-kubernetes
		cd go-controller
		make
		make install
		ln -s /usr/bin/ovnkube /usr/local/bin/
		mkdir -p /etc/cni/net.d
		mkdir -p /opt/cni/bin
	fi
}

setup_ovn() {
    local config_dir=$1
    local kube_config="${config_dir}/admin.kubeconfig"
    local dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

    cp -f ${dir}/bin/ovn-kubernetes-master.service /etc/systemd/system/ovn-kubernetes-master.service || echo
    cp -f ${dir}/bin/ovn-kubernetes-node.service /etc/systemd/system/ovn-kubernetes-node.service || echo
    cp -f ${dir}/bin/ovn-kubernetes-node.sh /usr/local/bin/ || echo
    cp -f ${dir}/bin/ovn-kubernetes-master.sh /usr/local/bin/ || echo

    # Create the service account for OVN stuff
    if ! /usr/local/bin/oc --config="${kube_config}" get serviceaccount ovn >/dev/null 2>&1; then
        /usr/local/bin/oc --config="${kube_config}" create serviceaccount ovn
        /usr/local/bin/oc --config="${kube_config}" adm policy add-cluster-role-to-user cluster-admin -z ovn

        sleep 10
        /usr/local/bin/oc --config="${kube_config}" adm policy add-scc-to-user anyuid -z ovn
    fi
}

ensure_token() {
    local config_dir=${1}
    local kube_config="${config_dir}/admin.kubeconfig"
    local token_file="${config_dir}/ovn.token"

    if [ ! -f ${token_file} ]; then
	sleep 10
	/usr/local/bin/oc --config="${kube_config}" sa get-token ovn > ${token_file}
	[[ -s "${token_file}" ]]
    fi
}

install_ovn
install_ovn_kubernetes
setup_ovn /data/cluster/master
ensure_token

systemctl daemon-reload
systemctl start ovn-kubernetes-master
systemctl start ovn-kubernetes-node
