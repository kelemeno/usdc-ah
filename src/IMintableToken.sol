// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

/// @author Matter Labs
interface IMintableToken {
    function mint(address _to, uint256 _amount) external;
    function burn(uint256 _amount) external;
}
