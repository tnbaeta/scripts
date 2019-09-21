K8S_VERSION="v1.15.1+vmware.1"

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

yum -y remove cri-tools-${CRI_TOOLS}-1.el7.vmware.1
yum -y remove kubernetes-cni-${CNI_VERSION}-1.el7.vmware.1
yum -y remove kubectl-${RPM_NAME}-1.el7.vmware.1
yum -y remove kubelet-${RPM_NAME}-1.el7.vmware.1
yum -y remove kubeadm-${RPM_NAME}-1.el7.vmware.1
