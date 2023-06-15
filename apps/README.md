# Tokamak Optimism Applications

## List

- Gateway
- Block Explorer

## Gateway

### Configuration

Check configuraion files at `gateway/kustomize/overlays/aws/<cluster_name>`

* config.json: gateway configuration
* ingress.yml: aws loadbalancer configuration

### Fargate Profile(AWS)

If you want to deploy to AWS EKS, argocd profile should be created.
Check `aws cli` before run next command.

```
eksctl create fargateprofile \
    --cluster ${cluster_name} \
    --region ${region} \
    --name app-blockscout \
    --namespace app-blockscout
```

## Run

Use `tokamak-apps.sh` script to run gateway.

```
Usage:
  ./tokamak-apps.sh [command]
    * commands
      - create
         - list
         - [app_name] [cluster_name] [env_name]
      - delete
         - list|[app_name]
      - tag|tags [app_name]
      - update
         - list
         - [app_name] config|[tag_name]|undo|list
      - reload(restart)
         - list|all|[app_name]

Examples:
 ./tokamak-apps.sh create list
 ./tokamak-apps.sh create gateway hardhat local
 ./tokamak-apps.sh create gateway goerli-nightly aws
 ./tokamak-apps.sh delete list
 ./tokamak-apps.sh delete gateway
 ./tokamak-apps.sh tag gateway
 ./tokamak-apps.sh update list
 ./tokamak-apps.sh update gateway config
 ./tokamak-apps.sh update gateway latest
 ./tokamak-apps.sh update gateway undo
 ./tokamak-apps.sh update gateway list
 ./tokamak-apps.sh reload list
 ./tokamak-apps.sh reload all
 ./tokamak-apps.sh reload gateway
```

**deploy goerli-nightly gateway to local cluster**

```
$ ./tokamak-apps.sh create gateway goerli-nightly local
```

**deploy goerli-nightly gateway to aws cluster**

```
$ ./tokamak-apps.sh create gateway goerli-nightly aws
```

**remove gateway to aws cluster**

```
$ ./tokamak-apps.sh delete gateway
```

**update configuration**

modify config.json

```
$ ./tokamak-apps.sh update gateway config
$ ./tokamak-apps.sh reload gateway
```

**update image**

get tags

```
./tokamak-apps.sh tag gateway
latest(2022-10-26T08:49:38.712264Z)
nightly-0.2.33(2022-10-26T13:39:53.22181Z)
nightly(2022-10-26T13:39:52.709211Z)
nightly-0.2.32(2022-10-26T13:22:26.111754Z)
release-0.2.31(2022-10-26T08:49:39.004183Z)
nightly-0.2.31(2022-10-26T08:45:20.796642Z)
nightly-0.2.30(2022-10-26T05:40:36.75239Z)
nightly-0.2.29(2022-10-26T05:36:55.016232Z)
nightly-0.2.28(2022-10-26T05:35:44.794981Z)
release-0.2.27(2022-10-25T02:27:24.389989Z)
```

update image

```
./tokamak-apps.sh update gateway release-0.2.31
```

**rollback image**

```
./tokamak-apps.sh update gateway undo
```
