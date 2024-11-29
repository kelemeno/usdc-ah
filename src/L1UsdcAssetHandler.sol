// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts-v4/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-v4/token/ERC20/utils/SafeERC20.sol";

import {IL1AssetHandler} from "l1-contracts/contracts/bridge/interfaces/IL1AssetHandler.sol";
import {AssetIdNotSupported, InsufficientChainBalance, NoFundsTransferred, Unauthorized} from "l1-contracts/contracts/common/L1ContractErrors.sol";

import {UsdcAssetHandlerBase} from "./UsdcAssetHandlerBase.sol";


/// @author Matter Labs
/// @custom:security-contact security@matterlabs.dev
/// @dev Vault handling bridging of USDC
/// @dev Designed for use with a proxy for upgradability.
contract L1UsdcAssetHandler is IL1AssetHandler, UsdcAssetHandlerBase {
    using SafeERC20 for IERC20;

    /// @dev Maps token balances for each chain to prevent unauthorized spending across hyperchains.
    /// This serves as a security measure until hyperbridging is implemented.
    /// NOTE: this function may be removed in the future, don't rely on it!
    mapping(uint256 chainId => uint256 balance) public chainBalance;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;

    /// @dev Contract is expected to be used as proxy implementation.
    /// @dev Disable the initialization to prevent Parity hack.
    /// @param _assetRouter Address of assetRouter
    constructor(
        address _assetRouter,
        bytes32 _usdcAssetId
    ) UsdcAssetHandlerBase(_assetRouter, _usdcAssetId) {
        _disableInitializers();
    }

    modifier onlyAssetDeploymentTracker() {
        if (msg.sender != L1_ASSET_DEPLOYMENT_TRACKER) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    function setTokenAddress(address _tokenAddress) external onlyAssetDeploymentTracker {
        _setTokenAddress(_tokenAddress);
    }

    /*//////////////////////////////////////////////////////////////
                            L1 SPECIFIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    ///  @inheritdoc IL1AssetHandler
    function bridgeRecoverFailedTransfer(
        uint256 _chainId,
        bytes32 _assetId,
        address _depositSender,
        bytes calldata _data
    ) external payable override onlyAssetRouter whenNotPaused {
        if (_assetId != USDC_ASSET_ID) {
            revert AssetIdNotSupported(_assetId);
        }
        (,,uint256 _amount ) = _decodeBridgeMintData(_data); //(_data, (uint256, address)); // replace with decodeBridgeMintData
        if (_amount == 0) {
            revert NoFundsTransferred();
        }

        _handleChainBalanceDecrease(_chainId, _amount);

        // we know USDC is native on L1.
        IERC20(tokenAddress).safeTransfer(_depositSender, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL & HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _handleChainBalanceIncrease(uint256 _chainId, uint256 _amount) internal override {
        chainBalance[_chainId] += _amount;
    }

    function _handleChainBalanceDecrease(uint256 _chainId, uint256 _amount) internal override {
        // Check that the chain has sufficient balance
        if (chainBalance[_chainId] < _amount) {
            revert InsufficientChainBalance();
        }
        chainBalance[_chainId] -= _amount;
    }
}
