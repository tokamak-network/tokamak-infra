# Deposit and Withdraw ETH into Optimism

## Editing .env

Copy `.env.example` file to `.env` and modify it.

```sh
cp .env.example .env

<edit> .env
```

## Run test

**Install Packages

```sh
yarn

or

yarn install
```

**Transfering ETH from L1 to L2**

```sh
yarn deposit
```

**Transfering ETH from L2 to L1**

```sh
yarn withdraw
```
