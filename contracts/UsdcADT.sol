// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable-v4/access/Ownable2StepUpgradeable.sol";

import {IL1AssetDeploymentTracker} from "../interfaces/IL1AssetDeploymentTracker.sol";
import {IAssetRouterBase} from "../asset-router/IAssetRouterBase.sol";
import {DataEncoding} from "../../common/libraries/DataEncoding.sol";

import {WrongCounterpart} from "../L1BridgeContractErrors.sol";

/// @author Matter Labs
/// @custom:security-contact security@matterlabs.dev
/// @dev Vault handling bridging of USDC
/// @dev Designed for use with a proxy for upgradability.
contract L1USDCAssetDeploymentTracker is IL1AssetDeploymentTracker, Ownable2StepUpgradeable {
    /// @dev L1 Shared Bridge smart contract that handles communication with its counterparts on L2s
    IAssetRouterBase public immutable ASSET_ROUTER;

    address public immutable L1_USDC_ADDRESS;

    address public immutable ASSET_HANDLER_ON_COUNTERPART; // To be deployed at predefined address

    bytes32 public usdcAssetId;

    constructor(address _assetRouter, address _usdcToken, address _assetHandlerOnCounterpart) {
        _disableInitializers();
        ASSET_ROUTER = IAssetRouterBase(_assetRouter);
        L1_USDC_ADDRESS = _usdcToken;
        ASSET_HANDLER_ON_COUNTERPART = _assetHandlerOnCounterpart;
    }

    /// @notice Registers a native token address for the vault.
    /// @dev It does not perform any checks for the correctnesss of the token contract.
    function registerTokenOnL1() external {
        usdcAssetId = DataEncoding.encodeAssetId(block.chainid, L1_USDC_ADDRESS, address(this));
        ASSET_ROUTER.setAssetHandlerAddressThisChain(bytes32(uint256(uint160(L1_USDC_ADDRESS))), address(this));
    }

    function bridgeCheckCounterpartAddress(
        uint256,
        bytes32,
        address,
        address _assetHandlerAddressOnCounterpart
    ) external view override {
        if (_assetHandlerAddressOnCounterpart != ASSET_HANDLER_ON_COUNTERPART) {
            revert WrongCounterpart();
        }
    }
}
