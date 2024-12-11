// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

// solhint-disable gas-custom-errors

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

import {BridgedStandardERC20} from "lib/era-contracts/l1-contracts/contracts/bridge/BridgedStandardERC20.sol";
import {L2AssetRouter} from "lib/era-contracts/l1-contracts/contracts/bridge/asset-router/L2AssetRouter.sol";
import {IL2NativeTokenVault} from "lib/era-contracts/l1-contracts/contracts/bridge/ntv/IL2NativeTokenVault.sol";

import {UpgradeableBeacon} from "@openzeppelin/contracts-v4/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts-v4/proxy/beacon/BeaconProxy.sol";

import {L2_ASSET_ROUTER_ADDR, L2_NATIVE_TOKEN_VAULT_ADDR, L2_BRIDGEHUB_ADDR} from "contracts/common/L2ContractAddresses.sol";
import {ETH_TOKEN_ADDRESS, SETTLEMENT_LAYER_RELAY_SENDER} from "contracts/common/Config.sol";

import {AddressAliasHelper} from "lib/era-contracts/l1-contracts/contracts/vendor/AddressAliasHelper.sol";
import {BridgehubMintCTMAssetData} from "lib/era-contracts/l1-contracts/contracts/bridgehub/IBridgehub.sol";
import {IAdmin} from "lib/era-contracts/l1-contracts/contracts/state-transition/chain-interfaces/IAdmin.sol";
import {IL2AssetRouter} from "lib/era-contracts/l1-contracts/contracts/bridge/asset-router/IL2AssetRouter.sol";
import {IL1Nullifier} from "lib/era-contracts/l1-contracts/contracts/bridge/interfaces/IL1Nullifier.sol";
import {IL1AssetRouter} from "lib/era-contracts/l1-contracts/contracts/bridge/asset-router/IL1AssetRouter.sol";
import {IBridgehub} from "lib/era-contracts/l1-contracts/contracts/bridgehub/IBridgehub.sol";

import {IChainTypeManager} from "lib/era-contracts/l1-contracts/contracts/state-transition/IChainTypeManager.sol";
import {IZKChain} from "lib/era-contracts/l1-contracts/contracts/state-transition/chain-interfaces/IZKChain.sol";
import {SharedL2ContractDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-in-l1-context/_SharedL2ContractDeployer.sol";
import {SystemContractsArgs} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-in-l1-context/_SharedL2ContractL1DeployerUtils.sol";

// import {DeployUtils} from "lib/era-contracts/l1-contracts/deploy-scripts/DeployUtils.s.sol";
import {L2UsdcTestAbstract} from "./L2UsdcAbstract.t.sol";
import {SharedL2ContractL1DeployerUtils, DeployUtils} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-in-l1-context/_SharedL2ContractL1DeployerUtils.sol";

contract L2UsdcL1Test is Test, SharedL2ContractL1DeployerUtils, SharedL2ContractDeployer, L2UsdcTestAbstract {
    function setUp() public override(SharedL2ContractDeployer) {
        super.setUp();
        deployTokens();
        deployL2UsdcAssetHandler();
    }

    function test() internal virtual override(DeployUtils, SharedL2ContractL1DeployerUtils) {}

    function initSystemContracts(
        SystemContractsArgs memory _args
    ) internal virtual override(SharedL2ContractDeployer, SharedL2ContractL1DeployerUtils) {
        super.initSystemContracts(_args);
    }

    function deployL2Contracts(
        uint256 _l1ChainId
    ) public virtual override(SharedL2ContractDeployer, SharedL2ContractL1DeployerUtils) {
        super.deployL2Contracts(_l1ChainId);
    }
}
