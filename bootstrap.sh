#!/bin/bash

set -euo pipefail

CONTROL_NODES=1
WORKER_NODES=1
TOTAL_NODES=$(($CONTROL_NODES+$WORKER_NODES))
DISTRO="focal" # Ubuntu 20.04 focal (lts)
USERNAME="kubernetes"
HOME_DIR="/home/$USERNAME"

MULTIPASS=$(which multipass)

clear

echo -e "------------------------------------------------------------------"
echo -e
echo -e "███╗░░░███╗██╗░░░██╗██╗░░░░░████████╗██╗  ██╗░░██╗░█████╗░░██████╗"
echo -e "████╗░████║██║░░░██║██║░░░░░╚══██╔══╝██║  ██║░██╔╝██╔══██╗██╔════╝"
echo -e "██╔████╔██║██║░░░██║██║░░░░░░░░██║░░░██║  █████═╝░╚█████╔╝╚█████╗░"
echo -e "██║╚██╔╝██║██║░░░██║██║░░░░░░░░██║░░░██║  ██╔═██╗░██╔══██╗░╚═══██╗"
echo -e "██║░╚═╝░██║╚██████╔╝███████╗░░░██║░░░██║  ██║░╚██╗╚█████╔╝██████╔╝"
echo -e "╚═╝░░░░░╚═╝░╚═════╝░╚══════╝░░░╚═╝░░░╚═╝  ╚═╝░░╚═╝░╚════╝░╚═════╝░"
echo -e
echo -e "          Multipass Kubernetes Cluster Bootsrapper v0.2"
echo -e
echo -e "------------------------------------------------------------------"

# Launch Kubernetes master node instances
echo -e "\n\nInitializing Multipass instances ($TOTAL_NODES)..."
echo -e "---"
for (( NODE=1; NODE<=$CONTROL_NODES; NODE++ ))
do
    $MULTIPASS launch --name control-0$NODE --cpus 2 --mem 2048m --disk 5G --cloud-init cloud-config.yaml $DISTRO
done

# Launch Kubernetes worker node instances
for (( NODE=1; NODE<=$WORKER_NODES; NODE++ ))
do
    $MULTIPASS launch --name worker-0$NODE --cpus 2 --mem 2048m --disk 5G --cloud-init cloud-config.yaml $DISTRO
done

# Boostrap Kubernetes cluster with kubeadm
echo -e "\n\nBootstrapping Kubernetes cluster..."
echo -e "---"
$MULTIPASS exec control-01 -- sudo kubeadm init
$MULTIPASS exec control-01 -- sudo mkdir -p $HOME_DIR/.kube
$MULTIPASS exec control-01 -- sudo cp -i /etc/kubernetes/admin.conf $HOME_DIR/.kube/config
$MULTIPASS exec control-01 -- sudo chown -R $USERNAME:$USERNAME $HOME_DIR/.kube

# Install .kube/config onto local system from cluster
export KUBECONFIG=$($MULTIPASS exec control-01 -- sudo cat $HOME_DIR/.kube/config)
mkdir -p $HOME/.kube
echo $KUBECONFIG > $HOME_DIR/kube/config

# Generate kubeadm token and store cluster join strings.
WORKER_NODE_JOIN_STRING=$($MULTIPASS exec control-01 -- sudo kubeadm token create --print-join-command)
CONTROL_NODE_JOIN_STRING="$WORKER_NODE_JOIN_STRING--control-plane"

## Join additional control nodes to the Kubernetes cluster if control node count > 1
if [ $CONTROL_NODES -gt 1 ]
then
    echo -e "\n\nJoining addtional control-plane nodes to the cluster ($(($CONTROL_NODES-1)))..."
    echo -e "---"
    for (( NODE=2; NODE<=$CONTROL_NODES; NODE++ ))
    do
        $MULTIPASS exec control-0$NODE -- sudo $CONTROL_NODE_JOIN_STRING
        $MULTIPASS exec control-0$NODE -- sudo mkdir -p $HOME_DIR/.kube
        $MULTIPASS exec control-0$NODE -- sudo cp /etc/kubernetes/admin.conf $HOME_DIR/.kube/config
        $MULTIPASS exec control-0$NODE -- sudo chown -R $USERNAME:$USERNAME $HOME_DIR/.kube
    done
fi

## Join all worker nodes to the Kubernetes cluster.
echo -e "\n\nJoining worker nodes to the cluster ($WORKER_NODES)..."
echo -e "---"
for (( NODE=1; NODE<=$WORKER_NODES; NODE++ ))
do
    $MULTIPASS exec worker-0$NODE -- sudo $WORKER_NODE_JOIN_STRING
    # Tag worker nodes role with 'node-role.kubernetes.io/worker=worker'
    $MULTIPASS exec control-01 -- sudo -u $USERNAME kubectl label node worker-0$NODE node-role.kubernetes.io/worker=worker
done

echo -e "\n\nPerforming final checks and balances..."
echo -e "---"
sleep 20 # This is just to wait for worker nodes to transition to a 'Ready' state change this later to perform check against real node status.
echo -e "Done!"

# List all Multipass instances
echo -e "\n\nListing Multipass instances:"
echo -e "---"
$MULTIPASS list

# List all Kubernetes cluster nodes (verbose)
echo -e "\n\nListing Kubernetes cluster nodes:"
echo -e "---"
$MULTIPASS exec control-01 -- sudo -u $USERNAME kubectl get nodes -Ao wide

##### TO DO:
# - Fix failing apt-update to pull google k8s repo/packages for kube* tools - apt repo times out or is rate limited?
# - Fix single endpoint issue for clusters with multiple control-plane nodes.
# - Add check to obtain node status poll every 5 seconds until 'Ready' state before proceeding.
# - Add switches to script to specify control-plane node count and worker node count (default launch be 1 control-plane node and 1 worker node if no swith specified)
