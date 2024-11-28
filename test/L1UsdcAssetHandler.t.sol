// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {L1UsdcAssetHandler} from "../src/L1UsdcAssetHandler.sol";
import {L1ContractDeployer, FinalizeL1DepositParams} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedL1ContractDeployer.t.sol";
import {TokenDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedTokenDeployer.t.sol";
import {ZKChainDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedZKChainDeployer.t.sol";
import {L2TxMocker} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedL2TxMocker.t.sol";
import {IL1Nullifier} from "lib/era-contracts/l1-contracts/contracts/bridge/interfaces/IL1Nullifier.sol";
// import {FinalizeL1DepositParams} from "lib/era-contracts/l1-contracts/contracts/bridge/L1Nullifier.sol";
import {DataEncoding} from "lib/era-contracts/l1-contracts/contracts/common/libraries/DataEncoding.sol";
import {BridgeHelper} from "lib/era-contracts/l1-contracts/contracts/bridge/BridgeHelper.sol";
import {ETH_TOKEN_ADDRESS} from "lib/era-contracts/l1-contracts/contracts/common/Config.sol";
import {L2_ASSET_ROUTER_ADDR} from "lib/era-contracts/l1-contracts/contracts/common/L2ContractAddresses.sol";
import {IAssetRouterBase} from "lib/era-contracts/l1-contracts/contracts/bridge/asset-router/IAssetRouterBase.sol";
import {IBridgehub} from "lib/era-contracts/l1-contracts/contracts/bridgehub/IBridgehub.sol";

// see L2Erc20TestAbstract for example of structure
contract L1UsdcAssetHandlerTest is Test, L1ContractDeployer, ZKChainDeployer, TokenDeployer, L2TxMocker {
    uint256 constant TEST_USERS_COUNT = 10;
    address[] public users;
    address[] public l2ContractAddresses;
    bytes32 public l2TokenAssetId;
    address public tokenL1Address;
    // generate MAX_USERS addresses and append it to users array
    function _generateUserAddresses() internal {
        require(users.length == 0, "Addresses already generated");

        for (uint256 i = 0; i < TEST_USERS_COUNT; i++) {
            address newAddress = makeAddr(string(abi.encode("account", i)));
            users.push(newAddress);
        }
    }

    function prepare() public {
        _generateUserAddresses();

        _deployL1Contracts();
        _deployTokens();
        _registerNewTokens(tokens);

        _deployEra();
        // _deployHyperchain(ETH_TOKEN_ADDRESS);
        // _deployHyperchain(ETH_TOKEN_ADDRESS);
        // _deployHyperchain(tokens[0]);
        // _deployHyperchain(tokens[0]);
        // _deployHyperchain(tokens[1]);
        // _deployHyperchain(tokens[1]);

        for (uint256 i = 0; i < zkChainIds.length; i++) {
            address contractAddress = makeAddr(string(abi.encode("contract", i)));
            l2ContractAddresses.push(contractAddress);

            _addL2ChainContract(zkChainIds[i], contractAddress);
        }
    }

    function setUp() public {
        prepare();
    }

    function depositToL1(address _tokenAddress) public {
        vm.mockCall(
            address(bridgehub),
            abi.encodeWithSelector(IBridgehub.proveL2MessageInclusion.selector),
            abi.encode(true)
        );
        uint256 chainId = eraZKChainId;
        l2TokenAssetId = DataEncoding.encodeNTVAssetId(chainId, _tokenAddress);
        bytes memory transferData = DataEncoding.encodeBridgeMintData({
            _originalCaller: ETH_TOKEN_ADDRESS,
            _remoteReceiver: address(this),
            _originToken: ETH_TOKEN_ADDRESS,
            _amount: 100,
            _erc20Metadata: BridgeHelper.getERC20Getters(_tokenAddress, chainId)
        });
        l1Nullifier.finalizeDeposit(
            FinalizeL1DepositParams({
                chainId: chainId,
                l2BatchNumber: 1,
                l2MessageIndex: 1,
                l2Sender: L2_ASSET_ROUTER_ADDR,
                l2TxNumberInBatch: 1,
                message: abi.encodePacked(
                    IAssetRouterBase.finalizeDeposit.selector,
                    chainId,
                    l2TokenAssetId,
                    transferData
                ),
                merkleProof: new bytes32[](0)
            })
        );
        tokenL1Address = l1NativeTokenVault.tokenAddress(l2TokenAssetId);
    }

    function test_DepositToL1_Success() public {
        depositToL1(ETH_TOKEN_ADDRESS);
    }
}
