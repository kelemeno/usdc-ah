// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable-v4/access/Ownable2StepUpgradeable.sol";

import {IL1AssetDeploymentTracker} from "l1-contracts/contracts/bridge/interfaces/IL1AssetDeploymentTracker.sol";
import {IAssetRouterBase} from "l1-contracts/contracts/bridge/asset-router/IAssetRouterBase.sol";
import {DataEncoding} from "l1-contracts/contracts/common/libraries/DataEncoding.sol";
import {IBridgehub, L2TransactionRequestTwoBridgesInner} from "l1-contracts/contracts/bridgehub/IBridgehub.sol";

// import { } from "l1-contracts/contracts/bridge/L1BridgeContractErrors.sol";
import {NoEthAllowed, WrongCounterPart, NotOwner, NoEthAllowed, OnlyBridgehub} from "l1-contracts/contracts/bridgehub/L1BridgehubErrors.sol";
import {TWO_BRIDGES_MAGIC_VALUE} from "l1-contracts/contracts/common/Config.sol";
import {L2_BRIDGEHUB_ADDR} from "l1-contracts/contracts/common/L2ContractAddresses.sol";

import {IUsdcAssetHandlerBase} from "./IUsdcAssetHandlerBase.sol";
import {AssetHandlerNotSet} from "./Errors.sol";

/// @dev The encoding version of the data.
bytes1 constant USDC_DEPLOYMENT_TRACKER_ENCODING_VERSION = 0x01;

/// @author Matter Labs
/// @custom:security-contact security@matterlabs.dev
/// @dev Vault handling bridging of USDC
/// @dev Designed for use with a proxy for upgradability.
contract L1UsdcAssetDeploymentTracker is IL1AssetDeploymentTracker, Ownable2StepUpgradeable {
    /// @dev Bridgehub smart contract that handles communication with its counterparts on L2s
    IBridgehub public immutable BRIDGE_HUB;

    /// @dev L1 Shared Bridge smart contract that handles communication with its counterparts on L2s
    IAssetRouterBase public immutable ASSET_ROUTER;

    address public immutable L1_USDC_ADDRESS;

    bytes32 public immutable USDC_ASSET_ID;

    address public l1AssetHandler; // To be deployed at predefined address

    address public assetHandlerOnCounterpart; // To be deployed at predefined address

    address public l2UsdcAddress;

    mapping(uint256 chainId => address l2UsdcAddress) public chainL2UsdcAddress;

    /// @notice Checks that the message sender is the bridgehub.
    modifier onlyBridgehub() {
        if (msg.sender != address(BRIDGE_HUB)) {
            revert OnlyBridgehub(msg.sender, address(BRIDGE_HUB));
        }
        _;
    }

    constructor(address _bridgehub, address _assetRouter, address _usdcToken, address _assetHandlerOnCounterpart) {
        _disableInitializers();
        BRIDGE_HUB = IBridgehub(_bridgehub);
        ASSET_ROUTER = IAssetRouterBase(_assetRouter);
        L1_USDC_ADDRESS = _usdcToken;
        USDC_ASSET_ID = DataEncoding.encodeAssetId(block.chainid, L1_USDC_ADDRESS, address(this));
    }

    function setAddresses(address _l1AssetHandler, address _assetHandlerOnCounterpart) external onlyOwner {
        l1AssetHandler = _l1AssetHandler;
        assetHandlerOnCounterpart = _assetHandlerOnCounterpart;
    }

    function setL2UsdcAddress(uint256 _chainId, address _l2UsdcAddress) external onlyOwner {
        chainL2UsdcAddress[_chainId] = _l2UsdcAddress;
    }

    /// @notice Registers a native token address for the vault.
    /// @dev It does not perform any checks for the correctnesss of the token contract.
    function registerTokenOnL1() external {
        ASSET_ROUTER.setAssetHandlerAddressThisChain(bytes32(uint256(uint160(L1_USDC_ADDRESS))), l1AssetHandler);
        IUsdcAssetHandlerBase(l1AssetHandler).setTokenAddress(L1_USDC_ADDRESS);
    }

    /// @notice The function responsible for registering the L2 tokenAddress on the L2AssetHandler.
    /// @dev The function is called by the Bridgehub contract during the `Bridgehub.requestL2TransactionTwoBridges`.
    /// @dev Since the L2 settlement layers `_chainId` might potentially have ERC20 tokens as native assets,
    /// there are two ways to perform the L1->L2 transaction:
    /// - via the `Bridgehub.requestL2TransactionDirect`. However, this would require the CTMDeploymentTracker to
    /// handle the ERC20 balances to be used in the transaction.
    /// - via the `Bridgehub.requestL2TransactionTwoBridges`. This way it will be the sender that provides the funds
    /// for the L2 transaction.
    /// The second approach is used due to its simplicity even though it gives the sender slightly more control over the call:
    /// `gasLimit`, etc.
    /// @param _chainId the chainId of the chain
    /// @param _originalCaller the previous message sender
    // / @param _data the data of the transaction
    // slither-disable-next-line locked-ether
    function bridgehubDeposit(
        uint256 _chainId,
        address _originalCaller,
        uint256,
        bytes calldata
    ) external payable onlyBridgehub returns (L2TransactionRequestTwoBridgesInner memory request) {
        if (msg.value != 0) {
            revert NoEthAllowed();
        }

        if (_originalCaller != owner()) {
            revert NotOwner(_originalCaller, owner());
        }

        address registeredL2UsdcAddress = chainL2UsdcAddress[_chainId];
        address token = registeredL2UsdcAddress != address(0) ? registeredL2UsdcAddress : l2UsdcAddress;
        request = _registerTokenAddressOnL2AssetHandler(_chainId, token);
    }

    /// @notice The function called by the Bridgehub after the L2 transaction has been initiated.
    /// @dev Not used in this contract. In case the transaction fails, we can just re-try it.
    function bridgehubConfirmL2Transaction(uint256 _chainId, bytes32 _txDataHash, bytes32 _txHash) external {}

    // for registering the L2AssetHandler in the L2AssetRouter
    function bridgeCheckCounterpartAddress(
        uint256,
        bytes32,
        address,
        address _assetHandlerAddressOnCounterpart
    ) external view override {
        if (_assetHandlerAddressOnCounterpart != assetHandlerOnCounterpart) {
            revert WrongCounterPart(_assetHandlerAddressOnCounterpart, assetHandlerOnCounterpart);
        }
    }

    /// @notice Used to register the ctm asset in L2 Bridgehub.
    /// @param _chainId the chainId of the chain
    function _registerTokenAddressOnL2AssetHandler(
        // solhint-disable-next-line no-unused-vars
        uint256 _chainId,
        address _tokenAddress
    ) internal view returns (L2TransactionRequestTwoBridgesInner memory request) {
        bytes memory l2TxCalldata = abi.encodeCall(
            IUsdcAssetHandlerBase.setTokenAddress,
            (_tokenAddress)
        );

        if (assetHandlerOnCounterpart == address(0)) {
            revert AssetHandlerNotSet();
        }
        request = L2TransactionRequestTwoBridgesInner({
            magicValue: TWO_BRIDGES_MAGIC_VALUE,
            l2Contract: assetHandlerOnCounterpart,
            l2Calldata: l2TxCalldata,
            factoryDeps: new bytes[](0),
            // The `txDataHash` is typically used in usual ERC20 bridges to commit to the transaction data
            // so that the user can recover funds in case the bridging fails on L2.
            // However, this contract uses the `requestL2TransactionTwoBridges` method just to perform an L1->L2 transaction.
            // We do not need to recover anything and so `bytes32(0)` here is okay.
            txDataHash: bytes32(0)
        });
    }
}
