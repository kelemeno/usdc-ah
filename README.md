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

We will deploy the new asset handler separately from the bridge (and not upgrade the bridge). This is to reduce legacy code. We will transfer all funds to the new asset handler, except for the amount needed to cover outstanding withdrawals, and outstanding failed deposits. Simultaneously, we will stop the initiation of deposits both on the L2 and L1 side. 

To explicitly write down the steps: 
- deploy new asset handler. Grant minting rights for the L2 USDC token for the L2AssetHandler. 
- stop the initiation of deposits and withdrawals on the L1 and L2 sides. 
- After the 15 min L1 finality window, all L1->L2 deposits will have been processed, some of them might have failed. After this time, we will calculate the outstanding withdrawals and failed deposits amount.
- Revoke minting rights for the old L2SharedBridges on the L2 USDC tokens.
- Transfer all funds (minus the outstanding amount) to the new asset handler (function on L1UsdcBridge).
- Set chain balances (function on L1AssetHandler).
