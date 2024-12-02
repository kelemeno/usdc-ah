// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {L1UsdcAssetHandler} from "../src/L1UsdcAssetHandler.sol";
import {SharedL2ContractDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-in-l1-context/_SharedL2ContractDeployer.sol";
import {TokenDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedTokenDeployer.t.sol";
import {L2AssetRouter} from "lib/era-contracts/l1-contracts/contracts/bridge/asset-router/L2AssetRouter.sol";
import {L2_NATIVE_TOKEN_VAULT_ADDR, L2_ASSET_ROUTER_ADDR} from "lib/era-contracts/l1-contracts/contracts/common/L2ContractAddresses.sol";
import {IL2NativeTokenVault} from "lib/era-contracts/l1-contracts/contracts/bridge/ntv/IL2NativeTokenVault.sol";

// see L2Erc20TestAbstract for example of structure
abstract contract L2UsdcTestAbstract is Test, SharedL2ContractDeployer, TokenDeployer {
    L1UsdcAssetHandler public usdcAssetHandler;
    bytes32 public usdcAssetId = keccak256(abi.encode(L1_CHAIN_ID, L1_TOKEN_ADDRESS));

    function setUp() public virtual override {
        _deployTokens();
    }

    function performDeposit(address depositor, address receiver, uint256 amount) internal {
        // usdcAssetHandler.deposit(amount);
        // uint256 l1ChainId = L1_CHAIN_ID;
        bytes memory transferData = abi.encode(depositor, amount, receiver);
        vm.prank(aliasedL1AssetRouter);
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

        address l2TokenAddress = IL2NativeTokenVault(L2_NATIVE_TOKEN_VAULT_ADDR).l2TokenAddress(L1_TOKEN_ADDRESS);

        // assertEq(BridgedStandardERC20(l2TokenAddress).balanceOf(receiver), 100);
        // assertEq(BridgedStandardERC20(l2TokenAddress).totalSupply(), 100);
        // assertEq(BridgedStandardERC20(l2TokenAddress).name(), TOKEN_DEFAULT_NAME);
        // assertEq(BridgedStandardERC20(l2TokenAddress).symbol(), TOKEN_DEFAULT_SYMBOL);
        // assertEq(BridgedStandardERC20(l2TokenAddress).decimals(), TOKEN_DEFAULT_DECIMALS);
    }
}
