// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {L2UsdcAssetHandler} from "../src/L2UsdcAssetHandler.sol";
import {SharedL2ContractDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-in-l1-context/_SharedL2ContractDeployer.sol";
import {TokenDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedTokenDeployer.t.sol";
import {L2AssetRouter} from "lib/era-contracts/l1-contracts/contracts/bridge/asset-router/L2AssetRouter.sol";
import {L2_NATIVE_TOKEN_VAULT_ADDR, L2_ASSET_ROUTER_ADDR} from "lib/era-contracts/l1-contracts/contracts/common/L2ContractAddresses.sol";
import {IL2NativeTokenVault} from "lib/era-contracts/l1-contracts/contracts/bridge/ntv/IL2NativeTokenVault.sol";
import {DataEncoding} from "lib/era-contracts/l1-contracts/contracts/common/libraries/DataEncoding.sol";

import {TestnetERC20Token} from "lib/era-contracts/l1-contracts/contracts/dev-contracts/TestnetERC20Token.sol";
import {AddressAliasHelper} from "lib/era-contracts/l1-contracts/contracts/vendor/AddressAliasHelper.sol";

// see L2Erc20TestAbstract for example of structure
abstract contract L2UsdcTestAbstract is Test, SharedL2ContractDeployer, TokenDeployer {

    bytes32 public usdcAssetId = keccak256(abi.encode(L1_CHAIN_ID, L1_TOKEN_ADDRESS));
    address public usdc;
    address public l1AssetHandler;
    address public deploymentTracker;
    address public recipient = makeAddr(string(abi.encode("recipient")));
    L2UsdcAssetHandler public l2AssetHandler;
    uint256 public eraZKChainId;


    function deployTokens() public { //virtual override {
        _setConfig();
        _deployTokens();
    }

    function deployL2UsdcAssetHandler() public {
        usdc = tokens[0];
        deploymentTracker = makeAddr("deploymentTracker");
        // 
        usdcAssetId = DataEncoding.encodeAssetId(block.chainid, usdc, address(deploymentTracker));
        l2AssetHandler = new L2UsdcAssetHandler(usdcAssetId, L1_CHAIN_ID,  address(deploymentTracker));
        vm.prank(AddressAliasHelper.applyL1ToL2Alias(l1AssetRouter));
        l2AssetRouter.setAssetHandlerAddress(L1_CHAIN_ID, usdcAssetId, address(l2AssetHandler));
        // vm.prank(deploymentTracker.owner());
        // deploymentTracker.setAddresses(address(l1AssetHandler), l2AssetHandler, l2UsdcAddress);
        // deploymentTracker.registerTokenOnL1();
        vm.prank(AddressAliasHelper.applyL1ToL2Alias(deploymentTracker));
        l2AssetHandler.setTokenAddress(usdc, false);
        TestnetERC20Token(usdc).mint(address(l2AssetHandler), 100000000);
        // stdstore
        //     .target(address(l1AssetHandler))
        //     .sig(l1AssetHandler.chainBalance.selector)
        //     .with_key(eraZKChainId)
        //     .checked_write(100000000);
    }

    function _setConfig() internal {
        vm.setEnv("L1_CONFIG", "/test/foundry/l1/integration/deploy-scripts/script-config/config-deploy-l1.toml");
        vm.setEnv("L1_OUTPUT", "/test/foundry/l1/integration/deploy-scripts/script-out/output-deploy-l1.toml");
        vm.setEnv(
            "ZK_CHAIN_CONFIG",
            "/test/foundry/l1/integration/deploy-scripts/script-config/config-deploy-zk-chain-era.toml"
        );
        vm.setEnv(
            "ZK_CHAIN_OUT",
            "/test/foundry/l1/integration/deploy-scripts/script-out/output-deploy-zk-chain-era.toml"
        );
    }

    function performDeposit(address depositor, address receiver, uint256 amount) internal {
        // usdcAssetHandler.deposit(amount);
        // uint256 l1ChainId = L1_CHAIN_ID;
        bytes memory transferData = abi.encode(depositor, receiver, amount);
        vm.prank(aliasedL1AssetRouter);
        console.log("finalizeDeposit called");
        console.log("code size", L2_ASSET_ROUTER_ADDR.code.length);
        L2AssetRouter(L2_ASSET_ROUTER_ADDR).finalizeDeposit(
            L1_CHAIN_ID,
            usdcAssetId,
            transferData
            // abi.encode(depositor, amount, receiver, "", L1_TOKEN_ADDRESS)
        );
    }

    function initializeTokenByDeposit() internal returns (address l2TokenAddress) {
        performDeposit(makeAddr("someDepositor"), makeAddr("someReceiver"), 1);

        l2TokenAddress = IL2NativeTokenVault(L2_NATIVE_TOKEN_VAULT_ADDR).l2TokenAddress(L1_TOKEN_ADDRESS);
        if (l2TokenAddress == address(0)) {
            revert("Token not initialized");
        }
    }

    function test_shouldFinalizeERC20Deposit() public {
        address depositor = makeAddr("depositor");
        address receiver = makeAddr("receiver");

        performDeposit(depositor, receiver, 100);

        // address l2TokenAddress = IL2NativeTokenVault(L2_NATIVE_TOKEN_VAULT_ADDR).l2TokenAddress(L1_TOKEN_ADDRESS);

        // assertEq(BridgedStandardERC20(l2TokenAddress).balanceOf(receiver), 100);
        // assertEq(BridgedStandardERC20(l2TokenAddress).totalSupply(), 100);
        // assertEq(BridgedStandardERC20(l2TokenAddress).name(), TOKEN_DEFAULT_NAME);
        // assertEq(BridgedStandardERC20(l2TokenAddress).symbol(), TOKEN_DEFAULT_SYMBOL);
        // assertEq(BridgedStandardERC20(l2TokenAddress).decimals(), TOKEN_DEFAULT_DECIMALS);
    }
}
