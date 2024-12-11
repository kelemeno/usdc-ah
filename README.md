# USDC Asset Handler

## Setup

```
git submodule init
git submodule update --init --recursive

cd lib/usdc-token
yarn set version 1.22.19
yarn
yarn install

cd lib/era-contracts
yarn 
git submodule init
git submodule update --init --recursive
```

## Run tests

testing supports foundry and zksync foundry for the L2 part. The L2 part is also tested with normal foundry, as it is much faster in L2UsdcL1Test.

```
forge test --no-match-contract L2UsdcTest
```

```
forge test --zksync --match-contract L2UsdcTest
```

## Planned migration from USDC shared bridge

[Previous bridge implementation](https://github.com/matter-labs/usdc-bridge/blob/main/src/L1USDCBridge.sol)

