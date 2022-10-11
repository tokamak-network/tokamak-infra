# Kubernetes
Resources for running the tokamak network based on kubernetes

## Directory Strcture
```
kustomize
├─ bases: kubernetes bases resource like statefulset, deployment, service, etc
├─ envs: env files and kustomize file to make kubernetes configmap
├─ overlays: overlays set entire kubernetes resource and it can override other resources
└─ scripts: scripts and kustomize file to make kubernetes configmap
```

## Prerequisites
- `kubectl` **Minimum version v1.20** [Install notes](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-on-linux)
- `minikube` from a [minikube page](https://minikube.sigs.k8s.io/docs/start/)
- Docker

## Configuration
There are resources in `kustomize/envs`, `kustomize/overlays` for each environment. First environment is `local`.

### local
Local is for local network test. It consists of one `l1`, one `l2`, one `data-transport-layer`, one `deployer`, one `batch-submitter` and one `relayer`.

You can set the configuration by editing `*.env` files in `kustomize/envs/local`.

You must create `secret.env` in by referencing `secret.env.example`.

## Run
This is an example of `local`.
### create a cluster
first,
```
cd k8s
```

minikube
```
minikube start --cpus 4 --memory 16384
# customize the cps and the memory for your system
```
### deploy local resource
minikube
```
#kubectl apply -k ./kustomize/overlays/local_hardhat/
./tokamak-optimism.sh create local_hardhat
minikube tunnel # (keep terminal session)
```
### monitoring
```
kubectl get pods
```
If you can see all `Running` in the status, then everyting was successful!

This may take some time.(about 5m)
### endpoint
minikube

Minikube doesn't provide port forwarding. this network is up,
```
l1 endpoint: http://{svc external address}:9545
l2 endpoint: http://{svc external address}:8545, ws://{svc external address}:8546
dtl endpoint: http://{svc external address}:7878
```
You can get `svc external address` to follow below command.
```
kubectl get svc

# NAME              TYPE           CLUSTER-IP      **EXTERNAL-IP**     PORT(S)          AGE
# hello-minikube1   LoadBalancer   10.96.184.178   **10.96.184.178**   8080:30791/TCP   40s
```
Notice that minkube is accessible from only local system.

## Delete cluster
minikube
```
minikube delete
```
