// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import {Asset} from "@immutablex/Asset.sol";
import "forge-std/Script.sol";
import {NFTEscrow} from "@escrow/NFTEscrow.sol";

contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new NFTEscrow();

        vm.stopBroadcast();
    }
}
