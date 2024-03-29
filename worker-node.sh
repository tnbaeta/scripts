#!/bin/bash

set -e

# This script can be run headless to just install the binaries
# The needed environment parameters to run in that fashion are:
# K8S_AUTOMATED=1 - tells the script this is headless
# K8S_VERSION=1.15.0 - the script will fill in v<>+vmware.1
# SCP=1 - asks if you are going to scp from a local machine 
# SCP_IP=ip address  - Where the vmware tarball exists on a machine

# First declare the docker version and kubernetes version
docker_version="18.09.4"
if  [ -n "$K8S_VERSION" ]
    then
       K8S_VERSION=v"$K8S_VERSION"+vmware.1
    else
        K8S_VERSION="v1.15.1+vmware.1"
fi
CNI_VERSION="0.7.5"
CRI_TOOLS="1.14.0"
COREDNS="v1.3.1"
ETCD="v3.3.10"
PAUSE="3.1"

#Name of Packages based on the version
PACKAGE_NAME=$(sed 's/v1/_1/g' <<< $K8S_VERSION)

#Download name
DOWNLOAD_NAME=$(sed 's/+/%2B/g' <<< $K8S_VERSION )

#Image name
IMAGE_NAME=$(sed 's/+/_/g' <<< $K8S_VERSION)

#Fixed etcd image
ETCD_SOLO=$(sed 's/v//g' <<< $ETCD)

#Fixed coredns name
COREDNS_SOLO=$(sed 's/v//g' <<< $COREDNS)

# Two part to get the RPM Name for install
RPM_NAME_WITH_V=$(cut -d '+' -f1 <<< $K8S_VERSION )
RPM_NAME=$(sed 's/v//g' <<< $RPM_NAME_WITH_V)


#Check if the OS is Ubuntu or Redhat based
if [[ -e /etc/debian_version ]]
then
    OS="ubuntu"
elif [[ -e /etc/redhat-release ]]
then
    OS="rhel"
else
    echo "Not a supported OS"
fi

# Docker Install for Ubuntu
if [ $OS == "ubuntu" ]
then
    ubuntu_version=$( uname -a | awk '{print $3}' | cut -d '-' -f1 | cut -d '.' -f2 )
    installed_docker=$( sudo docker version | head -5 | grep  Version | awk '{print $2}' | cut -d '-' -f1 )
    # remove old docker versions
    if [ ${docker_version} == "${installed_docker}" ]
    then
        echo "Docker already desired version"
    else
        echo "starting docker install"
        echo ${installed_docker}
        if  [ ${ubuntu_version} -le 4 ]
            then
                sudo apt-get remove docker docker-engine docker.io containerd runc
        fi

        # update the apt repository
        sudo apt-get update

        # install neccesary prereqs
        sudo apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg-agent \
            software-properties-common \
            socat \
            ebtables

        # Add the key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

        #Add the docker repo
        sudo add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"

        sudo apt-get update

        # Install the right docker version
        if  [ ${ubuntu_version} -le 4 ]
        then
            sudo apt-get install -y docker-ce=5\:${docker_version}~3-0~ubuntu-xenial docker-ce-cli=5\:${docker_version}~3-0~ubuntu-xenial containerd.io
        else    
            sudo apt-get install -y docker-ce=5\:${docker_version}~3-0~ubuntu-bionic docker-ce-cli=5\:${docker_version}~3-0~ubuntu-bionic containerd.io
        fi
        
        # Setup daemon and not fail on reruns
        if [[ ! -f /etc/docker/daemon.json ]]
        then
cat > daemon.json <<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
"max-size": "100m"
},
"storage-driver": "overlay2"
}
EOF

sudo cp daemon.json /etc/docker/daemon.json

sudo mkdir -p /etc/systemd/system/docker.service.d
fi
        # Enable and start docker
        sudo systemctl enable docker
        sudo systemctl daemon-reload
        sudo systemctl restart docker
    fi
fi

# Docker install on Red Hat
if [ $OS == "rhel" ]
then
    installed_docker=$( sudo docker version | head -5 | grep  Version | awk '{print $2}' | cut -d '-' -f1 )
    if [ ${docker_version} == "${installed_docker}" ]
    then
        echo "Docker already desired version"
    else
    #Remove Old Versions
    sudo yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine

    # Install things we need later on
    sudo yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2 wget socat ebtables

    # Set up the Docker CE repo
    sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

    #Install the right docker packages 
    sudo yum install -y docker-ce-${docker_version}-3.el7 docker-ce-cli-${docker_version}-3.el7 containerd.io

# Setup daemon and not fail on reruns
    if [[ ! -f /etc/docker/daemon.json ]]
    then
cat > daemon.json <<EOF
{
"exec-opts": ["native.cgroupdriver=systemd"],
"log-driver": "json-file",
"log-opts": {
"max-size": "100m"
},
"storage-driver": "overlay2"
}
EOF

sudo mkdir /etc/docker
sudo cp daemon.json /etc/docker/daemon.json

sudo mkdir -p /etc/systemd/system/docker.service.d
fi

        # Enable and start docker
        sudo systemctl enable docker
        sudo systemctl daemon-reload
        sudo systemctl restart docker
    fi

fi

# Docker is now installed. Need to grab and download the signed binaries

if [ ! -f "vmware-kubernetes-${K8S_VERSION}.tar.gz"  ]
    then
        if [ "$K8S_AUTOMATED" == "1" ]
        then
            if [ "$SCP" = "1" ]
            then
                scp -o StrictHostKeyChecking=no ${SCP_IP}:vmware-kubernetes-${K8S_VERSION}.tar.gz vmware-kubernetes-${K8S_VERSION}.tar.gz
            else
                wget https://essentialpks-staging.s3-us-west-2.amazonaws.com/essential-pks/523a448aa3e9a0ef93ff892dceefee0a/vmware-kubernetes-${DOWNLOAD_NAME}.tar.gz
            fi
        else
        # Saving on Bandwidth and time
        echo "Do you have ssh keys properly configured and another instance in this cluster with these files available? (y/n)"

        read varscp

            if [ $varscp == "y" ]
                then
                    echo "What is ip address?"
                    read varscphost

                    scp -o StrictHostKeyChecking=no ${varscphost}:vmware-kubernetes-${K8S_VERSION}.tar.gz vmware-kubernetes-${K8S_VERSION}.tar.gz
                else
                    wget https://downloads.heptio.com/essential-pks/523a448aa3e9a0ef93ff892dceefee0a/vmware-kubernetes-${DOWNLOAD_NAME}.tar.gz
            fi
        fi
else
    echo "VMware Signed Binary Archive already downloaded"
fi

if [ ! -d "vmware-kubernetes-${K8S_VERSION}" ]
then
    tar zxf vmware-kubernetes-${K8S_VERSION}.tar.gz
else
    echo "VMware folder already present"
fi

#Install Deb packages on Ubuntu
if [[ $OS == "ubuntu" &&  ! -f vmware-kubernetes-${K8S_VERSION}/debs/installed.txt ]]
then

    sudo dpkg -i vmware-kubernetes-${K8S_VERSION}/debs/cri-tools_${CRI_TOOLS}+vmware.1-1_amd64.deb
    sudo dpkg -i vmware-kubernetes-${K8S_VERSION}/debs/kubernetes-cni_${CNI_VERSION}+vmware.1-1_amd64.deb
    sudo dpkg -i vmware-kubernetes-${K8S_VERSION}/debs/kubectl${PACKAGE_NAME}-1_amd64.deb
    sudo dpkg -i vmware-kubernetes-${K8S_VERSION}/debs/kubelet${PACKAGE_NAME}-1_amd64.deb
    sudo dpkg -i vmware-kubernetes-${K8S_VERSION}/debs/kubeadm${PACKAGE_NAME}-1_amd64.deb

    # This file is created once to not keep installing the same files remove to reinstall these packages
    touch vmware-kubernetes-${K8S_VERSION}/debs/installed.txt
elif [[ $OS == "rhel" && ! -f vmware-kubernetes-${K8S_VERSION}/rpms/installed.txt ]]
then 
    

    sudo rpm -ivh --nosignature vmware-kubernetes-${K8S_VERSION}/rpms/cri-tools-${CRI_TOOLS}-1.el7.vmware.1.x86_64.rpm --nodeps
    sudo rpm -ivh --nosignature vmware-kubernetes-${K8S_VERSION}/rpms/kubernetes-cni-${CNI_VERSION}-1.el7.vmware.1.x86_64.rpm --nodeps
    sudo rpm -ivh --nosignature vmware-kubernetes-${K8S_VERSION}/rpms/kubectl-${RPM_NAME}-1.el7.vmware.1.x86_64.rpm --nodeps
    sudo rpm -ivh --nosignature vmware-kubernetes-${K8S_VERSION}/rpms/kubelet-${RPM_NAME}-1.el7.vmware.1.x86_64.rpm --nodeps
    sudo rpm -ivh --nosignature vmware-kubernetes-${K8S_VERSION}/rpms/kubeadm-${RPM_NAME}-1.el7.vmware.1.x86_64.rpm --nodeps

    touch vmware-kubernetes-${K8S_VERSION}/rpms/installed.txt

else
    echo "Packages have already been installed"
fi


#Enable kubelet
sudo systemctl enable kubelet

#Install the signed images
if [  ! -f vmware-kubernetes-${K8S_VERSION}/images-installed.txt ]
then
    sudo docker load -i vmware-kubernetes-${K8S_VERSION}/coredns-${COREDNS}+vmware.3/images/coredns-${COREDNS}_vmware.3.tar.gz
    sudo docker load -i vmware-kubernetes-${K8S_VERSION}/etcd-${ETCD}+vmware.3/images/etcd-${ETCD}_vmware.3.tar.gz
    sudo docker load -i vmware-kubernetes-${K8S_VERSION}/kubernetes-${K8S_VERSION}/images/kube-proxy-${IMAGE_NAME}.tar.gz
    sudo docker load -i vmware-kubernetes-${K8S_VERSION}/kubernetes-${K8S_VERSION}/images/kube-apiserver-${IMAGE_NAME}.tar.gz
    sudo docker load -i vmware-kubernetes-${K8S_VERSION}/kubernetes-${K8S_VERSION}/images/kube-controller-manager-${IMAGE_NAME}.tar.gz
    sudo docker load -i vmware-kubernetes-${K8S_VERSION}/kubernetes-${K8S_VERSION}/images/kube-scheduler-${IMAGE_NAME}.tar.gz
    sudo docker load -i vmware-kubernetes-${K8S_VERSION}/kubernetes-${K8S_VERSION}/images/pause-${PAUSE}.tar.gz
    # For single node control planes  and coredns
    sudo docker tag vmware/etcd:${ETCD}_vmware.3 vmware/etcd:${ETCD_SOLO}
    sudo docker tag vmware/coredns:${COREDNS}_vmware.3 vmware/coredns:${COREDNS_SOLO}

    #This file is created once to not keep reloading images
    touch vmware-kubernetes-${K8S_VERSION}/images-installed.txt
else
    echo "Images have already been loaded"

fi

if [ "$K8S_AUTOMATED" == "1" ]
then
    echo "Completed installing binaries"
else
    echo "Please copy the full kubeadm join command from your control plane"

    read varcontrolplane

    sudo ${varcontrolplane}
fi
