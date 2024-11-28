// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {L1UsdcAssetHandler} from "../src/L1UsdcAssetHandler.sol";
import {SharedL2ContractDeployer} from "lib/era-contracts/l1-contracts/test/foundry/l1/integration/l2-tests-in-l1-context/_SharedL2ContractDeployer.sol";

// see L2Erc20TestAbstract for example of structure
abstract contract L2UsdcAssetHandlerTest is Test, SharedL2ContractDeployer {
    L1UsdcAssetHandler public usdcAssetHandler;

    function setUp() override public {
        
    }
}
