// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, StdStorage, stdStorage} from "forge-std/Test.sol";
import {L1UsdcAssetHandler} from "../src/L1UsdcAssetHandler.sol";
import {L1UsdcAssetDeploymentTracker} from "../src/L1UsdcAssetDeploymentTracker.sol";
import {L1ContractDeployer, FinalizeL1DepositParams, L2TransactionRequestTwoBridgesOuter} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedL1ContractDeployer.t.sol";
import {TokenDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedTokenDeployer.t.sol";
import {ZKChainDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedZKChainDeployer.t.sol";
import {L2TxMocker} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/_SharedL2TxMocker.t.sol";
import {REQUIRED_L2_GAS_PRICE_PER_PUBDATA} from "lib/era-contracts/l1-contracts/contracts/common/Config.sol";
// import {IL1Nullifier} from "lib/era-contracts/l1-contracts/contracts/bridge/interfaces/IL1Nullifier.sol";
// import {FinalizeL1DepositParams} from "lib/era-contracts/l1-contracts/contracts/bridge/L1Nullifier.sol";
import {DataEncoding} from "lib/era-contracts/l1-contracts/contracts/common/libraries/DataEncoding.sol";
import {BridgeHelper} from "lib/era-contracts/l1-contracts/contracts/bridge/BridgeHelper.sol";
import {ETH_TOKEN_ADDRESS} from "lib/era-contracts/l1-contracts/contracts/common/Config.sol";
import {L2_ASSET_ROUTER_ADDR} from "lib/era-contracts/l1-contracts/contracts/common/L2ContractAddresses.sol";
import {IAssetRouterBase} from "lib/era-contracts/l1-contracts/contracts/bridge/asset-router/IAssetRouterBase.sol";
import {IBridgehub} from "lib/era-contracts/l1-contracts/contracts/bridgehub/IBridgehub.sol";
import {L2TransactionRequestDirect} from "lib/era-contracts/l1-contracts/contracts/bridgehub/IBridgehub.sol";
import {NEW_ENCODING_VERSION} from "lib/era-contracts/l1-contracts/contracts/bridge/asset-router/IAssetRouterBase.sol";
import {IERC20} from "@openzeppelin/contracts-v4/token/ERC20/IERC20.sol";
import {TxStatus} from "lib/era-contracts/l1-contracts/contracts/common/Messaging.sol";

// import {FiatTokenV2_2} from "lib/usdc-token/contracts/v2/FiatTokenV2.sol";
import {TestnetERC20Token} from "lib/era-contracts/l1-contracts/contracts/dev-contracts/TestnetERC20Token.sol";

// see L2Erc20TestAbstract for example of structure
contract L1UsdcAssetHandlerTest is Test, L1ContractDeployer, ZKChainDeployer, TokenDeployer, L2TxMocker {
    using stdStorage for StdStorage;

    uint256 constant public TEST_USERS_COUNT = 10;
    address[] public users;
    address[] public l2ContractAddresses;
    bytes32 public l2TokenAssetId;
    address public tokenL1Address;
    // generate MAX_USERS addresses and append it to users array

    address public usdc;
    L1UsdcAssetHandler public l1AssetHandler;
    L1UsdcAssetDeploymentTracker public deploymentTracker;
    bytes32 public usdcAssetId;
    address public recipient = makeAddr(string(abi.encode("recipient")));
    address l2AssetHandler = makeAddr(string(abi.encode("l2AssetHandler")));
    address l2UsdcAddress = makeAddr(string(abi.encode("l2UsdcAddress")));

    function _generateUserAddresses() internal {
        require(users.length == 0, "Addresses already generated");

        for (uint256 i = 0; i < TEST_USERS_COUNT; ++i) {
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

        for (uint256 i = 0; i < zkChainIds.length; ++i) {
            address contractAddress = makeAddr(string(abi.encode("contract", i)));
            l2ContractAddresses.push(contractAddress);

            _addL2ChainContract(zkChainIds[i], contractAddress);
        }
    }

    function setUp() public {
        prepare();
        // usdc = new FiatTokenV2_2();
        usdc = tokens[0];
        deploymentTracker = new L1UsdcAssetDeploymentTracker(address(bridgehub), address(sharedBridge), usdc);
        usdcAssetId = DataEncoding.encodeAssetId(block.chainid, usdc, address(deploymentTracker));
        l1AssetHandler = new L1UsdcAssetHandler(address(sharedBridge), usdcAssetId, address(deploymentTracker));
        vm.prank(sharedBridge.owner());
        sharedBridge.setAssetDeploymentTracker(bytes32(uint256(uint160(usdc))), address(deploymentTracker));
        vm.prank(deploymentTracker.owner());
        deploymentTracker.setAddresses(address(l1AssetHandler), l2AssetHandler, l2UsdcAddress);
        deploymentTracker.registerTokenOnL1();
        TestnetERC20Token(usdc).mint(address(l1AssetHandler), 100000000);
        stdstore
            .target(address(l1AssetHandler))
            .sig(l1AssetHandler.chainBalance.selector)
            .with_key(eraZKChainId)
            .checked_write(100000000);
    }

    function depositToL1() public {
        uint256 balanceBefore = TestnetERC20Token(usdc).balanceOf(recipient);

        console.log("usdcAssetId");
        console.logBytes32(usdcAssetId);
        vm.mockCall(
            address(bridgehub),
            abi.encodeWithSelector(IBridgehub.proveL2MessageInclusion.selector),
            abi.encode(true)
        );
        uint256 chainId = eraZKChainId;
        bytes memory transferData = abi.encode(
            ETH_TOKEN_ADDRESS,
            recipient,
            100
        );

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
                    usdcAssetId,
                    transferData
                ),
                merkleProof: new bytes32[](0)
            })
        );
        uint256 balanceAfter = TestnetERC20Token(usdc).balanceOf(recipient);
        assertEq(balanceAfter - balanceBefore, 100);
    }

    function test_DepositToL1_Success() public {
        depositToL1();
    }

    function depositToL2() public {
        bytes memory secondBridgeCalldata = bytes.concat(
            NEW_ENCODING_VERSION,
            abi.encode(usdcAssetId, abi.encode(uint256(100), address(this)))
        );
        IERC20(usdc).approve(address(l1AssetHandler), 100);
        uint256 balanceBefore = TestnetERC20Token(usdc).balanceOf(address(this));
        
        bridgehub.requestL2TransactionTwoBridges{value: 250000000000100}(
            L2TransactionRequestTwoBridgesOuter({
                chainId: eraZKChainId,
                mintValue: 250000000000100,
                l2Value: 0,
                l2GasLimit: 1000000,
                l2GasPerPubdataByteLimit: REQUIRED_L2_GAS_PRICE_PER_PUBDATA,
                refundRecipient: address(0),
                secondBridgeAddress: address(sharedBridge),
                secondBridgeValue: 0,
                secondBridgeCalldata: secondBridgeCalldata
            })
        );
        uint256 balanceAfter = TestnetERC20Token(usdc).balanceOf(address(this));
        assertEq(balanceBefore - balanceAfter, 100);
    }

    function test_DepositToL2_Success() public {
        depositToL1();
       
    }

    function test_DepositToL2_RecoverFailedTransfer() public {
        depositToL1();
        depositToL2();

        bytes memory transferData = abi.encode(
            ETH_TOKEN_ADDRESS,
            recipient,
            100
        );
        bytes32 l2TxHash = keccak256("l2TxHash");
        uint256 l2BatchNumber = 5;
        uint256 l2MessageIndex = 0;
        uint16 l2TxNumberInBatch = 0;
        bytes32[] memory merkleProof = new bytes32[](1);
        bytes32 txDataHash = keccak256(bytes.concat(bytes1(0x01), abi.encode(address(this), usdcAssetId, transferData)));

        vm.mockCall(
            address(bridgehub),
            abi.encodeWithSelector(
                IBridgehub.proveL1ToL2TransactionStatus.selector,
                eraZKChainId,
                l2TxHash,
                l2BatchNumber,
                l2MessageIndex,
                l2TxNumberInBatch,
                merkleProof,
                TxStatus.Failure
            ),
            abi.encode(true)
        );

        // Set Deposit Happened
        vm.startBroadcast(address(bridgehub));
        sharedBridge.bridgehubConfirmL2Transaction({
            _chainId: eraZKChainId,
            _txDataHash: txDataHash,
            _txHash: l2TxHash
        });
        vm.stopBroadcast();

        vm.startBroadcast();
        l1Nullifier.bridgeRecoverFailedTransfer({
            _chainId: eraZKChainId,
            _depositSender: address(this),
            _assetId: usdcAssetId,
            _assetData: transferData,
            _l2TxHash: l2TxHash,
            _l2BatchNumber: l2BatchNumber,
            _l2MessageIndex: l2MessageIndex,
            _l2TxNumberInBatch: l2TxNumberInBatch,
            _merkleProof: merkleProof
        });
        vm.stopBroadcast();
    }
}
