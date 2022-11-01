# Tokamak Optimism Applications

## List

- Gateway
- Block Explorer

## Gateway

### Configuration

**config.json**

create `config.json` file at `gateway/kustomize/config/` or copy template configuraion files like `config.xxxx.json`

```
cd gateway/kustomize/config
cp config.aws-goerli-nightly.json config.json
```

**.env**

create `.env` file at `gateway/kustomize/overlays/aws/` to deploy to aws cluster(eks) or copy template env files like `.env.xxx`

```
cd gateway/kustomize/overlays
cp .env.goerli-nightly .env
```

## Run

Use `tokamak-apps.sh` script to run gateway.

```
./tokamak-apps.sh help
Usage:
  ./tokamak-apps.sh [command] [app_name] [env_name]
    * command list
      - create
         - list|all
         - [app_name] [env_name]
      - delete
         - list|all|[app_name]
      - tag|tags [app_name]
      - update
         - list
         - [app_name] config|[tag_name]|undo|list
      - reload(restart)
         - list|all|[app_name]

Examples:
 ./tokamak-apps.sh create list
 ./tokamak-apps.sh create gateway local
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

**deploy gateway to local cluster**

```
$ ./tokamak-apps.sh create gateway local
```

**deploy gateway to aws cluster**

```
$ ./tokamak-apps.sh create gateway aws
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
