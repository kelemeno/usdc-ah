// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";

contract DeployScript is Script {

    address bridgehub = 0x0000000000000000000000000000000000000000;
    address sharedBridge = 0x0000000000000000000000000000000000000000;
    address usdc = 0x0000000000000000000000000000000000000000;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        deploymentTracker = new L1UsdcAssetDeploymentTracker(address(bridgehub), address(sharedBridge), usdc);
        usdcAssetId = DataEncoding.encodeAssetId(block.chainid, usdc, address(deploymentTracker));
        l1AssetHandler = new L1UsdcAssetHandler(address(sharedBridge), usdcAssetId, address(deploymentTracker));
        vm.prank(sharedBridge.owner());
        sharedBridge.setAssetDeploymentTracker(bytes32(uint256(uint160(usdc))), address(deploymentTracker));
        vm.prank(deploymentTracker.owner());
        deploymentTracker.setAddresses(address(l1AssetHandler), l2AssetHandler, l2UsdcAddress);
        deploymentTracker.registerTokenOnL1();
        vm.stopBroadcast();
    }
}
