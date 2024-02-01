// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import {Asset} from "@immutablex/Asset.sol";
import "forge-std/Script.sol";
import {NFTEscrow} from "@escrow/NFTEscrow.sol";

contract DeployScript is Script {
    function run() public {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);

        NFTEscrow escrow = new NFTEscrow();

        console.log("Escrow address: %s", address(escrow));

        address owner = vm.envAddress("OWNER_ADDRESS");
        console.log("Owner address: %s", owner);

        escrow.initialize(owner);

        console.log(
            "Escrow initialized",
            escrow.hasRole(escrow.DEFAULT_ADMIN_ROLE(), owner)
        );

        vm.stopBroadcast();
    }
}
