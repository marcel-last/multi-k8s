# multi-k8s
Multipass Kubernetes Cluster Bootstrapper

A small tool written in bash that bootstrap and deploy a Kubernetes cluster Ubuntu's Multipass container service.

## How to use
1. Modify any variables in bootstrap.sh to suite your requirements.

2. Run bootstrap.sh script to deploy the Mutlipass/Kubernetes environment
```bash
$ bash bootstrap.sh
```

3. To destroy your Kubernetes cluster and Multipass container environment
```bash
# bash cleanup.sh
```

## Project Dependencies
- Bash
- Multipass

## To Do
- prompt for node count (both worker and controler nodes).
- prompt for versions or releases of Kubernetes to target.
