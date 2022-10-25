# Tokamak Optimism Applications

## List

- Gateway
- Block Explorer

## Gateway

### Configuration

**config.json**

create `config.json` file at `gateway/kustomize/config/` or copy template configuraion files like `config.xxxx.json`

```
$ cd gateway/kustomize/config
$ cp config.aws-goerli-nightly.json config.json
```

**.env**

create `.env` file at `gateway/kustomize/overlays/aws/` to deploy to aws cluster(eks) or copy template env files like `.env.xxx`

```
$ cd gateway/kustomize/overlays
$ cp .env.goerli-nightly .env
```

## Run

Use `tokamak-apps.sh` script to run gateway.

```
$ ./tokamak-apps.sh help
Usage:
  ./tokamak-apps.sh [command] [app_name] [env_name]
    * command list
      - create [list|all|app_name env_name]
      - delete [list|all|app_name]
      - update [list|app_name]
      - reload(restart) [list|all|app_name]

Examples:
 ./tokamak-apps.sh create list
 ./tokamak-apps.sh create gateway local
 ./tokamak-apps.sh delete list
 ./tokamak-apps.sh delete gateway
 ./tokamak-apps.sh update list
 ./tokamak-apps.sh update gateway
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

**update gateway**

modify config.json

```
$ ./tokamak-apps.sh update gateway
$ ./tokamak-apps.sh reload gateway
```
