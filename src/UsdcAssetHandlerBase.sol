// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable-v4/security/PausableUpgradeable.sol";

import {IERC20} from "@openzeppelin/contracts-v4/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts-v4/token/ERC20/utils/SafeERC20.sol";

import {IAssetHandler} from "l1-contracts/contracts/bridge/interfaces/IAssetHandler.sol";
import {IAssetRouterBase} from "l1-contracts/contracts/bridge/asset-router/IAssetRouterBase.sol";
import {Unauthorized, NonEmptyMsgValue, TokensWithFeesNotSupported} from "l1-contracts/contracts/common/L1ContractErrors.sol";

import {IMintableToken} from "./IMintableToken.sol";
import {AssetHandlerNotSet} from "./Errors.sol";
// import {TokensWithFeesNotSupported} from "l1-contracts/contracts/bridge/L1BridgeContractErrors.sol";

/// @author Matter Labs
/// @custom:security-contact security@matterlabs.dev
/// @dev Vault handling bridging of USDC
/// @dev Designed for use with a proxy for upgradability.
abstract contract UsdcAssetHandlerBase is IAssetHandler, PausableUpgradeable {
    using SafeERC20 for IERC20;

    /// @dev L1 Shared Bridge smart contract that handles communication with its counterparts on L2s
    IAssetRouterBase public immutable ASSET_ROUTER;

    /// @dev The assetId of the base token.
    bytes32 public immutable USDC_ASSET_ID;

    address public immutable L1_ASSET_DEPLOYMENT_TRACKER;

    /// @dev A tokenAddress
    address public tokenAddress;

    bool public isNative;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;

    /// @notice Checks that the message sender is the bridgehub.
    modifier onlyAssetRouter() {
        if (msg.sender != address(ASSET_ROUTER)) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier nonpayableForced() {
        if (msg.value != 0) {
            revert NonEmptyMsgValue();
        }
        _;
    }

    /// @dev Contract is expected to be used as proxy implementation.
    /// @dev Disable the initialization to prevent Parity hack.
    /// @param _assetRouter Address of assetRouter
    constructor(address _assetRouter, bytes32 _usdcAssetId) {
        _disableInitializers();
        ASSET_ROUTER = IAssetRouterBase(_assetRouter);
        USDC_ASSET_ID = _usdcAssetId;
    }

    function _setTokenAddress(address _tokenAddress) internal {
        tokenAddress = _tokenAddress;
    }

    /*//////////////////////////////////////////////////////////////
                            FINISH TRANSACTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAssetHandler
    /// @notice Used when the chain receives a transfer from L1 Shared Bridge and correspondingly mints the asset.
    /// @param _chainId The chainId that the message is from.
    /// @param _assetId The assetId of the asset being bridged.
    /// @param _data The abi.encoded transfer data.
    function bridgeMint(
        uint256 _chainId,
        bytes32 _assetId,
        bytes calldata _data
    ) external payable override onlyAssetRouter whenNotPaused {
        address receiver;
        uint256 amount;
        // we set all originChainId for all already bridged tokens with the setLegacyTokenAssetId and updateChainBalancesFromSharedBridge functions.
        // for tokens that are bridged for the first time, the originChainId will be 0.
        // slither-disable-next-line unused-return
        (, receiver, amount) = _decodeBridgeMintData(_data);

        _handleChainBalanceDecrease(_chainId, amount);
        _withdrawFunds(receiver, tokenAddress, amount);
        // solhint-disable-next-line func-named-parameters
        emit BridgeMint(_chainId, _assetId, receiver, amount);
    }

    /*//////////////////////////////////////////////////////////////
                            Start transaction Functions
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IAssetHandler
    /// @notice Allows bridgehub to acquire mintValue for L1->L2 transactions.
    /// @dev In case of native token vault _data is the tuple of _depositAmount and _receiver.
    function bridgeBurn(
        uint256 _chainId,
        uint256,
        bytes32 _assetId,
        address _originalCaller,
        bytes calldata _data
    ) external payable override nonpayableForced onlyAssetRouter whenNotPaused returns (bytes memory _bridgeMintData) {
        (uint256 _depositAmount, address _receiver) = _decodeBridgeBurnData(_data);
        uint256 expectedDepositAmount = _depositFunds(_originalCaller, IERC20(tokenAddress), _depositAmount); // note if _originalCaller is this contract, this will return 0. This does not happen.
        _handleChainBalanceIncrease(_chainId, _depositAmount);
        // The token has non-standard transfer logic
        if (_depositAmount != expectedDepositAmount) {
            revert TokensWithFeesNotSupported();
        }
        _bridgeMintData = _encodeBridgeMintData({
            _originalCaller: _originalCaller,
            _remoteReceiver: _receiver,
            _amount: _depositAmount
        });

        emit BridgeBurn({
            chainId: _chainId,
            assetId: _assetId,
            sender: _originalCaller,
            receiver: _receiver,
            amount: _depositAmount
        });
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL & HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Transfers tokens from the depositor address to the smart contract address.
    /// @param _from The address of the depositor.
    /// @param _token The ERC20 token to be transferred.
    /// @param _amount The amount to be transferred.
    /// @return The difference between the contract balance before and after the transferring of funds.
    function _depositFunds(address _from, IERC20 _token, uint256 _amount) internal virtual returns (uint256) {
        uint256 balanceBefore = _token.balanceOf(address(this));
        // slither-disable-next-line arbitrary-send-erc20
        if (isNative) {
            IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        } else {
            IMintableToken(tokenAddress).mint(_from, _amount);
        }

        uint256 balanceAfter = _token.balanceOf(address(this));

        return balanceAfter - balanceBefore;
    }

    function _withdrawFunds(address _to, address _token, uint256 _amount) internal {
        if (isNative) {
            IERC20(_token).safeTransfer(_to, _amount);
        } else {
            IMintableToken(_token).mint(_to, _amount);
        }
    }

    function _handleChainBalanceIncrease(uint256 _chainId, uint256 _amount) internal virtual;

    function _handleChainBalanceDecrease(uint256 _chainId, uint256 _amount) internal virtual;

    function _encodeBridgeMintData(
        address _originalCaller,
        address _remoteReceiver,
        // address _originToken,
        uint256 _amount
    ) internal pure returns (bytes memory) {
        return abi.encode(_originalCaller, _remoteReceiver, _amount);
    }

    function _decodeBridgeMintData(bytes calldata _data) internal pure returns (address, address, uint256) {
        return abi.decode(_data, (address, address, uint256));
    }

    function _decodeBridgeBurnData(bytes calldata _data) internal pure returns (uint256, address) {
        return abi.decode(_data, (uint256, address));
    }
}
