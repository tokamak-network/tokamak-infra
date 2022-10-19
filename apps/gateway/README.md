# Tokamak Optimism Gateway

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
