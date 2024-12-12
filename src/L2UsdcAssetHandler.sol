// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IAssetHandler} from "l1-contracts/contracts/bridge/interfaces/IAssetHandler.sol";
import {AddressAliasHelper} from "l1-contracts/contracts/vendor/AddressAliasHelper.sol";
import {Unauthorized} from "l1-contracts/contracts/common/L1ContractErrors.sol";

import {L2_ASSET_ROUTER_ADDR} from "l1-contracts/contracts/common/L2ContractAddresses.sol"; 
import {UsdcAssetHandlerBase} from "./UsdcAssetHandlerBase.sol";

/// @author Matter Labs
/// @custom:security-contact security@matterlabs.dev
/// @dev Vault handling bridging of USDC
/// @dev Designed for use with a proxy for upgradability.
contract L2UsdcAssetHandler is IAssetHandler, UsdcAssetHandlerBase {
    /// @dev Chain ID of L1 for bridging reasons.
    uint256 public immutable L1_CHAIN_ID;

    /// @dev Contract is expected to be used as proxy implementation.
    /// @dev Disable the initialization to prevent Parity hack.
    constructor(
        bytes32 _usdcAssetId,
        uint256 _l1ChainId,
        address _l1AssetDeploymentTracker
    ) UsdcAssetHandlerBase(L2_ASSET_ROUTER_ADDR, _usdcAssetId, _l1AssetDeploymentTracker) {
        L1_CHAIN_ID = _l1ChainId;
    }

    modifier onlyAliasedAssetDeploymentTracker() {
        if (AddressAliasHelper.undoL1ToL2Alias(msg.sender) != L1_ASSET_DEPLOYMENT_TRACKER) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    function setTokenAddress(address _tokenAddress, bool _isNative) external onlyAliasedAssetDeploymentTracker {
        _setTokenAddress(_tokenAddress, _isNative);
    }


    function _handleChainBalanceIncrease(uint256 _chainId, uint256 _amount) internal override {}

    function _handleChainBalanceDecrease(uint256 _chainId, uint256 _amount) internal override {}
}
